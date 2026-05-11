import SwiftUI

enum WorkbenchSection: String, CaseIterable, Identifiable {
    case requests
    case environments
    case history
    case commands

    var id: String { rawValue }

    var title: String {
        switch self {
        case .requests:
            "Requests"
        case .environments:
            "Environments"
        case .history:
            "History"
        case .commands:
            "Commands"
        }
    }

    var systemImage: String {
        switch self {
        case .requests:
            "arrow.left.arrow.right"
        case .environments:
            "server.rack"
        case .history:
            "clock.arrow.circlepath"
        case .commands:
            "command"
        }
    }
}
