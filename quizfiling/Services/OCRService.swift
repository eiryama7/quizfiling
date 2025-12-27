import Foundation
import Vision

struct OCRResult {
    let pageTexts: [String]
    let fullText: String
}

final class OCRService {
    func recognize(images: [CGImage], progress: @escaping (Double) -> Void) async throws -> OCRResult {
        var pageTexts: [String] = []
        for (index, image) in images.enumerated() {
            try Task.checkCancellation()
            let text = try await recognize(image: image)
            pageTexts.append(text)
            let fraction = Double(index + 1) / Double(max(images.count, 1))
            progress(fraction)
        }
        let fullText = pageTexts.joined(separator: "\n\n")
        return OCRResult(pageTexts: pageTexts, fullText: fullText)
    }

    private func recognize(image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
