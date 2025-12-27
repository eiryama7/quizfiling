import Foundation
import SwiftData

@MainActor
final class SubjectRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func ensureDefaults() throws {
        let descriptor = FetchDescriptor<SubjectEntity>()
        let count = try context.fetchCount(descriptor)
        guard count == 0 else { return }
        let defaults = [
            "国語",
            "数学",
            "英語",
            "理科",
            "社会",
            "情報",
            "その他"
        ]
        for (index, name) in defaults.enumerated() {
            context.insert(SubjectEntity(name: name, sortOrder: index))
        }
        try context.save()
    }

    func enabledSubjects() throws -> [SubjectEntity] {
        var descriptor = FetchDescriptor<SubjectEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        descriptor.predicate = #Predicate { $0.isEnabled }
        return try context.fetch(descriptor)
    }

    func allSubjects() throws -> [SubjectEntity] {
        let descriptor = FetchDescriptor<SubjectEntity>(sortBy: [SortDescriptor(\.sortOrder)])
        return try context.fetch(descriptor)
    }

    func save() throws {
        try context.save()
    }
}

@MainActor
final class DocumentRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ document: DocumentEntity) throws {
        context.insert(document)
        try context.save()
    }

    func delete(_ document: DocumentEntity) throws {
        context.delete(document)
        try context.save()
    }

    func save() throws {
        try context.save()
    }
}

@MainActor
final class QuestionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ question: QuestionEntity) throws {
        context.insert(question)
        try context.save()
    }

    func delete(_ question: QuestionEntity) throws {
        context.delete(question)
        try context.save()
    }

    func save() throws {
        try context.save()
    }

    func attempt(for question: QuestionEntity) throws -> StudyStateEntity? {
        let questionID = question.id
        let descriptor = FetchDescriptor<StudyStateEntity>(predicate: #Predicate { $0.question?.id == questionID })
        return try context.fetch(descriptor).first
    }

    func upsertStudyState(for question: QuestionEntity, isCorrect: Bool) throws {
        let existing = try attempt(for: question)
        let state = existing ?? StudyStateEntity(question: question)
        if existing == nil {
            context.insert(state)
        }
        state.attemptCount += 1
        if isCorrect {
            state.correctCount += 1
        }
        state.accuracy = state.attemptCount == 0 ? 0 : Double(state.correctCount) / Double(state.attemptCount)
        let nextInterval = isCorrect ? min(state.intervalDays * 2, 60) : 1
        state.intervalDays = nextInterval
        state.nextReviewAt = Calendar.current.date(byAdding: .day, value: nextInterval, to: .now) ?? .now
        try context.save()
    }
}

@MainActor
final class AttemptRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ attempt: AttemptEntity) throws {
        context.insert(attempt)
        try context.save()
    }
}
