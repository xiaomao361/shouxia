import XCTest
@testable import Shouxia

final class PickupRepositoryTests: XCTestCase {
    func testPickupLocationMatchingTrimsWhitespaceAndRejectsMissingLocation() {
        let first = makeRecord(location: " 北门驿站 ")
        let sameLocation = makeRecord(location: "北门驿站")
        let otherLocation = makeRecord(location: "南门驿站")
        let missingLocation = makeRecord(location: nil)

        XCTAssertTrue(first.sharesPickupLocation(with: sameLocation))
        XCTAssertFalse(first.sharesPickupLocation(with: otherLocation))
        XCTAssertFalse(first.sharesPickupLocation(with: missingLocation))
        XCTAssertFalse(missingLocation.sharesPickupLocation(with: missingLocation))
    }

    func testPickupGroupUsesImportBatchWhenLocationIsMissing() {
        let batchID = UUID()
        let first = makeRecord(location: nil, importBatchID: batchID)
        let sameBatch = makeRecord(location: "北门驿站", importBatchID: batchID)
        let otherBatch = makeRecord(location: nil, importBatchID: UUID())

        XCTAssertTrue(first.sharesPickupGroup(with: sameBatch))
        XCTAssertFalse(first.sharesPickupGroup(with: otherBatch))
        XCTAssertEqual(first.locationDisplayName, "同批导入 · 地点待确认")
    }

