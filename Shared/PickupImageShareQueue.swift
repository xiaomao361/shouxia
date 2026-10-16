import Foundation

struct PickupImageShareReceipt: Equatable, Sendable {
    var addedCount = 0
    var duplicateCount = 0
    var failedBatchCount = 0

    func message(surfaceRefreshFailed: Bool) -> String? {
        var parts: [String] = []
        if failedBatchCount > 0 {
            if addedCount > 0 { parts.append("已从分享添加 \(addedCount) 个取件码") }
            if duplicateCount > 0 { parts.append("\(duplicateCount) 个取件码已存在") }
            parts.append("\(failedBatchCount) 批分享未处理完成，已保留；请稍后重新打开收下重试")
        } else if addedCount > 0 {
            parts.append("已从分享添加 \(addedCount) 个取件码")
        } else if duplicateCount > 0 {
            parts.append("分享的取件码已在收下中")
        }
        if surfaceRefreshFailed { parts.append("小组件暂时无法更新") }
        return parts.isEmpty ? nil : parts.joined(separator: "；")
    }
}

/// User-facing recovery instructions; never expose raw provider or file-system errors.
enum PickupShareFeedback {
    static func recognitionFailure(_ error: Error, isImage: Bool) -> String {
        if let error = error as? PickupImageShareError { return error.localizedDescription }
        if let error = error as? PickupSharedTextParser.SharedTextError { return error.localizedDescription }
        if let error = error as? ImagePickupRecognitionError { return error.localizedDescription }
        return isImage ? "图片暂时无法读取或识别，请换一张清晰截图再试"
            : "文字暂时无法读取，请重新分享或复制到收下里粘贴"
    }

    static func groupedFailures(_ failures: [String]) -> [String] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        for failure in failures {
            if counts[failure] == nil { order.append(failure) }
            counts[failure, default: 0] += 1
        }
        return order.map { "\(counts[$0]!) 项：\($0)" }
    }

    static func saveFailure(_ error: Error) -> String {
        if let error = error as? PickupImageShareError { return error.localizedDescription }
        if (error as NSError).domain == NSCocoaErrorDomain,
           (error as NSError).code == CocoaError.fileWriteOutOfSpace.rawValue {
            return "设备存储空间不足，请释放空间后再保存"
        }
        return "暂时无法保存，已保留当前勾选，请再试一次；也可取消后在收下里粘贴文字或从截图添加"
    }
}

/// Confirmed minimum fields only. The extension never writes the app's record database.
struct PickupImageShareBatch: Codable, Equatable, Sendable {
    let version: Int
    let id: UUID
    let items: [Item]

    struct Item: Codable, Equatable, Identifiable, Sendable {
        let code: String
        let location: String?
        let platform: String?
        /// Missing in existing image batches; these remain image-recognition records.
        let source: PickupSource?
        var id: String { PickupIdentity.key(code: code, location: location, platform: platform) }

        init(code: String, location: String?, platform: String?, source: PickupSource? = nil) {
            self.code = code
            self.location = location
            self.platform = platform
            self.source = source
        }

        var effectiveSource: PickupSource { source ?? .imageRecognition }

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
              Set(items.map(\.id)).count == items.count else {
            throw PickupImageShareError.invalidBatch
        }
        for item in items {
            guard (4...24).contains(item.code.count),
                  item.code.range(of: #"^[A-Z0-9]+(?:-[A-Z0-9]+){0,4}$"#, options: .regularExpression) != nil,
                  !(item.code.allSatisfy(\.isNumber) && item.code.count > 8),
                  [.imageRecognition, .sharedText].contains(item.effectiveSource),
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
        case .missingAppGroup: "暂时无法保存，请打开收下后粘贴文字或从截图添加"
        case .invalidBatch: "取件信息无法保存，请重新分享取件文字或截图"
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
