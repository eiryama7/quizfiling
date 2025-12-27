import Foundation

struct TextChunker {
    static func chunk(text: String, maxCharacters: Int = 1200) -> [String] {
        guard text.count > maxCharacters else { return [text] }
        var chunks: [String] = []
        var current = ""
        for paragraph in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let piece = paragraph + "\n"
            if current.count + piece.count > maxCharacters, !current.isEmpty {
                chunks.append(current)
                current = ""
            }
            current += piece
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    static func extractKeywords(text: String, limit: Int = 6) -> [String] {
        let tokens = text
            .replacingOccurrences(of: "[^\p{L}\p{N}]", with: " ", options: .regularExpression)
            .split(separator: " ")
            .map { String($0) }
        var counts: [String: Int] = [:]
        for token in tokens where token.count >= 2 {
            counts[token, default: 0] += 1
        }
        let sorted = counts.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key.count > rhs.key.count }
            return lhs.value > rhs.value
        }
        return sorted.prefix(limit).map { $0.key }
    }
}

struct SubjectHeuristics {
    static func inferSubject(from text: String, subjects: [String]) -> (String, Double, [String]) {
        let lower = text.lowercased()
        let map: [String: [String]] = [
            "国語": ["小説", "古文", "漢文", "文法", "語句", "読解"],
            "数学": ["方程式", "関数", "図形", "確率", "微分", "積分", "ベクトル", "数列"],
            "英語": ["english", "英文", "grammar", "単語", "文法", "reading"],
            "理科": ["化学", "物理", "生物", "地学", "実験", "反応"],
            "社会": ["歴史", "地理", "公民", "政治", "経済", "年号"],
            "情報": ["アルゴリズム", "プログラム", "ネットワーク", "データ", "情報"],
            "その他": []
        ]

        var best = "その他"
        var bestScore = 0
        for subject in subjects {
            let keywords = map[subject, default: []]
            let score = keywords.reduce(0) { result, keyword in
                result + (lower.contains(keyword.lowercased()) ? 1 : 0)
            }
            if score > bestScore {
                bestScore = score
                best = subject
            }
        }
        let confidence = min(0.9, Double(bestScore) / 6.0 + 0.2)
        let tags = TextChunker.extractKeywords(text: text, limit: 5)
        return (best, confidence, tags)
    }
}