    func testLegacyRecordWithoutBatchAndLocationSourceStillDecodes() throws {
        let record = makeRecord(location: "北门驿站")
        let encoded = try JSONEncoder().encode(record)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "importBatchID")
        object.removeValue(forKey: "locationSource")
        object.removeValue(forKey: "handedOffAt")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PickupRecord.self, from: legacyData)

        XCTAssertNil(decoded.importBatchID)
        XCTAssertNil(decoded.locationSource)
        XCTAssertNil(decoded.handedOffAt)
        XCTAssertEqual(decoded.location, "北门驿站")
    }

    func testLegacyNotificationAutomationSourceMigratesToSMSAutomation() throws {
        let legacy = Data(#""notificationAutomation""#.utf8)
        let source = try JSONDecoder().decode(PickupSource.self, from: legacy)
        XCTAssertEqual(source, .smsAutomation)

        let encoded = try JSONEncoder().encode(source)
        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), #""smsAutomation""#)
    }

    func testImageRecognitionSourceRoundTrips() throws {
        let encoded = try JSONEncoder().encode(PickupSource.imageRecognition)
        let decoded = try JSONDecoder().decode(PickupSource.self, from: encoded)

        XCTAssertEqual(decoded, .imageRecognition)
        XCTAssertEqual(decoded.displayName, "图片识别")
    }

    func testHandoffSourceRoundTrips() throws {
        let encoded = try JSONEncoder().encode(PickupSource.handoff)
        let decoded = try JSONDecoder().decode(PickupSource.self, from: encoded)

        XCTAssertEqual(decoded, .handoff)
        XCTAssertEqual(decoded.displayName, "他人托取")
    }

    func testHandoffPackageContainsOnlyMinimumPickupFieldsAndDecodes() throws {
        let record = makeRecord(location: "北门驿站")
        let package = PickupHandoffPackage(records: [record], now: Date(timeIntervalSince1970: 1_700_000_000))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("test.shouxia")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(package).write(to: url)

        let decoded = try PickupHandoffPackage.decode(contentsOf: url)

        XCTAssertEqual(decoded, package)
        XCTAssertEqual(decoded.items.first?.code, record.code)
        XCTAssertEqual(decoded.items.first?.location, record.location)
        let payload = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(payload.contains(record.rawText))
        XCTAssertFalse(payload.contains("rawText"))
        XCTAssertFalse(payload.contains("fingerprint"))
    }

    func testHandoffImportAddsItemsAndDeduplicatesSamePackage() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let records = [
            makeRecord(code: "3-2-4012", location: "北门驿站"),
            makeRecord(code: "829146", location: "1号柜"),
        ]
        let package = PickupHandoffPackage(records: records)

        let first = try await repository.importHandoffPackage(package)
        let second = try await repository.importHandoffPackage(package)
        let imported = try await repository.records()

        XCTAssertEqual(first, PickupHandoffImportSummary(addedCount: 2, duplicateCount: 0))
        XCTAssertEqual(second, PickupHandoffImportSummary(addedCount: 0, duplicateCount: 2))
        XCTAssertEqual(imported.map(\.source), [.handoff, .handoff])
        XCTAssertEqual(Set(imported.map(\.code)), Set(["3-2-4012", "829146"]))
    }

    func testImportDeduplicatesAndSupportsCompletionUndo() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("pickups.json")
        let repository = PickupRepository(fileURL: fileURL)
        let text = "【丰巢】快件已存入1号柜，取件码829146，请及时领取。"

        let first = try await repository.importText(text, source: .paste)
        let second = try await repository.importText(text, source: .smsAutomation)

        guard case let .added(record) = first else {
            return XCTFail("First import should add a record")
        }
        guard case let .duplicate(duplicate) = second else {
            return XCTFail("Second import should be a duplicate")
        }
        XCTAssertEqual(record.id, duplicate.id)

        let completed = try await repository.complete(id: record.id)
        XCTAssertNotNil(completed?.completedAt)

        let restored = try await repository.undoCompletion(id: record.id)
        XCTAssertNil(restored?.completedAt)
        XCTAssertNil(restored?.archivedAt)
    }

    func testActivePickupCodeDeduplicatesAcrossDifferentInputText() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))

        let first = try await repository.importText(
            "【丰巢】快件已存入1号柜，取件码829146，请及时领取。",
            source: .paste
        )
        let second = try await repository.importText("829146", source: .paste)

        guard case .added = first, case .duplicate = second else {
            return XCTFail("The same active pickup code should only create one record")
        }
        let activeRecords = try await repository.records()
        XCTAssertEqual(activeRecords.count, 1)
    }

    func testCompletedPickupCodeCanBeReusedByANewNotification() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))

        let first = try await repository.importText(
            "【丰巢】取件码829146，请及时领取。",
            source: .paste
        )
        guard case let .added(record) = first else {
            return XCTFail("First import should add a record")
        }
        _ = try await repository.complete(id: record.id)

        let reused = try await repository.importText(
            "【菜鸟】新的包裹已到，取件码829146。",
            source: .paste
        )
        guard case .added = reused else {
            return XCTFail("A completed short code must remain reusable for a future package")
        }
        let reusedRecords = try await repository.records()
        XCTAssertEqual(reusedRecords.count, 2)
    }

    func testHandoffCompletesSenderFlowAndUndoRestoresPendingState() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let result = try await repository.importText(
            "【丰巢】快件已存入1号柜，取件码829146，请及时领取。",
            source: .paste
        )
        guard case let .added(record) = result else {
            return XCTFail("Import should add a record")
        }
        let handoffDate = Date(timeIntervalSince1970: 1_700_000_000)

        let handedOff = try await repository.handOff(ids: [record.id], at: handoffDate)

        XCTAssertEqual(handedOff.count, 1)
        XCTAssertEqual(handedOff.first?.handedOffAt, handoffDate)
        XCTAssertEqual(handedOff.first?.completedAt, handoffDate)
        let persistedAfterHandoff = try await repository.records()
        XCTAssertTrue(persistedAfterHandoff.first?.isHandedOff == true)

        let restored = try await repository.undoCompletion(id: record.id)
        XCTAssertNil(restored?.handedOffAt)
        XCTAssertNil(restored?.completedAt)
        XCTAssertNil(restored?.archivedAt)
    }

    func testHandoffIsAtomicWhenAnyRecordIsNotPending() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let first = try await repository.importText("取件码 123456", source: .paste)
        let second = try await repository.importText("取件码 654321", source: .paste)
        guard case let .added(firstRecord) = first,
              case let .added(secondRecord) = second else {
            return XCTFail("Both imports should add records")
        }
        _ = try await repository.complete(id: secondRecord.id)

        let handedOff = try await repository.handOff(ids: [firstRecord.id, secondRecord.id])
        let persisted = try await repository.records()

        XCTAssertTrue(handedOff.isEmpty)
        XCTAssertNil(persisted.first(where: { $0.id == firstRecord.id })?.completedAt)
        XCTAssertNil(persisted.first(where: { $0.id == firstRecord.id })?.handedOffAt)
    }

    func testImportAppliesCommonLocationOnlyWhenLocationIsMissing() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let batchID = UUID()

        let fallbackResult = try await repository.importText(
            "包裹已到，请使用领取码 P668899 完成取件。",
            source: .imageRecognition,
            importBatchID: batchID,
            defaultLocation: " 小区北门驿站 "
        )
        let recognizedResult = try await repository.importText(
            "包裹已到南门快递柜，取件码 829146。",
            source: .paste,
            defaultLocation: "小区北门驿站"
        )

        guard case let .added(fallback) = fallbackResult,
              case let .added(recognized) = recognizedResult else {
            return XCTFail("Both imports should add records")
        }
        XCTAssertEqual(fallback.location, "小区北门驿站")
        XCTAssertEqual(fallback.locationSource, .commonDefault)
        XCTAssertEqual(fallback.importBatchID, batchID)
        XCTAssertEqual(recognized.location, "南门快递柜")
        XCTAssertEqual(recognized.locationSource, .recognized)
    }

    func testUpdateNormalizesAndPersistsPickupCodeAndLocation() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let result = try await repository.importText(
            "【丰巢】快件已存入1号柜，取件码829146，请及时领取。",
            source: .paste
        )
        guard case let .added(record) = result else {
            return XCTFail("Import should add a record")
        }

        let updated = try await repository.update(
            id: record.id,
            code: " ab-123 ",
            location: " 北门驿站 "
        )
        let persisted = try await repository.records().first

        XCTAssertEqual(updated?.code, "AB-123")
        XCTAssertEqual(updated?.location, "北门驿站")
        XCTAssertEqual(updated?.locationSource, .userEdited)
        XCTAssertEqual(persisted?.code, "AB-123")
        XCTAssertEqual(persisted?.location, "北门驿站")

        let cleared = try await repository.update(
            id: record.id,
            code: "AB-123",
            location: "   "
        )
        XCTAssertNil(cleared?.location)
        XCTAssertNil(cleared?.locationSource)
    }

    func testUpdateRejectsInvalidPickupCode() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let result = try await repository.importText(
            "【丰巢】快件已存入1号柜，取件码829146，请及时领取。",
            source: .paste
        )
        guard case let .added(record) = result else {
            return XCTFail("Import should add a record")
        }

        do {
            _ = try await repository.update(id: record.id, code: "错误 码", location: nil)
            XCTFail("Invalid code should be rejected")
        } catch let error as PickupRecordEditError {
            XCTAssertEqual(error, .invalidCode)
        }
    }

    func testArchiveRestoreAndPermanentDeleteLifecycle() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let result = try await repository.importText(
            "【菜鸟】凭取件码 3-2-4012 到北门菜鸟驿站领取。",
            source: .paste
        )
        guard case let .added(record) = result else {
            return XCTFail("Import should add a record")
        }

        _ = try await repository.complete(id: record.id)
        let archived = try await repository.archive(id: record.id)
        XCTAssertNotNil(archived?.completedAt)
        XCTAssertNotNil(archived?.archivedAt)

        let restored = try await repository.restoreFromArchive(id: record.id)
        XCTAssertNotNil(restored?.completedAt)
        XCTAssertNil(restored?.archivedAt)

        _ = try await repository.archive(id: record.id)
        let deleted = try await repository.permanentlyDelete(id: record.id)
        let remainingRecords = try await repository.records()
        XCTAssertTrue(deleted)
        XCTAssertTrue(remainingRecords.isEmpty)
    }

    func testPermanentDeleteRejectsPendingRecord() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let result = try await repository.importText(
            "【丰巢】快件已存入1号柜，取件码829146，请及时领取。",
            source: .paste
        )
        guard case let .added(record) = result else {
            return XCTFail("Import should add a record")
        }

        let deleted = try await repository.permanentlyDelete(id: record.id)
        let remainingRecords = try await repository.records()
        XCTAssertFalse(deleted)
        XCTAssertEqual(remainingRecords.count, 1)
    }

    func testAutomaticClipboardDoesNotRestorePermanentlyDeletedRecord() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let text = "【丰巢】快件已存入1号柜，取件码829146，请及时领取。"

        let first = try await repository.importAutomaticClipboardText(text)
        guard case let .added(record)? = first else {
            return XCTFail("Automatic clipboard import should add the record")
        }
        _ = try await repository.complete(id: record.id)
        _ = try await repository.archive(id: record.id)
        let deleted = try await repository.permanentlyDelete(id: record.id)
        XCTAssertTrue(deleted)

        let automaticRetry = try await repository.importAutomaticClipboardText(text)
        let remainingRecords = try await repository.records()
        XCTAssertNil(automaticRetry)
        XCTAssertTrue(remainingRecords.isEmpty)

        let manualRetry = try await repository.importText(text, source: .paste)
        guard case .added = manualRetry else {
            return XCTFail("An explicit manual paste should still be allowed")
        }
    }

    func testAutomaticClipboardSuppressionsDoNotDiscardOlderDeletions() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("pickups.json")
        let suppressionURL = directory.appendingPathComponent(
            "automatic-clipboard-suppressions.json"
        )
        let repository = PickupRepository(fileURL: fileURL)
        let firstText = "【丰巢】取件码829146，请及时领取。"
        let secondText = "【菜鸟】取件码729915，请及时领取。"

        let first = try await repository.importAutomaticClipboardText(firstText)
        guard case let .added(firstRecord)? = first else {
            return XCTFail("First automatic import should add a record")
        }
        _ = try await repository.complete(id: firstRecord.id)
        _ = try await repository.archive(id: firstRecord.id)
        let firstDeleted = try await repository.permanentlyDelete(id: firstRecord.id)
        XCTAssertTrue(firstDeleted)

        let firstFingerprint = try PickupParser()
            .parseAutomaticClipboard(firstText)
            .fingerprint
        let seededSuppressions = [firstFingerprint]
            + (0..<511).map { "placeholder-\($0)" }
        try JSONEncoder().encode(seededSuppressions).write(to: suppressionURL, options: .atomic)

        let second = try await repository.importAutomaticClipboardText(secondText)
        guard case let .added(secondRecord)? = second else {
            return XCTFail("Second automatic import should add a record")
        }
        _ = try await repository.complete(id: secondRecord.id)
        _ = try await repository.archive(id: secondRecord.id)
        let secondDeleted = try await repository.permanentlyDelete(id: secondRecord.id)
        XCTAssertTrue(secondDeleted)

        let firstRetry = try await repository.importAutomaticClipboardText(firstText)
        XCTAssertNil(firstRetry)
    }

    private var multiCodeText: String {
        "【中通快递】您有2个包裹在老六号楼（新4号楼）二单元106妈妈驿站，取货码9-4-0178、5-1-2889"
    }

    func testMultiCodeImportPersistsBothAndDeduplicatesWholeMessage() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("pickups.json")
        let repository = PickupRepository(fileURL: fileURL)
        let first = try await repository.importText(multiCodeText, source: .smsAutomation)
        XCTAssertEqual(first.addedRecords.map(\.code), ["9-4-0178", "5-1-2889"])
        XCTAssertNotNil(first.addedRecords.first?.importBatchID)
        XCTAssertEqual(Set(first.addedRecords.compactMap(\.importBatchID)).count, 1)
        XCTAssertTrue(first.addedRecords.allSatisfy { $0.source == .smsAutomation && $0.locationSource == .recognized })
        let second = try await repository.importText(multiCodeText, source: .paste)
        XCTAssertEqual(second, .batch(added: [], duplicateCount: 2))
        let reloaded = try await PickupRepository(fileURL: fileURL).records()
        XCTAssertEqual(reloaded.count, 2)
    }

    func testLegacyCompletedFirstCodeDoesNotBlockMissingSecondCode() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("pickups.json")
        // Old releases stored the whole-message fingerprint for the first code.
        let parsed = try PickupParser().parse(multiCodeText)
        let legacy = PickupRecord(id: UUID(), rawText: "", code: parsed.code,
                                  location: nil, platform: "中通", createdAt: Date(),
                                  source: .paste, fingerprint: parsed.fingerprint,
                                  completedAt: Date(), archivedAt: nil)
        try JSONEncoder().encode([legacy]).write(to: fileURL)
        let repository = PickupRepository(fileURL: fileURL)
        let result = try await repository.importText(multiCodeText, source: .paste)
        guard case let .batch(added, duplicates) = result else { return XCTFail("Expected a batch") }
        XCTAssertEqual(added.map(\.code), ["5-1-2889"])
        XCTAssertEqual(duplicates, 1)
        let records = try await repository.records()
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.id, legacy.id)
        XCTAssertNotNil(records.first?.completedAt)
    }

    func testMultiCodeAutomaticClipboardHonorsIndividualDeletionSuppression() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("pickups.json"))
        let result = try await repository.importAutomaticClipboardText(multiCodeText)
        let added = try XCTUnwrap(result).addedRecords
        XCTAssertEqual(added.count, 2)
        for record in added {
            _ = try await repository.complete(id: record.id)
            _ = try await repository.archive(id: record.id)
            _ = try await repository.permanentlyDelete(id: record.id)
            _ = try await repository.importAutomaticClipboardText(multiCodeText)
            let records = try await repository.records()
            XCTAssertFalse(records.contains { $0.id == record.id || $0.code == record.code })
        }
        let retry = try await repository.importAutomaticClipboardText(multiCodeText)
        XCTAssertNil(retry)
        let explicit = try await repository.importText(multiCodeText, source: .paste)
        XCTAssertEqual(explicit.addedRecords.count, 2)
    }

    func testMultiCodeWriteFailureThrowsWithoutPartialSuccess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data("blocker".utf8).write(to: blocker)
        let repository = PickupRepository(fileURL: blocker.appendingPathComponent("pickups.json"))
        do {
            _ = try await repository.importText(multiCodeText, source: .paste)
            XCTFail("An unwritable batch must throw")
        } catch {
            XCTAssertEqual(try Data(contentsOf: blocker), Data("blocker".utf8))
        }
    }

    @MainActor
    func testStoreReportsBatchCountsForManualAutomaticAndImageImports() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = PickupRepository(fileURL: directory.appendingPathComponent("manual.json"))
        let store = PickupStore(repository: repository)
        await store.importText("取货码9-4-0178", source: .paste)
        await store.importText(multiCodeText, source: .paste)
        XCTAssertEqual(store.records.count, 2)
        XCTAssertEqual(store.notice, .success("已收好 1 个取件码，另有 1 个已收过"))
        await store.importText(multiCodeText, source: .paste)
        XCTAssertEqual(store.notice, .neutral("这些取件码已经收过了"))

        let automatic = PickupStore(repository: PickupRepository(fileURL: directory.appendingPathComponent("automatic.json")))
        await automatic.importClipboardAutomatically(multiCodeText)
        XCTAssertEqual(automatic.records.count, 2)
        XCTAssertEqual(automatic.notice, .success("已从剪贴板收好 2 个取件码"))

        let images = PickupStore(repository: PickupRepository(fileURL: directory.appendingPathComponent("images.json")))
        let candidates = try ImagePickupExtractor().candidates(from: [
            RecognizedTextLine(text: multiCodeText, confidence: 0.95, minX: 0, midY: 0)
        ])
        await images.importImageCandidates(candidates)
        XCTAssertEqual(Set(images.records.map(\.code)), Set(["9-4-0178", "5-1-2889"]))
        XCTAssertEqual(images.notice, .success("已从图片收好 2 个取件码"))
    }

    @MainActor
    func testStoreReportsBatchWriteFailureAsError() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let blocker = directory.appendingPathComponent("not-a-directory")
        try Data("blocker".utf8).write(to: blocker)
        let store = PickupStore(repository: PickupRepository(fileURL: blocker.appendingPathComponent("pickups.json")))
        await store.importText(multiCodeText, source: .paste)
        XCTAssertEqual(store.notice, .error("没有收好，再试一次"))
        XCTAssertTrue(store.records.isEmpty)
    }

    private func makeRecord(
        code: String = "123456",
        location: String?,
        importBatchID: UUID? = nil
    ) -> PickupRecord {
        PickupRecord(
            id: UUID(),
            rawText: "取件码 \(code)",
            code: code,
            location: location,
            platform: nil,
            createdAt: Date(),
            source: .paste,
            fingerprint: UUID().uuidString,
            importBatchID: importBatchID,
            completedAt: nil,
            archivedAt: nil
        )
    }
}
