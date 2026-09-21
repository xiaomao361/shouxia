import XCTest
@testable import Shouxia

final class PickupSurfaceTests: XCTestCase {
    func testHistoryCalendarBoundaryAndLegacyArchiveVisibility() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 21, hour: 12)))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 20)))
        var edge = record(code: "1001", location: nil, time: 1)
        edge.completedAt = start
        var old = record(code: "1002", location: nil, time: 2)
        old.completedAt = start.addingTimeInterval(-1)
        old.archivedAt = now // Archiving must not change completion-based recency.
        var legacy = record(code: "1003", location: nil, time: 3)
        legacy.archivedAt = now
        let pending = record(code: "1004", location: nil, time: 4)
        let records = [old, pending, edge, legacy]
        XCTAssertEqual(PickupHistoryRange.recent.records(from: records, now: now, calendar: calendar).map(\.code), ["1003", "1001"])
        XCTAssertEqual(PickupHistoryRange.all.records(from: records).map(\.code), ["1003", "1001", "1002"])
        XCTAssertEqual(records[0].archivedAt, now)
    }

    func testDirectHistoryDeletionAndRestoredRecordProtection() async throws {
        let file = temporaryURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = PickupRepository(fileURL: file)
        let result = try await repo.importText("取件码 4567", source: .paste)
        let item = try XCTUnwrap(result.addedRecords.first)
        _ = try await repo.complete(id: item.id)
        _ = try await repo.undoCompletion(id: item.id)
        let rejected = try await repo.permanentlyDelete(id: item.id)
        XCTAssertFalse(rejected) // A stale history row must not delete a now-pending item.
        _ = try await repo.complete(id: item.id)
        let deleted = try await repo.permanentlyDelete(id: item.id)
        XCTAssertTrue(deleted)
        let remaining = try await repo.records()
        XCTAssertTrue(remaining.isEmpty)
        let missing = try await repo.permanentlyDelete(id: item.id)
        XCTAssertFalse(missing)
    }

    func testLegacyArchivedHistoryCanRestoreOrDeleteWithoutMigration() async throws {
        let file = temporaryURL()
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = PickupRepository(fileURL: file)
        let result = try await repo.importText("取件码 5678", source: .paste)
        let item = try XCTUnwrap(result.addedRecords.first)
        _ = try await repo.complete(id: item.id)
        _ = try await repo.archive(id: item.id)
        let restored = try await repo.undoCompletion(id: item.id)
        XCTAssertNil(restored?.completedAt)
        XCTAssertNil(restored?.archivedAt)
        _ = try await repo.complete(id: item.id)
        _ = try await repo.archive(id: item.id)
        let deleted = try await repo.permanentlyDelete(id: item.id)
        XCTAssertTrue(deleted)
    }

    func testSnapshotFiltersSortsGroupsAndDoesNotLeakSourceText() throws {
        let old = record(code: "1001", location: " 北门 ", time: 1)
        let newest = record(code: "1002", location: "南门", time: 3)
        let middle = record(code: "1003", location: "北门", time: 2)
        var done = record(code: "1004", location: nil, time: 4)
        done.completedAt = Date()
        var archived = record(code: "1005", location: nil, time: 5)
        archived.archivedAt = Date()
        let snapshot = PickupSurfaceSnapshot.make(records: [old, done, newest, archived, middle])
        XCTAssertEqual(snapshot.items(at: nil).map(\.code), ["1002", "1003", "1001"])
        XCTAssertEqual(snapshot.items(at: "北门").count, 2)
        XCTAssertTrue(snapshot.items(at: "已删除地点").isEmpty)
        let encoded = String(decoding: try JSONEncoder().encode(snapshot), as: UTF8.self)
        XCTAssertFalse(encoded.contains("secret SMS"))
        XCTAssertFalse(encoded.contains("fingerprint"))
    }

    func testUnavailableCorruptExpiredAndMissingSnapshotAreNotEmptySuccess() throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        XCTAssertThrowsError(try PickupSnapshotFile.read(from: url))
        try PickupSnapshotFile.write(.unavailable(), to: url)
        XCTAssertThrowsError(try PickupSnapshotFile.read(from: url))
        try Data("broken".utf8).write(to: url)
        XCTAssertThrowsError(try PickupSnapshotFile.read(from: url))
        let now = Date()
        try PickupSnapshotFile.write(.make(records: [], at: now), to: url)
        XCTAssertEqual(try PickupSnapshotFile.read(from: url, at: now).items.count, 0)
        XCTAssertThrowsError(try PickupSnapshotFile.read(from: url, at: now.addingTimeInterval(86400)))
    }

    func testEverySuccessfulMutationRefreshesSnapshotAndFailureInvalidates() async throws {
        let file = temporaryURL()
        let snapshotURL = file.deletingLastPathComponent().appendingPathComponent("snapshot.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = PickupRepository(fileURL: file, surfacePublisher: { try PickupSnapshotFile.write($0, to: snapshotURL) })
        let result = try await repo.importText("取件码 1234", source: .smsAutomation)
        let item = try XCTUnwrap(result.addedRecords.first)
        XCTAssertEqual(try PickupSnapshotFile.read(from: snapshotURL).items.map(\.id), [item.id])
        _ = try await repo.complete(id: item.id)
        XCTAssertTrue(try PickupSnapshotFile.read(from: snapshotURL).items.isEmpty)
        _ = try await repo.undoCompletion(id: item.id)
        _ = try await repo.update(id: item.id, code: "5678", location: "北门")
        XCTAssertEqual(try PickupSnapshotFile.read(from: snapshotURL).items.first?.code, "5678")
        _ = try await repo.handOff(ids: [item.id])
        XCTAssertTrue(try PickupSnapshotFile.read(from: snapshotURL).items.isEmpty)
        _ = try await repo.undoCompletion(id: item.id)
        XCTAssertEqual(try PickupSnapshotFile.read(from: snapshotURL).items.count, 1)
        _ = try await repo.complete(id: item.id)
        _ = try await repo.archive(id: item.id)
        _ = try await repo.restoreFromArchive(id: item.id)
        XCTAssertTrue(try PickupSnapshotFile.read(from: snapshotURL).items.isEmpty)
        _ = try await repo.undoCompletion(id: item.id)
        XCTAssertEqual(try PickupSnapshotFile.read(from: snapshotURL).items.count, 1)
        try Data("broken".utf8).write(to: file)
        do { _ = try await repo.records(); XCTFail("corrupt source must fail") } catch { }
        XCTAssertThrowsError(try PickupSnapshotFile.read(from: snapshotURL))
    }

    func testSnapshotFailureDoesNotUndoSuccessfulSourceCommit() async throws {
        let url = temporaryURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = PickupRepository(fileURL: url, surfacePublisher: { _ in throw CocoaError(.fileWriteNoPermission) })
        _ = try await repo.importText("取件码 7890", source: .paste)
        let records = try await repo.records()
        let failed = await repo.surfaceRefreshFailed
        XCTAssertEqual(records.count, 1)
        XCTAssertTrue(failed)
    }

    func testLinkContainsIdentityWithoutCode() {
        let id = UUID()
        XCTAssertEqual(PickupSurfaceLink.recordID(in: PickupSurfaceLink.url(id: id)), id)
        XCTAssertNil(PickupSurfaceLink.recordID(in: URL(string: "https://pickup?id=\(id)")!))
    }

    func testHandoffImportCommonLocationAndMissingLocationMapping() async throws {
        let file = temporaryURL()
        let snapshotURL = file.deletingLastPathComponent().appendingPathComponent("snapshot.json")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let repo = PickupRepository(fileURL: file, surfacePublisher: { try PickupSnapshotFile.write($0, to: snapshotURL) })
        _ = try await repo.importText("取件码 1234", source: .smsAutomation, defaultLocation: " 北门 ")
        let snapshot = try PickupSnapshotFile.read(from: snapshotURL)
        XCTAssertEqual(snapshot.items[0].locationKey, "北门")
        XCTAssertTrue(snapshot.items[0].usesCommonLocation)
        let missing = record(code: "5678", location: nil, time: 1)
        let other = PickupSurfaceSnapshot.make(records: [missing])
        XCTAssertEqual(other.items(at: "").count, 1)
        XCTAssertEqual(other.items[0].location, "地点待确认")
        let package = PickupHandoffPackage(records: [missing])
        _ = try await repo.importHandoffPackage(package)
        XCTAssertEqual(try PickupSnapshotFile.read(from: snapshotURL).items.count, 2)
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("records.json")
    }

    private func record(code: String, location: String?, time: TimeInterval) -> PickupRecord {
        PickupRecord(id: UUID(), rawText: "secret SMS", code: code, location: location, platform: nil,
                     createdAt: Date(timeIntervalSince1970: time), source: .paste, fingerprint: code,
                     completedAt: nil, archivedAt: nil)
    }
}
