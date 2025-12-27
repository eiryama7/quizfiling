import Foundation
import SwiftData

enum DocumentStatus: String, Codable, CaseIterable {
    case unprocessed
    case processing
    case completed
    case failed
}

enum QuestionType: String, Codable, CaseIterable, Identifiable {
    case multipleChoice
    case fillBlank
    case trueFalse
    case written

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .multipleChoice: return "4択"
        case .fillBlank: return "穴埋め"
        case .trueFalse: return "正誤"
        case .written: return "記述"
        }
    }
}

@Model
final class SubjectEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var sortOrder: Int
    var isEnabled: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, sortOrder: Int, isEnabled: Bool = true, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DocumentPageTextEntity {
    @Attribute(.unique) var id: UUID
    var pageIndex: Int
    var text: String
    var document: DocumentEntity?

    init(id: UUID = UUID(), pageIndex: Int, text: String, document: DocumentEntity? = nil) {
        self.id = id
        self.pageIndex = pageIndex
        self.text = text
        self.document = document
    }
}

@Model
final class DocumentEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var subject: SubjectEntity?
    var tags: [String] = []
    var fileURLs: [String] = []
    var pageCount: Int
    @Relationship(deleteRule: .cascade, inverse: \DocumentPageTextEntity.document) var pageTexts: [DocumentPageTextEntity] = []
    var ocrFullText: String = ""
    var summary: String = ""
    var statusRaw: String
    var lastError: String?

    var status: DocumentStatus {
        get { DocumentStatus(rawValue: statusRaw) ?? .unprocessed }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        subject: SubjectEntity? = nil,
        tags: [String] = [],
        fileURLs: [String] = [],
        pageCount: Int = 0,
        pageTexts: [DocumentPageTextEntity] = [],
        ocrFullText: String = "",
        summary: String = "",
        status: DocumentStatus = .unprocessed,
        lastError: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.subject = subject
        self.tags = tags
        self.fileURLs = fileURLs
        self.pageCount = pageCount
        self.pageTexts = pageTexts
        self.ocrFullText = ocrFullText
        self.summary = summary
        self.statusRaw = status.rawValue
        self.lastError = lastError
    }
}

@Model
final class QuestionEntity {
    @Attribute(.unique) var id: UUID
    var document: DocumentEntity?
    var subject: SubjectEntity?
    var tags: [String] = []
    var typeRaw: String
    var prompt: String
    var choices: [String] = []
    var correctIndex: Int?
    var fillBlankAnswer: String?
    var trueFalseAnswer: Bool?
    var sampleAnswer: String?
    var explanation: String?
    var difficulty: Int?
    var createdAt: Date
    var updatedAt: Date

    var type: QuestionType {
        get { QuestionType(rawValue: typeRaw) ?? .written }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        document: DocumentEntity? = nil,
        subject: SubjectEntity? = nil,
        tags: [String] = [],
        type: QuestionType,
        prompt: String,
        choices: [String] = [],
        correctIndex: Int? = nil,
        fillBlankAnswer: String? = nil,
        trueFalseAnswer: Bool? = nil,
        sampleAnswer: String? = nil,
        explanation: String? = nil,
        difficulty: Int? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.document = document
        self.subject = subject
        self.tags = tags
        self.typeRaw = type.rawValue
        self.prompt = prompt
        self.choices = choices
        self.correctIndex = correctIndex
        self.fillBlankAnswer = fillBlankAnswer
        self.trueFalseAnswer = trueFalseAnswer
        self.sampleAnswer = sampleAnswer
        self.explanation = explanation
        self.difficulty = difficulty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class AttemptEntity {
    @Attribute(.unique) var id: UUID
    var question: QuestionEntity?
    var answeredAt: Date
    var selectedIndex: Int?
    var isCorrect: Bool?
    var selfScored: Bool?
    var note: String?

    init(
        id: UUID = UUID(),
        question: QuestionEntity? = nil,
        answeredAt: Date = .now,
        selectedIndex: Int? = nil,
        isCorrect: Bool? = nil,
        selfScored: Bool? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.question = question
        self.answeredAt = answeredAt
        self.selectedIndex = selectedIndex
        self.isCorrect = isCorrect
        self.selfScored = selfScored
        self.note = note
    }
}

@Model
final class StudyStateEntity {
    @Attribute(.unique) var id: UUID
    var question: QuestionEntity?
    var correctCount: Int
    var attemptCount: Int
    var accuracy: Double
    var nextReviewAt: Date
    var intervalDays: Int

    init(
        id: UUID = UUID(),
        question: QuestionEntity? = nil,
        correctCount: Int = 0,
        attemptCount: Int = 0,
        accuracy: Double = 0,
        nextReviewAt: Date = .now,
        intervalDays: Int = 1
    ) {
        self.id = id
        self.question = question
        self.correctCount = correctCount
        self.attemptCount = attemptCount
        self.accuracy = accuracy
        self.nextReviewAt = nextReviewAt
        self.intervalDays = intervalDays
    }
}

