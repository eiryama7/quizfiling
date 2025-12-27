import SwiftUI
import SwiftData

struct TestModeView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \QuestionEntity.createdAt, order: .reverse) private var questions: [QuestionEntity]
    @Query private var studyStates: [StudyStateEntity]

    @State private var selectedType: QuestionType?
    @State private var selectedSubject: SubjectEntity?
    @State private var subjects: [SubjectEntity] = []
    @State private var includeDueOnly = false
    @State private var includeLowAccuracy = false
    @State private var isTesting = false
    @State private var testQuestions: [QuestionEntity] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("条件") {
                    Picker("タイプ", selection: $selectedType) {
                        Text("すべて").tag(Optional<QuestionType>.none)
                        ForEach(QuestionType.allCases) { type in
                            Text(type.displayName).tag(Optional(type))
                        }
                    }
                    Picker("科目", selection: $selectedSubject) {
                        Text("すべて").tag(Optional<SubjectEntity>.none)
                        ForEach(subjects) { subject in
                            Text(subject.name).tag(Optional(subject))
                        }
                    }
                    Toggle("復習期日のみ", isOn: $includeDueOnly)
                    Toggle("正答率が低いもの", isOn: $includeLowAccuracy)
                }

                Section {
                    Button("テストを開始") {
                        testQuestions = filteredQuestions().shuffled()
                        isTesting = true
                    }
                    .disabled(filteredQuestions().isEmpty)
                }
            }
            .navigationTitle("テスト")
            .sheet(isPresented: $isTesting) {
                TestSessionView(questions: testQuestions)
            }
            .task {
                let repo = SubjectRepository(context: context)
                subjects = (try? repo.allSubjects()) ?? []
            }
        }
    }

    private func filteredQuestions() -> [QuestionEntity] {
        let now = Date()
        return questions.filter { question in
            let matchesType = selectedType == nil || question.type == selectedType
            let matchesSubject = selectedSubject == nil || question.subject?.id == selectedSubject?.id
            let state = studyStates.first(where: { $0.question?.id == question.id })
            let dueOK = !includeDueOnly || (state?.nextReviewAt ?? now) <= now
            let lowAcc = !includeLowAccuracy || (state?.accuracy ?? 1.0) < 0.6
            return matchesType && matchesSubject && dueOK && lowAcc
        }
    }
}

