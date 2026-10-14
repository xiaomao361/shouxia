import Foundation

struct PickupImageShareReceipt: Equatable, Sendable {
    var addedCount = 0
    var duplicateCount = 0
    var failedBatchCount = 0
}

/// Confirmed OCR fields only. The extension never writes the app's record database.
struct PickupImageShareBatch: Codable, Equatable, Sendable {
    let version: Int
    let id: UUID
    let items: [Item]

    struct Item: Codable, Equatable, Identifiable, Sendable {
        let code: String
        let location: String?
        let platform: String?
        var id: String { code }

        var sanitizedText: String {
            ([platform.map { "【\($0)】" }, location.map { "已到\($0)" }, "取件码 \(code)"])
                .compactMap { $0 }.joined(separator: "，")
        }
    }

    init(id: UUID = UUID(), items: [Item]) {
        version = 1
        self.id = id
        self.items = items
    }

    func validated() throws -> Self {
        guard version == 1, !items.isEmpty, items.count <= 100,
              Set(items.map(\.code)).count == items.count else {
            throw PickupImageShareError.invalidBatch
        }
        for item in items {
            guard (4...24).contains(item.code.count),
                  item.code.range(of: #"^[A-Z0-9]+(?:-[A-Z0-9]+){0,4}$"#, options: .regularExpression) != nil,
                  !(item.code.allSatisfy(\.isNumber) && item.code.count > 8),
                  validField(item.location, limit: 80), validField(item.platform, limit: 20) else {
                throw PickupImageShareError.invalidBatch
            }
        }
        return self
    }

    private func validField(_ value: String?, limit: Int) -> Bool {
        guard let value else { return true }
        return !value.isEmpty && value.count <= limit
            && value.rangeOfCharacter(from: .controlCharacters) == nil
            && value.range(of: #"\d{10,}"#, options: .regularExpression) == nil
    }
}

enum PickupImageShareError: LocalizedError {
    case missingAppGroup, invalidBatch, queueFull, tooManyImages, oversizedImage
    var errorDescription: String? {
        switch self {
        case .missingAppGroup: "暂时无法保存，请改用收下里的“从截图添加”"
        case .invalidBatch: "取件信息无法保存，请重新选择截图"
        case .queueFull: "请先打开收下，接收已保存的取件码后再试"
        case .tooManyImages: "一次最多分享五张图片，请重新选择"
        case .oversizedImage: "这张图片过大，请改用截图再试"
        }
    }
}

struct PickupImageShareQueue: Sendable {
    let directory: URL
    static let maximumFileSize = 64 * 1024

    static func shared() throws -> Self {
        #if os(iOS)
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.zhouwei.shouxia"
        ) else { throw PickupImageShareError.missingAppGroup }
        return Self(directory: container.appendingPathComponent("image-share-inbox-v1", isDirectory: true))
        #else
        throw PickupImageShareError.missingAppGroup
        #endif
    }

    func enqueue(_ batch: PickupImageShareBatch) throws {
        let batch = try batch.validated()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard try pendingFiles().count < 50 else { throw PickupImageShareError.queueFull }
        let data = try JSONEncoder().encode(batch)
        guard data.count <= Self.maximumFileSize else { throw PickupImageShareError.invalidBatch }
        let url = directory.appendingPathComponent(batch.id.uuidString).appendingPathExtension("json")
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    func pendingFiles() throws -> [URL] {
        do {
            return try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch CocoaError.fileReadNoSuchFile { return [] }
    }

    func read(_ url: URL) throws -> PickupImageShareBatch {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard let size, size <= Self.maximumFileSize else { throw PickupImageShareError.invalidBatch }
        return try JSONDecoder().decode(PickupImageShareBatch.self, from: Data(contentsOf: url)).validated()
    }

    /// Called only after the app database has committed. A failed import stays recoverable.
    func acknowledge(_ url: URL) throws {
        guard url.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL else {
            throw PickupImageShareError.invalidBatch
        }
        try FileManager.default.removeItem(at: url)
    }
}
