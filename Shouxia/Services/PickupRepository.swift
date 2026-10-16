import Foundation

actor PickupRepository {
    static let shared = PickupRepository()

    private let fileURL: URL
    private let automaticClipboardSuppressionsURL: URL
    private let parser: PickupParser
    private let surfacePublisher: (@Sendable (PickupSurfaceSnapshot) throws -> Void)?
    private let publishesLiveActivity: Bool
    private(set) var surfaceRefreshFailed = false

    init(fileURL: URL? = nil, parser: PickupParser = PickupParser(),
         surfacePublisher: (@Sendable (PickupSurfaceSnapshot) throws -> Void)? = nil) {
        self.parser = parser
        self.publishesLiveActivity = fileURL == nil
        #if os(iOS)
        self.surfacePublisher = surfacePublisher ?? (fileURL == nil ? PickupSurfacePublisher.publish : nil)
        #else
        self.surfacePublisher = surfacePublisher
        #endif
        let resolvedFileURL: URL
        if let fileURL {
            resolvedFileURL = fileURL
        } else {
            let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            resolvedFileURL = baseURL
                .appendingPathComponent("com.zhouwei.shouxia", isDirectory: true)
                .appendingPathComponent("pickups.json", isDirectory: false)
        }
        self.fileURL = resolvedFileURL
        self.automaticClipboardSuppressionsURL = resolvedFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("automatic-clipboard-suppressions.json", isDirectory: false)
    }

    func records() throws -> [PickupRecord] {
        let records = try loadRecords()
        refreshSurfaces(records)
        return records
    }

    func importText(
        _ text: String,
        source: PickupSource,
        importBatchID: UUID? = nil,
        defaultLocation: String? = nil
    ) throws -> PickupImportResult {
        let parsed = try parser.parseAll(text, requiresLabel: source == .smsAutomation)
        return try importParsedPickups(
            parsed,
            source: source,
            importBatchID: importBatchID,
            defaultLocation: defaultLocation
        )
    }

    func importAutomaticClipboardText(
        _ text: String,
        defaultLocation: String? = nil
    ) throws -> PickupImportResult? {
        let parsed = try parser.parseAll(text, requiresLabel: true)
        let suppressions = try loadAutomaticClipboardSuppressions()
        let allowed = parsed.filter { !suppressions.contains($0.fingerprint) }
        guard !allowed.isEmpty else { return nil }
        return try importParsedPickups(
            allowed,
            source: .paste,
            defaultLocation: defaultLocation
        )
    }

    /// Reviewed fields are data, not a new SMS to parse. Validate all items before one commit.
    func importImageCandidates(_ candidates: [ImagePickupCandidate], defaultLocation: String? = nil) throws -> PickupImportResult {
        guard !candidates.isEmpty else { throw PickupImportError.missingCode }
        try PickupCandidateReview.validate(candidates)
        let parsed = candidates.map { candidate in
            ParsedPickup(rawText: candidate.sanitizedImportText, code: candidate.code,
                         location: candidate.location, platform: candidate.platform,
                         fingerprint: parser.fingerprint(for: candidate.sanitizedImportText),
                         unresolvedNotificationCount: candidate.unresolvedNotificationCount,
                         locationRequiresConfirmation: candidate.locationRequiresConfirmation)
        }
        return try importParsedPickups(parsed, source: .imageRecognition, importBatchID: UUID(), defaultLocation: defaultLocation)
    }

    private func importParsedPickups(
        _ parsed: [ParsedPickup],
        source: PickupSource,
        importBatchID: UUID? = nil,
        defaultLocation: String? = nil
    ) throws -> PickupImportResult {
        var records = try loadRecords()
        let batchID = importBatchID ?? (parsed.count > 1 ? UUID() : nil)
        let results = parsed.map {
            importParsedPickup($0, source: source, importBatchID: batchID,
                               defaultLocation: defaultLocation, records: &records)
        }
        let added = results.flatMap(\.addedRecords)
        if !added.isEmpty { try save(records) }
        let unresolvedCount = parsed.map(\.unresolvedNotificationCount).max() ?? 0
        if results.count == 1, unresolvedCount == 0 { return results[0] }
        return .batch(added: added, duplicateCount: results.count - added.count, unresolvedCount: unresolvedCount)
    }

    private func importParsedPickup(
        _ parsed: ParsedPickup,
        source: PickupSource,
        importBatchID: UUID? = nil,
        defaultLocation: String? = nil,
        records: inout [PickupRecord]
    ) -> PickupImportResult {
        if let existing = duplicateRecord(
            code: parsed.code,
            location: parsed.location, platform: parsed.platform,
            fingerprint: parsed.fingerprint,
            in: records
        ) {
            return .duplicate(existing)
        }

        let normalizedDefaultLocation = defaultLocation?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackLocation: String? = normalizedDefaultLocation.flatMap { location in
            guard !location.isEmpty, location.count <= 80 else { return nil }
            return location
        }
        let location = parsed.location ?? (parsed.locationRequiresConfirmation ? nil : fallbackLocation)
        let locationSource: PickupLocationSource? = if parsed.location != nil {
            .recognized
        } else if fallbackLocation != nil && !parsed.locationRequiresConfirmation {
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
        return .added(record)
    }

    func importHandoffPackage(_ package: PickupHandoffPackage) throws -> PickupHandoffImportSummary {
        let package = try package.validated()
        var records = try loadRecords()
        var addedCount = 0
        var duplicateCount = 0

        for item in package.items {
            if duplicateRecord(
                code: item.code,
                location: item.location, platform: item.platform,
                fingerprint: item.importFingerprint,
                in: records
            ) != nil {
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

    /// Each package commits atomically before acknowledgement. Retry identity survives
    /// completion and avoids re-adding a package if acknowledgement previously failed.
    func receiveSharedImages(
        from queue: PickupImageShareQueue,
        defaultLocation: String? = nil
    ) throws -> PickupImageShareReceipt {
        var receipt = PickupImageShareReceipt()
        for file in try queue.pendingFiles() {
            do {
                let batch = try queue.read(file)
                var records = try loadRecords()
                let parsed = try batch.items.map { item in
                    let identity = parser.fingerprint(for: "取件码 \(item.code)\n分享批次 \(batch.id.uuidString)\n分享条目 \(item.id)")
                    // Version-1 batches written by 1.2.7(17) used code-only retry identity.
                    // Those batches guaranteed one item per code. Preserve retry suppression
                    // even after the old record has been completed or its location edited.
                    let legacy = parser.fingerprint(for: "取件码 \(item.code)\n分享批次 \(batch.id.uuidString)")
                    let legacyMatch = batch.items.filter { $0.code == item.code }.count == 1
                        && records.contains { $0.fingerprint == legacy }
                    return ParsedPickup(rawText: item.sanitizedText, code: item.code,
                                        location: item.location, platform: item.platform,
                                        fingerprint: legacyMatch ? legacy : identity)
                }
                let results = zip(parsed, batch.items).map { pickup, item in
                    importParsedPickup(pickup, source: item.effectiveSource, importBatchID: batch.id,
                                       defaultLocation: defaultLocation, records: &records)
                }
                let addedCount = results.flatMap(\.addedRecords).count
                if addedCount > 0 { try save(records) }
                receipt.addedCount += addedCount
                receipt.duplicateCount += batch.items.count - addedCount
                try queue.acknowledge(file)
            } catch {
                // Keep unreadable/uncommitted packages, continue independent valid ones.
                receipt.failedBatchCount += 1
            }
        }
        return receipt
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
        guard let index = records.firstIndex(where: { $0.id == id && ($0.isCompleted || $0.isArchived) }) else {
            return false
        }
        try suppressAutomaticClipboardImport(for: records[index].fingerprint)
        records.remove(at: index)
        try save(records)
        return true
    }

    private func loadRecords() throws -> [PickupRecord] {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([PickupRecord].self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            // A new installation has no source file. Permission and decoding failures
            // must reach the unavailable path, never become an empty successful list.
            return []
        } catch {
            publishSurface(.unavailable())
            throw error
        }
    }

    private func save(_ records: [PickupRecord]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
        refreshSurfaces(records)
        #if os(iOS)
        if publishesLiveActivity {
            Task { @MainActor in PickupLiveActivityController.shared.refresh() }
        }
        #endif
    }

    private func refreshSurfaces(_ records: [PickupRecord]) {
        publishSurface(.make(records: records))
    }

    private func publishSurface(_ snapshot: PickupSurfaceSnapshot) {
        #if os(iOS)
        if !snapshot.isAvailable, publishesLiveActivity {
            Task { @MainActor in PickupLiveActivityController.shared.sourceBecameUnavailable() }
        }
        #endif
        guard let surfacePublisher else { return }
        do {
            try surfacePublisher(snapshot)
            surfaceRefreshFailed = false
        } catch {
            // The source commit succeeded. Do not report import/completion as failed.
            surfaceRefreshFailed = true
        }
    }

    private func duplicateRecord(
        code: String,
        location: String?,
        platform: String?,
        fingerprint: String,
        in records: [PickupRecord]
    ) -> PickupRecord? {
        records.first { record in
            if record.fingerprint == fingerprint {
                return true
            }
            return !record.isCompleted
                && !record.isArchived
                && PickupIdentity.key(code: record.code, location: record.location, platform: record.platform)
                    == PickupIdentity.key(code: code, location: location, platform: platform)
        }
    }

    private func loadAutomaticClipboardSuppressions() throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: automaticClipboardSuppressionsURL.path) else {
            return Set()
        }
        let data = try Data(contentsOf: automaticClipboardSuppressionsURL)
        return Set(try JSONDecoder().decode([String].self, from: data))
    }

    private func suppressAutomaticClipboardImport(for fingerprint: String) throws {
        var suppressions = try loadAutomaticClipboardSuppressions()
        guard suppressions.insert(fingerprint).inserted else { return }

        let directory = automaticClipboardSuppressionsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(suppressions.sorted())
        try data.write(to: automaticClipboardSuppressionsURL, options: .atomic)
    }
}
