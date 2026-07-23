import Foundation

struct PickupRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let rawText: String
    let code: String
    let location: String?
    let platform: String?
    let createdAt: Date
    let source: PickupSource
    let fingerprint: String
    var completedAt: Date?
    var archivedAt: Date?

    var isCompleted: Bool {
        completedAt != nil
    }

    var isArchived: Bool {
        archivedAt != nil
    }
}

enum PickupSource: String, Codable, Sendable {
    case paste
    case notificationAutomation

    var displayName: String {
        switch self {
        case .paste:
            "剪贴板"
        case .notificationAutomation:
            "通知自动化"
        }
    }
}

struct ParsedPickup: Equatable, Sendable {
    let rawText: String
    let code: String
    let location: String?
    let platform: String?
    let fingerprint: String
}

enum PickupImportResult: Equatable, Sendable {
    case added(PickupRecord)
    case duplicate(PickupRecord)
}

enum PickupImportError: LocalizedError, Equatable {
    case emptyText
    case missingCode

    var errorDescription: String? {
        switch self {
        case .emptyText:
            "剪贴板里没有可用文字"
        case .missingCode:
            "没有识别到取件码，请复制完整通知后重试"
        }
    }
}
