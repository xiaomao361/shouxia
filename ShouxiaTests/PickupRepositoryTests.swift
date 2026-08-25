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

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PickupRecord.self, from: legacyData)

        XCTAssertNil(decoded.importBatchID)
        XCTAssertNil(decoded.locationSource)
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

    func testPermanentDeleteRejectsNonArchivedRecord() async throws {
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
