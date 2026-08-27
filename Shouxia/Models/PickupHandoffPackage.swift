import CoreTransferable
import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let shouxiaHandoff = UTType(
        exportedAs: "com.zhouwei.shouxia.handoff",
        conformingTo: .json
    )
}

struct PickupHandoffPackage: Codable, Equatable, Identifiable, Sendable {
    static let currentVersion = 1
    static let maximumItemCount = 100

    let id: UUID
    let version: Int
    let createdAt: Date
    let items: [PickupHandoffItem]

    init(records: [PickupRecord], now: Date = Date()) {
        id = UUID()
        version = Self.currentVersion
        createdAt = now
        items = records.map(PickupHandoffItem.init(record:))
    }

    func validated() throws -> Self {
        guard version == Self.currentVersion else {
            throw PickupHandoffError.unsupportedVersion
        }
        guard !items.isEmpty else {
            throw PickupHandoffError.emptyPackage
        }
        guard items.count <= Self.maximumItemCount else {
            throw PickupHandoffError.tooManyItems
        }
        guard Set(items.map(\.recordID)).count == items.count else {
            throw PickupHandoffError.invalidPackage
        }
        try items.forEach { try $0.validate() }
        return self
    }

    static func decode(contentsOf url: URL) throws -> Self {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? 0) <= 256_000 else {
            throw PickupHandoffError.invalidPackage
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Self.self, from: Data(contentsOf: url)).validated()
    }

    func exportURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShouxiaHandoffs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let url = directory.appendingPathComponent(
            "收下交接包-\(items.count)件-\(id.uuidString.prefix(6)).shouxia"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(self).write(to: url, options: .atomic)
        return url
    }
}

extension PickupHandoffPackage: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .shouxiaHandoff) { package in
            SentTransferredFile(try package.exportURL())
        }
    }
}

struct PickupHandoffItem: Codable, Equatable, Identifiable, Sendable {
    let recordID: UUID
    let code: String
    let location: String?
    let platform: String?

    var id: UUID { recordID }

    init(record: PickupRecord) {
        recordID = record.id
        code = record.code
        location = record.location
        platform = record.platform
    }

    var importFingerprint: String {
        "handoff-\(recordID.uuidString.lowercased())"
    }

    var sanitizedImportText: String {
        [
            platform,
            location.map { "领取地点：\($0)" },
            "取件码：\(code)",
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }

    fileprivate func validate() throws {
        guard (2...40).contains(code.count),
              code.range(of: #"^[A-Za-z0-9]+(?:-[A-Za-z0-9]+){0,4}$"#, options: .regularExpression) != nil,
              location.map({ !$0.isEmpty && $0.count <= 80 }) ?? true,
              platform.map({ !$0.isEmpty && $0.count <= 40 }) ?? true
        else {
            throw PickupHandoffError.invalidPackage
        }
    }
}

enum PickupHandoffError: LocalizedError, Equatable {
    case emptyPackage
    case tooManyItems
    case unsupportedVersion
    case invalidPackage

    var errorDescription: String? {
        switch self {
        case .emptyPackage:
            "这个交接包里没有取件信息"
        case .tooManyItems:
            "这个交接包里的取件信息太多"
        case .unsupportedVersion:
            "这个交接包来自较新的收下版本，请先更新 App"
        case .invalidPackage:
            "这个交接包无法读取，请让对方重新发送"
        }
    }
}

struct PickupHandoffImportSummary: Equatable, Sendable {
    let addedCount: Int
    let duplicateCount: Int
}
