import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case library = "ライブラリ"
    case questions = "問題バンク"
    case test = "テスト"
    case settings = "設定"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .library: return "tray.full"
        case .questions: return "questionmark.circle"
        case .test: return "checkmark.circle"
        case .settings: return "gear"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem = .library

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationTitle("QuizFiling")
        } detail: {
            Group {
                switch selection {
                case .library:
                    LibraryView()
                case .questions:
                    QuestionBankView()
                case .test:
                    TestModeView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
