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

    func importText(
        _ text: String,
        source: PickupSource,
        importBatchID: UUID? = nil,
        defaultLocation: String? = nil
    ) throws -> PickupImportResult {
        let parsed = try parser.parse(text)
        var records = try loadRecords()

        if let existing = records.first(where: { $0.fingerprint == parsed.fingerprint }) {
            return .duplicate(existing)
        }

        let normalizedDefaultLocation = defaultLocation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLocation: String? = normalizedDefaultLocation.flatMap { location in
            guard !location.isEmpty, location.count <= 80 else { return nil }
            return location
        }
        let location = parsed.location ?? fallbackLocation
        let locationSource: PickupLocationSource? = if parsed.location != nil {
            .recognized
        } else if fallbackLocation != nil {
            .commonDefault
        } else {
            nil
        }

        let record = PickupRecord(
            id: UUID(),
            rawText: parsed.rawText,
            code: parsed.code,
            location: location,
            platform: parsed.platform,
            createdAt: Date(),
            source: source,
            fingerprint: parsed.fingerprint,
            importBatchID: importBatchID,
            locationSource: locationSource,
            completedAt: nil,
            archivedAt: nil
        )
        records.append(record)
        try save(records)
        return .added(record)
    }

    func importHandoffPackage(_ package: PickupHandoffPackage) throws -> PickupHandoffImportSummary {
        let package = try package.validated()
        var records = try loadRecords()
        var addedCount = 0
        var duplicateCount = 0

        for item in package.items {
            if records.contains(where: { $0.fingerprint == item.importFingerprint }) {
                duplicateCount += 1
                continue
            }

            records.append(
                PickupRecord(
                    id: UUID(),
                    rawText: item.sanitizedImportText,
                    code: item.code.uppercased(),
                    location: item.location,
                    platform: item.platform,
                    createdAt: Date(),
                    source: .handoff,
                    fingerprint: item.importFingerprint,
                    importBatchID: package.id,
                    completedAt: nil,
                    archivedAt: nil
                )
            )
            addedCount += 1
        }

        if addedCount > 0 {
            try save(records)
        }
        return PickupHandoffImportSummary(
            addedCount: addedCount,
            duplicateCount: duplicateCount
        )
    }

    func complete(id: UUID) throws -> PickupRecord? {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        records[index].handedOffAt = nil
        records[index].completedAt = Date()
        let completed = records[index]
        try save(records)
        return completed
    }

    func handOff(ids: [UUID], at date: Date = Date()) throws -> [PickupRecord] {
        let requestedIDs = Set(ids)
        guard !requestedIDs.isEmpty, requestedIDs.count == ids.count else {
            return []
        }

        var records = try loadRecords()
        let matchingIndices = records.indices.filter { index in
            requestedIDs.contains(records[index].id)
                && !records[index].isCompleted
                && !records[index].isArchived
        }
        guard matchingIndices.count == requestedIDs.count else {
            return []
        }

        for index in matchingIndices {
            records[index].handedOffAt = date
            records[index].completedAt = date
        }
        let handedOff = matchingIndices.map { records[$0] }
        try save(records)
        return handedOff
    }

    func undoCompletion(id: UUID) throws -> PickupRecord? {
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        records[index].completedAt = nil
        records[index].handedOffAt = nil
        records[index].archivedAt = nil
        let restored = records[index]
        try save(records)
        return restored
    }

    func update(id: UUID, code: String, location: String?) throws -> PickupRecord? {
        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else {
            throw PickupRecordEditError.emptyCode
        }
        guard normalizedCode.count <= 40,
              normalizedCode.range(
                  of: #"^[A-Z0-9]+(?:-[A-Z0-9]+){0,4}$"#,
                  options: .regularExpression
              ) != nil
        else {
            throw PickupRecordEditError.invalidCode
        }

        let normalizedLocation = location?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedLocation.map({ $0.count <= 80 }) ?? true else {
            throw PickupRecordEditError.locationTooLong
        }

        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        records[index].code = normalizedCode
        records[index].location = normalizedLocation?.isEmpty == false
            ? normalizedLocation
            : nil
        records[index].locationSource = records[index].location == nil
            ? nil
            : .userEdited
        let updated = records[index]
        try save(records)
        return updated
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
