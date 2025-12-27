import Foundation

struct GeneratedQuestion {
    let type: QuestionType
    let prompt: String
    let choices: [String]
    let correctIndex: Int?
    let fillBlankAnswer: String?
    let trueFalseAnswer: Bool?
    let sampleAnswer: String?
    let explanation: String?
    let tags: [String]
}

final class QuizGenerationService {
    func generate(text: String) async -> [GeneratedQuestion] {
        let chunks = TextChunker.chunk(text: text, maxCharacters: 900)
        let keywords = Array(Array(Set(chunks.flatMap { TextChunker.extractKeywords(text: $0, limit: 3) })).prefix(6))
        guard !keywords.isEmpty else { return [] }
        var questions: [GeneratedQuestion] = []
        for keyword in keywords {
            let prompt = "\(keyword) について簡潔に説明してください。"
            questions.append(
                GeneratedQuestion(
                    type: .written,
                    prompt: prompt,
                    choices: [],
                    correctIndex: nil,
                    fillBlankAnswer: nil,
                    trueFalseAnswer: nil,
                    sampleAnswer: "本文の記述に基づき整理して答える。",
                    explanation: "重要語句の理解を確認します。",
                    tags: [keyword]
                )
            )
        }
        return questions
    }
}
