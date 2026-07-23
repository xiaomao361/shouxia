import Foundation

actor PickupRepository {
    static let shared = PickupRepository()

    private let fileURL: URL
    private let parser: PickupParser

    init(fileURL: URL? = nil, parser: PickupParser = PickupParser()) {
        self.parser = parser
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = baseURL
                .appendingPathComponent("com.zhouwei.shouxia", isDirectory: true)
                .appendingPathComponent("pickups.json", isDirectory: false)
        }
    }

    func records() throws -> [PickupRecord] {
        try loadRecords()
    }

    func importText(_ text: String, source: PickupSource) throws -> PickupImportResult {
        let parsed = try parser.parse(text)
        var records = try loadRecords()

        if let existing = records.first(where: { $0.fingerprint == parsed.fingerprint }) {
            return .duplicate(existing)
        }

        let record = PickupRecord(
            id: UUID(),
            rawText: parsed.rawText,
            code: parsed.code,
            location: parsed.location,
            platform: parsed.platform,
            createdAt: Date(),
            source: source,
            fingerprint: parsed.fingerprint,
            completedAt: nil,
            archivedAt: nil
        )
        records.append(record)
        try save(records)
        return .added(record)
    }

    func complete(id: UUID) throws -> PickupRecord? {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        records[index].completedAt = Date()
        let completed = records[index]
        try save(records)
        return completed
    }

    func undoCompletion(id: UUID) throws -> PickupRecord? {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        records[index].completedAt = nil
        records[index].archivedAt = nil
        let restored = records[index]
        try save(records)
        return restored
    }

    func archive(id: UUID) throws -> PickupRecord? {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }),
              records[index].isCompleted else {
            return nil
        }
        records[index].archivedAt = Date()
        let archived = records[index]
        try save(records)
        return archived
    }

    func restoreFromArchive(id: UUID) throws -> PickupRecord? {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }),
              records[index].isArchived else {
            return nil
        }
        records[index].archivedAt = nil
        let restored = records[index]
        try save(records)
        return restored
    }

    func permanentlyDelete(id: UUID) throws -> Bool {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id && $0.isArchived }) else {
            return false
        }
        records.remove(at: index)
        try save(records)
        return true
    }

    private func loadRecords() throws -> [PickupRecord] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([PickupRecord].self, from: data)
    }

    private func save(_ records: [PickupRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
    }
}
