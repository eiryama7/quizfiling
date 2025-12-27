import Foundation

struct SubjectClassificationResult {
    let subjectName: String
    let confidence: Double
    let rationale: String
    let tags: [String]
}

final class SubjectClassificationService {
    func classify(text: String, availableSubjects: [String]) async -> SubjectClassificationResult {
        let inference = SubjectHeuristics.inferSubject(from: text, subjects: availableSubjects)
        return SubjectClassificationResult(
            subjectName: inference.0,
            confidence: inference.1,
            rationale: "本文から頻出キーワードを検出",
            tags: inference.2
        )
    }
}
