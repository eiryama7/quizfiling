import Foundation

struct SummaryResult {
    let summary: String
}

final class SummarizationService {
    func summarize(text: String) async -> SummaryResult {
        let chunks = TextChunker.chunk(text: text, maxCharacters: 800)
        let partials = chunks.map { chunk in
            chunk
                .split(whereSeparator: { $0 == "。" || $0 == "." })
                .prefix(2)
                .map(String.init)
                .joined(separator: "。")
        }
        let combined = partials.joined(separator: "。")
        let trimmed = String(combined.prefix(180))
        let summary = trimmed.isEmpty ? "（要約なし）" : trimmed + (trimmed.count >= 180 ? "…" : "")
        return SummaryResult(summary: summary)
    }
}
