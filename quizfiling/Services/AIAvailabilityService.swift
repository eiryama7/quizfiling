import Foundation

struct AIAvailabilityStatus {
    let isAvailable: Bool
    let reason: String
}

@MainActor
final class AIAvailabilityService: ObservableObject {
    static let shared = AIAvailabilityService()

    @Published private(set) var status: AIAvailabilityStatus

    private init() {
        self.status = AIAvailabilityService.evaluate()
    }

    func refresh() {
        status = AIAvailabilityService.evaluate()
    }

    private static func evaluate() -> AIAvailabilityStatus {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return AIAvailabilityStatus(isAvailable: true, reason: "利用可能")
        } else {
            return AIAvailabilityStatus(isAvailable: false, reason: "iOS 26 未満のため利用不可")
        }
        #else
        return AIAvailabilityStatus(isAvailable: false, reason: "Foundation Models が利用できないビルド環境です")
        #endif
    }
}
