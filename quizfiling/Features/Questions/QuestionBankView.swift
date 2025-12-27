import SwiftUI
import SwiftData

struct QuestionBankView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \QuestionEntity.createdAt, order: .reverse) private var questions: [QuestionEntity]
    @Query private var studyStates: [StudyStateEntity]

    @State private var searchText = ""
    @State private var selectedType: QuestionType?
    @State private var selectedSubject: SubjectEntity?
    @State private var subjects: [SubjectEntity] = []
    @State private var showEditor = false
    @State private var editingQuestion: QuestionEntity?

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredQuestions) { question in
                    Button {
                        editingQuestion = question
                        showEditor = true
                    } label: {
                        QuestionRow(question: question, accuracy: accuracy(for: question))
                    }
                }
                .onDelete(perform: delete)
            }
            .navigationTitle("問題バンク")
            .searchable(text: $searchText, prompt: "問題・タグ検索")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingQuestion = nil
                        showEditor = true
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { selectedType = nil }
                        ForEach(QuestionType.allCases) { type in
                            Button(type.displayName) { selectedType = type }
                        }
                    } label: {
                        Label(selectedType?.displayName ?? "タイプ", systemImage: "slider.horizontal.3")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて") { selectedSubject = nil }
                        ForEach(subjects) { subject in
                            Button(subject.name) { selectedSubject = subject }
                        }
                    } label: {
                        Label(selectedSubject?.name ?? "科目", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showEditor) {
                QuestionEditorView(question: editingQuestion)
            }
            .task {
                let repo = SubjectRepository(context: context)
                subjects = (try? repo.allSubjects()) ?? []
            }
        }
    }

    private var filteredQuestions: [QuestionEntity] {
        questions.filter { question in
            let matchesSearch = searchText.isEmpty || question.prompt.localizedCaseInsensitiveContains(searchText) || question.tags.joined(separator: ",").localizedCaseInsensitiveContains(searchText)
            let matchesType = selectedType == nil || question.type == selectedType
            let matchesSubject = selectedSubject == nil || question.subject?.id == selectedSubject?.id
            return matchesSearch && matchesType && matchesSubject
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let question = filteredQuestions[index]
            context.delete(question)
        }
        try? context.save()
    }

    private func accuracy(for question: QuestionEntity) -> Double {
        studyStates.first(where: { $0.question?.id == question.id })?.accuracy ?? 0
    }
}

private struct QuestionRow: View {
    let question: QuestionEntity
    let accuracy: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(question.prompt)
                .font(.headline)
            HStack {
                Text(question.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let subject = question.subject?.name {
                    Text(subject)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("正答率 \(Int(accuracy * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
