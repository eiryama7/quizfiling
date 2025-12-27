import SwiftUI
import SwiftData
import UIKit

struct DocumentDetailView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var processingCoordinator: DocumentProcessingCoordinator
    @EnvironmentObject private var aiAvailability: AIAvailabilityService

    @State private var subjects: [SubjectEntity] = []
    @State private var isEditingSummary = false
    @State private var tagsText = ""
    @State private var showAllOCR = false
    @State private var errorMessage: String?

    let document: DocumentEntity

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                titleSection
                previewSection
                statusSection
                subjectSection
                summarySection
                ocrSection
                actionSection
            }
            .padding()
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let repo = SubjectRepository(context: context)
            subjects = (try? repo.allSubjects()) ?? []
            tagsText = document.tags.joined(separator: ", ")
        }
        .alert("エラー", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("タイトル")
                .font(.headline)
            TextField("タイトル", text: Binding(get: {
                document.title
            }, set: { newValue in
                document.title = newValue
                document.updatedAt = .now
                try? context.save()
            }))
            .textFieldStyle(.roundedBorder)
        }
    }

    private var previewSection: some View {
        Group {
            if let pdfPath = document.fileURLs.first(where: { $0.lowercased().hasSuffix(".pdf") }) {
                PDFKitView(url: FileStorageService.shared.resolve(pdfPath))
                    .frame(minHeight: 240)
            } else {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(document.fileURLs, id: \.self) { path in
                            let url = FileStorageService.shared.resolve(path)
                            if let image = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 220)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("処理ステータス")
                .font(.headline)
            if let progress = processingCoordinator.progressByDocument[document.id], document.status == .processing {
                ProgressView(value: progress)
                Button("キャンセル") {
                    processingCoordinator.cancel(document: document)
                }
            } else {
                Text(document.statusLabel)
                    .font(.subheadline)
            }
            if let error = document.lastError {
                Text("エラー: \(error)")
                    .foregroundStyle(.red)
            }
        }
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("科目 / タグ")
                .font(.headline)
            Picker("科目", selection: Binding(get: {
                document.subject ?? subjects.first
            }, set: { newValue in
                document.subject = newValue
                document.updatedAt = .now
                try? context.save()
            })) {
                ForEach(subjects) { subject in
                    Text(subject.name).tag(Optional(subject))
                }
            }
            .pickerStyle(.menu)
            TextField("タグ（カンマ区切り）", text: $tagsText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: tagsText) { _, newValue in
                    document.tags = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    document.updatedAt = .now
                    try? context.save()
                }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("要約")
                    .font(.headline)
                Spacer()
                Button(isEditingSummary ? "完了" : "編集") {
                    isEditingSummary.toggle()
                    try? context.save()
                }
            }
            if isEditingSummary {
                TextEditor(text: Binding(get: {
                    document.summary
                }, set: { newValue in
                    document.summary = newValue
                    document.updatedAt = .now
                }))
                .frame(minHeight: 100)
            } else {
                Text(document.summary.isEmpty ? "（未入力）" : document.summary)
                    .font(.subheadline)
            }
            if !aiAvailability.status.isAvailable {
                Text("AI要約は利用不可: \(aiAvailability.status.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var ocrSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("OCR")
                .font(.headline)
            if showAllOCR {
                Text(document.ocrFullText.isEmpty ? "（未処理）" : document.ocrFullText)
                    .font(.footnote)
            } else {
                Text(String(document.ocrFullText.prefix(400)))
                    .font(.footnote)
                Button("全文を表示") { showAllOCR = true }
                    .font(.caption)
            }
            Button("OCRを再実行") {
                let repo = SubjectRepository(context: context)
                processingCoordinator.process(document: document, context: context, subjectRepository: repo)
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("問題生成")
                .font(.headline)
            Button("問題を生成") {
                Task {
                    do {
                        try await processingCoordinator.generateQuestions(for: document, context: context)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            if !aiAvailability.status.isAvailable {
                Text("AI生成は利用不可: \(aiAvailability.status.reason)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
