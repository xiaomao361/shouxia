import Foundation

struct PickupRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let rawText: String
    var code: String
    var location: String?
    let platform: String?
    let createdAt: Date
    let source: PickupSource
    let fingerprint: String
    var importBatchID: UUID?
    var locationSource: PickupLocationSource?
    var handedOffAt: Date?
    var completedAt: Date?
    var archivedAt: Date?

    init(
        id: UUID,
        rawText: String,
        code: String,
        location: String?,
        platform: String?,
        createdAt: Date,
        source: PickupSource,
        fingerprint: String,
        importBatchID: UUID? = nil,
        locationSource: PickupLocationSource? = nil,
        handedOffAt: Date? = nil,
        completedAt: Date?,
        archivedAt: Date?
    ) {
        self.id = id
        self.rawText = rawText
        self.code = code
        self.location = location
        self.platform = platform
        self.createdAt = createdAt
        self.source = source
        self.fingerprint = fingerprint
        self.importBatchID = importBatchID
        self.locationSource = locationSource
        self.handedOffAt = handedOffAt
        self.completedAt = completedAt
        self.archivedAt = archivedAt
    }

    var isCompleted: Bool {
        completedAt != nil
    }

    var isHandedOff: Bool {
        handedOffAt != nil
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

    func sharesPickupGroup(with other: PickupRecord) -> Bool {
        if let importBatchID, importBatchID == other.importBatchID {
            return true
        }
        return sharesPickupLocation(with: other)
    }

    var locationDisplayName: String {
        if let location, !location.isEmpty {
            return location
        }
        return importBatchID == nil ? "地点待确认" : "同批导入 · 地点待确认"
    }
}

enum PickupLocationSource: String, Codable, Sendable {
    case recognized
    case commonDefault
    case userEdited
}

enum PickupRecordEditError: LocalizedError, Equatable {
    case missingRecord
    case emptyCode
    case invalidCode
    case locationTooLong

    var errorDescription: String? {
        switch self {
        case .missingRecord:
            "这条取件信息已经不存在了"
        case .emptyCode:
            "请填写取件码"
        case .invalidCode:
            "取件码请使用字母、数字和短横线，长度不超过 40 个字符"
        case .locationTooLong:
            "取件地点请控制在 80 个字符以内"
        }
    }
}

enum PickupSource: String, Codable, Sendable {
    case paste
    case smsAutomation
    case imageRecognition
    case handoff

    var displayName: String {
        switch self {
        case .paste:
            "剪贴板"
        case .smsAutomation:
            "短信自动化"
        case .imageRecognition:
            "图片识别"
        case .handoff:
            "他人托取"
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
