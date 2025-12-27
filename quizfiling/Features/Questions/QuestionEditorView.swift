import SwiftUI
import SwiftData

struct QuestionEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let question: QuestionEntity?

    @State private var prompt: String = ""
    @State private var type: QuestionType = .written
    @State private var choices: [String] = ["", "", "", ""]
    @State private var correctIndex: Int = 0
    @State private var fillBlankAnswer: String = ""
    @State private var trueFalseAnswer: Bool = true
    @State private var sampleAnswer: String = ""
    @State private var explanation: String = ""
    @State private var tagsText: String = ""
    @State private var subjects: [SubjectEntity] = []
    @State private var selectedSubject: SubjectEntity?

    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    Picker("タイプ", selection: $type) {
                        ForEach(QuestionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    TextField("問題文", text: $prompt, axis: .vertical)
                    Picker("科目", selection: $selectedSubject) {
                        Text("未設定").tag(Optional<SubjectEntity>.none)
                        ForEach(subjects) { subject in
                            Text(subject.name).tag(Optional(subject))
                        }
                    }
                    TextField("タグ（カンマ区切り）", text: $tagsText)
                }

                if type == .multipleChoice {
                    Section("選択肢") {
                        ForEach(0..<4, id: \.self) { index in
                            TextField("選択肢 \(index + 1)", text: Binding(get: {
                                choices[index]
                            }, set: { newValue in
                                choices[index] = newValue
                            }))
                        }
                        Picker("正解", selection: $correctIndex) {
                            ForEach(0..<4, id: \.self) { index in
                                Text("\(index + 1)").tag(index)
                            }
                        }
                    }
                }

                if type == .fillBlank {
                    Section("穴埋め") {
                        TextField("正解", text: $fillBlankAnswer)
                    }
                }

                if type == .trueFalse {
                    Section("正誤") {
                        Toggle("正しい", isOn: $trueFalseAnswer)
                    }
                }

                Section("解説 / 記述") {
                    TextField("模範解答", text: $sampleAnswer, axis: .vertical)
                    TextField("解説", text: $explanation, axis: .vertical)
                }
            }
            .navigationTitle(question == nil ? "問題追加" : "問題編集")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") {
                        save()
                        dismiss()
                    }
                    .disabled(prompt.isEmpty)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .task {
                let repo = SubjectRepository(context: context)
                subjects = (try? repo.allSubjects()) ?? []
                if let question {
                    prompt = question.prompt
                    type = question.type
                    choices = question.choices + Array(repeating: "", count: max(0, 4 - question.choices.count))
                    correctIndex = question.correctIndex ?? 0
                    fillBlankAnswer = question.fillBlankAnswer ?? ""
                    trueFalseAnswer = question.trueFalseAnswer ?? true
                    sampleAnswer = question.sampleAnswer ?? ""
                    explanation = question.explanation ?? ""
                    tagsText = question.tags.joined(separator: ", ")
                    selectedSubject = question.subject
                }
            }
        }
    }

    private func save() {
        let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let trimmedChoices = Array(choices.prefix(4))
        if let question {
            question.prompt = prompt
            question.type = type
            question.choices = trimmedChoices
            question.correctIndex = type == .multipleChoice ? correctIndex : nil
            question.fillBlankAnswer = type == .fillBlank ? fillBlankAnswer : nil
            question.trueFalseAnswer = type == .trueFalse ? trueFalseAnswer : nil
            question.sampleAnswer = sampleAnswer
            question.explanation = explanation
            question.tags = tags
            question.subject = selectedSubject
            question.updatedAt = .now
        } else {
            let newQuestion = QuestionEntity(
                subject: selectedSubject,
                tags: tags,
                type: type,
                prompt: prompt,
                choices: trimmedChoices,
                correctIndex: type == .multipleChoice ? correctIndex : nil,
                fillBlankAnswer: type == .fillBlank ? fillBlankAnswer : nil,
                trueFalseAnswer: type == .trueFalse ? trueFalseAnswer : nil,
                sampleAnswer: sampleAnswer,
                explanation: explanation
            )
            context.insert(newQuestion)
        }
        try? context.save()
    }
}
