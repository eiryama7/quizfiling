import SwiftUI

extension DocumentEntity {
    var statusLabel: String {
        switch status {
        case .unprocessed: return "未処理"
        case .processing: return "処理中"
        case .completed: return "完了"
        case .failed: return "失敗"
        }
    }

    var statusColor: Color {
        switch status {
        case .unprocessed: return Color.gray.opacity(0.2)
        case .processing: return Color.blue.opacity(0.2)
        case .completed: return Color.green.opacity(0.2)
        case .failed: return Color.red.opacity(0.2)
        }
    }
}