private struct TestSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let questions: [QuestionEntity]

    @State private var currentIndex = 0
    @State private var answers: [UUID: TestAnswer] = [:]
    @State private var finished = false

    var body: some View {
        NavigationStack {
            if finished {
                resultView
            } else if questions.isEmpty {
                ContentUnavailableView("問題がありません", systemImage: "questionmark")
            } else {
                questionView(question: questions[currentIndex])
            }
        }
    }

    private func questionView(question: QuestionEntity) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Q\(currentIndex + 1)/\(questions.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(question.prompt)
                .font(.headline)

            switch question.type {
            case .multipleChoice:
                ForEach(0..<question.choices.count, id: \.self) { index in
                    Button {
                        answers[question.id] = .choice(index)
                    } label: {
                        HStack {
                            Text(question.choices[index])
                            Spacer()
                            if answers[question.id]?.choiceIndex == index {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                    }
                }
            case .fillBlank:
                TextField("回答", text: Binding(get: {
                    answers[question.id]?.text ?? ""
                }, set: { newValue in
                    answers[question.id] = .text(newValue)
                }))
                .textFieldStyle(.roundedBorder)
            case .trueFalse:
                Toggle("正しい", isOn: Binding(get: {
                    answers[question.id]?.boolValue ?? true
                }, set: { newValue in
                    answers[question.id] = .bool(newValue)
                }))
            case .written:
                TextEditor(text: Binding(get: {
                    answers[question.id]?.text ?? ""
                }, set: { newValue in
                    answers[question.id] = .text(newValue)
                }))
                .frame(minHeight: 120)
            }

            Spacer()

            Button(currentIndex + 1 == questions.count ? "結果を見る" : "次へ") {
                if currentIndex + 1 == questions.count {
                    finalize()
                } else {
                    currentIndex += 1
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("テスト")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("終了") { dismiss() }
            }
        }
    }

    private var resultView: some View {
        let score = scoreSummary()
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("結果")
                    .font(.title2)
                Text("正答数: \(score.correct)/\(score.total)")
                ForEach(questions) { question in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(question.prompt)
                            .font(.headline)
                        Text(score.resultText(for: question))
                            .font(.caption)
                            .foregroundStyle(score.isCorrect(question) ? .green : .red)
                    }
                }
                Button("閉じる") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }

    private func finalize() {
        let repo = QuestionRepository(context: context)
        let attemptRepo = AttemptRepository(context: context)
        for question in questions {
            let answer = answers[question.id]
            let evaluation = evaluate(question: question, answer: answer)
            let attempt = AttemptEntity(
                question: question,
                selectedIndex: answer?.choiceIndex,
                isCorrect: evaluation.isCorrect,
                selfScored: evaluation.selfScored,
                note: answer?.text
            )
            try? attemptRepo.add(attempt)
            if let isCorrect = evaluation.isCorrect {
                try? repo.upsertStudyState(for: question, isCorrect: isCorrect)
            }
        }
        finished = true
    }

    private func evaluate(question: QuestionEntity, answer: TestAnswer?) -> EvaluationResult {
        switch question.type {
        case .multipleChoice:
            guard let choice = answer?.choiceIndex else { return EvaluationResult(isCorrect: false, selfScored: false) }
            return EvaluationResult(isCorrect: choice == question.correctIndex, selfScored: false)
        case .fillBlank:
            guard let text = answer?.text else { return EvaluationResult(isCorrect: false, selfScored: false) }
            let correct = text.trimmingCharacters(in: .whitespacesAndNewlines) == question.fillBlankAnswer?.trimmingCharacters(in: .whitespacesAndNewlines)
            return EvaluationResult(isCorrect: correct, selfScored: false)
        case .trueFalse:
            guard let value = answer?.boolValue else { return EvaluationResult(isCorrect: false, selfScored: false) }
            return EvaluationResult(isCorrect: value == question.trueFalseAnswer, selfScored: false)
        case .written:
            return EvaluationResult(isCorrect: nil, selfScored: true)
        }
    }

    private func scoreSummary() -> ScoreSummary {
        var correct = 0
        var total = 0
        for question in questions {
            let evaluation = evaluate(question: question, answer: answers[question.id])
            if let isCorrect = evaluation.isCorrect {
                total += 1
                if isCorrect { correct += 1 }
            }
        }
        return ScoreSummary(correct: correct, total: max(total, 1), evaluations: questions.map { question in
            (question.id, evaluate(question: question, answer: answers[question.id]))
        })
    }
}

private struct TestAnswer {
    var choiceIndex: Int?
    var text: String?
    var boolValue: Bool?

    static func choice(_ index: Int) -> TestAnswer { TestAnswer(choiceIndex: index) }
    static func text(_ value: String) -> TestAnswer { TestAnswer(text: value) }
    static func bool(_ value: Bool) -> TestAnswer { TestAnswer(boolValue: value) }
}

private struct EvaluationResult {
    let isCorrect: Bool?
    let selfScored: Bool?
}

private struct ScoreSummary {
    let correct: Int
    let total: Int
    let evaluations: [(UUID, EvaluationResult)]

    func isCorrect(_ question: QuestionEntity) -> Bool {
        evaluations.first(where: { $0.0 == question.id })?.1.isCorrect ?? false
    }

    func resultText(for question: QuestionEntity) -> String {
        let evaluation = evaluations.first(where: { $0.0 == question.id })?.1
        if question.type == .written {
            return "自己採点対象"
        }
        return (evaluation?.isCorrect ?? false) ? "正解" : "不正解"
    }
}
