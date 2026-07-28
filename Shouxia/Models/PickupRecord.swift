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

    var normalizedLocation: String? {
        guard let location else { return nil }
        let normalized = location
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    func sharesPickupLocation(with other: PickupRecord) -> Bool {
        guard let normalizedLocation else { return false }
        return normalizedLocation == other.normalizedLocation
    }
}

enum PickupSource: String, Codable, Sendable {
    case paste
    case smsAutomation
    case imageRecognition

    var displayName: String {
        switch self {
        case .paste:
            "剪贴板"
        case .smsAutomation:
            "短信自动化"
        case .imageRecognition:
            "图片识别"
        }
    }

    init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(String.self)
        if rawValue == "notificationAutomation" {
            self = .smsAutomation
            return
        }
        guard let source = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown pickup source: \(rawValue)"
                )
            )
        }
        self = source
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
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
