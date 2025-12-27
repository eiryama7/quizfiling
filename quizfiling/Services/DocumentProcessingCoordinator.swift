import Foundation
import SwiftData
import PDFKit
import UIKit

@MainActor
final class DocumentProcessingCoordinator: ObservableObject {
    @Published private(set) var progressByDocument: [UUID: Double] = [:]
    @Published private(set) var errorByDocument: [UUID: String] = [:]

    private let ocrService = OCRService()
    private let pdfRenderService = PDFRenderService()
    private let classificationService = SubjectClassificationService()
    private let summarizationService = SummarizationService()
    private let quizGenerationService = QuizGenerationService()

    private var tasks: [UUID: Task<Void, Never>] = [:]

    func process(document: DocumentEntity, context: ModelContext, subjectRepository: SubjectRepository) {
        cancel(document: document)
        document.status = .processing
        document.lastError = nil
        document.updatedAt = .now
        progressByDocument[document.id] = 0
        try? context.save()

        let documentID = document.id
        let fileURLs = document.fileURLs
        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let urls = fileURLs.map { FileStorageService.shared.resolve($0) }
                let images = try await self.loadImages(from: urls)
                let ocrResult = try await self.ocrService.recognize(images: images) { progress in
                    Task { @MainActor in
                        self.progressByDocument[documentID] = progress
                    }
                }
                try Task.checkCancellation()

                await MainActor.run {
                    document.pageTexts = ocrResult.pageTexts.enumerated().map { index, text in
                        DocumentPageTextEntity(pageIndex: index, text: text, document: document)
                    }
                    document.pageCount = ocrResult.pageTexts.count
                    document.ocrFullText = ocrResult.fullText
                }

                let subjects = await MainActor.run { (try? subjectRepository.enabledSubjects().map { $0.name }) ?? [] }
                let classification = await self.classificationService.classify(text: ocrResult.fullText, availableSubjects: subjects)
                await MainActor.run {
                    document.tags = Array(Set(document.tags + classification.tags))
                    if let subject = try? subjectRepository.allSubjects().first(where: { $0.name == classification.subjectName }) {
                        document.subject = subject
                    }
                }

                let summary = await self.summarizationService.summarize(text: ocrResult.fullText)
                await MainActor.run {
                    if document.summary.isEmpty {
                        document.summary = summary.summary
                    }
                    document.status = .completed
                    document.updatedAt = .now
                    try? context.save()
                    self.progressByDocument[documentID] = 1
                }
            } catch is CancellationError {
                await MainActor.run {
                    document.status = .unprocessed
                    document.updatedAt = .now
                    try? context.save()
                }
            } catch {
                await MainActor.run {
                    document.status = .failed
                    document.lastError = error.localizedDescription
                    document.updatedAt = .now
                    try? context.save()
                    self.errorByDocument[documentID] = error.localizedDescription
                }
            }
        }
        tasks[document.id] = task
    }

    func cancel(document: DocumentEntity) {
        tasks[document.id]?.cancel()
        tasks[document.id] = nil
    }

    private func loadImages(from urls: [URL]) async throws -> [CGImage] {
        var results: [CGImage] = []
        for url in urls {
            try Task.checkCancellation()
            if url.pathExtension.lowercased() == "pdf" {
                let rendered = try pdfRenderService.renderPages(url: url)
                results.append(contentsOf: rendered)
            } else {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data), let cgImage = image.cgImage {
                    results.append(cgImage)
                }
            }
        }
        return results
    }

    func generateQuestions(for document: DocumentEntity, context: ModelContext) async throws {
        let generated = await quizGenerationService.generate(text: document.ocrFullText)
        for question in generated {
            let entity = QuestionEntity(
                document: document,
                subject: document.subject,
                tags: question.tags,
                type: question.type,
                prompt: question.prompt,
                choices: question.choices,
                correctIndex: question.correctIndex,
                fillBlankAnswer: question.fillBlankAnswer,
                trueFalseAnswer: question.trueFalseAnswer,
                sampleAnswer: question.sampleAnswer,
                explanation: question.explanation
            )
            context.insert(entity)
        }
        try context.save()
    }
}
