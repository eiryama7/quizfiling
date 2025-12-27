import SwiftUI
import SwiftData

@main
struct QuizFilingApp: App {
    private let container: ModelContainer
    @StateObject private var aiAvailability = AIAvailabilityService.shared
    @StateObject private var processingCoordinator = DocumentProcessingCoordinator()

    init() {
        let schema = Schema([
            SubjectEntity.self,
            DocumentEntity.self,
            DocumentPageTextEntity.self,
            QuestionEntity.self,
            AttemptEntity.self,
            StudyStateEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.modelContext, container.mainContext)
                .environmentObject(aiAvailability)
                .environmentObject(processingCoordinator)
                .task {
                    let repository = SubjectRepository(context: container.mainContext)
                    try? repository.ensureDefaults()
                }
        }
    }
}
