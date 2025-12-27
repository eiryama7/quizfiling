import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var aiAvailability: AIAvailabilityService

    @Query(sort: \SubjectEntity.sortOrder) private var subjects: [SubjectEntity]

    @State private var newSubjectName = ""
    @State private var showResetAlert = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI 可用性") {
                    HStack {
                        Text("ステータス")
                        Spacer()
                        Text(aiAvailability.status.isAvailable ? "利用可能" : "利用不可")
                            .foregroundStyle(aiAvailability.status.isAvailable ? .green : .red)
                    }
                    Text(aiAvailability.status.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("科目マスタ") {
                    ForEach(subjects) { subject in
                        HStack {
                            TextField("科目名", text: Binding(get: {
                                subject.name
                            }, set: { newValue in
                                subject.name = newValue
                                subject.updatedAt = .now
                                try? context.save()
                            }))
                            Toggle("有効", isOn: Binding(get: {
                                subject.isEnabled
                            }, set: { newValue in
                                subject.isEnabled = newValue
                                subject.updatedAt = .now
                                try? context.save()
                            }))
                            .labelsHidden()
                        }
                    }
                    .onMove(perform: moveSubject)

                    HStack {
                        TextField("新しい科目", text: $newSubjectName)
                        Button("追加") {
                            addSubject()
                        }
                        .disabled(newSubjectName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("ストレージ") {
                    Button("全データ削除") {
                        showResetAlert = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("設定")
            .toolbar { EditButton() }
            .alert("全データ削除", isPresented: $showResetAlert, actions: {
                Button("削除", role: .destructive) {
                    resetAllData()
                }
                Button("キャンセル", role: .cancel) {}
            }, message: {
                Text("全てのドキュメント・問題・履歴を削除します。")
            })
        }
    }

    private func addSubject() {
        let trimmed = newSubjectName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let order = (subjects.map { $0.sortOrder }.max() ?? 0) + 1
        let subject = SubjectEntity(name: trimmed, sortOrder: order)
        context.insert(subject)
        try? context.save()
        newSubjectName = ""
    }

    private func moveSubject(from source: IndexSet, to destination: Int) {
        var updated = subjects
        updated.move(fromOffsets: source, toOffset: destination)
        for (index, subject) in updated.enumerated() {
            subject.sortOrder = index
            subject.updatedAt = .now
        }
        try? context.save()
    }

    private func resetAllData() {
        deleteAll(DocumentEntity.self)
        deleteAll(DocumentPageTextEntity.self)
        deleteAll(QuestionEntity.self)
        deleteAll(AttemptEntity.self)
        deleteAll(StudyStateEntity.self)
        try? context.save()
        try? FileStorageService.shared.purgeAll()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        let descriptor = FetchDescriptor<T>()
        if let results = try? context.fetch(descriptor) {
            for item in results {
                context.delete(item)
            }
        }
    }
}
