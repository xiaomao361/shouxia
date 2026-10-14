import Combine
import XCTest
@testable import Shouxia

final class PickupStoreTests: XCTestCase {
    @MainActor
    func testImportCompletionAndUndoPublishPendingRecords() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = PickupRepository(fileURL: root.appendingPathComponent("records.json"))
        let store = PickupStore(repository: repository)
        var pendingCounts: [Int] = []
        let subscription = store.$records.sink { records in
            pendingCounts.append(records.filter { !$0.isCompleted && !$0.isArchived }.count)
        }
        await store.load()
        await store.importText("取件码1234，北门驿站", source: .paste)
        let record = try XCTUnwrap(store.pendingRecords.first)
        XCTAssertEqual(pendingCounts.last, 1)
        store.beginCompletion(record)
        XCTAssertEqual(pendingCounts.last, 0)
        await store.persistCompletion(record)
        XCTAssertEqual(store.historyRecords.count, 1)
        await store.undoLastCompletion()
        XCTAssertEqual(pendingCounts.last, 1)
        XCTAssertTrue(store.historyRecords.isEmpty)
        withExtendedLifetime(subscription) {}
    }

    @MainActor
    func testReadFailurePublishesErrorAndRecoveryClearsFailure() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("records.json")
        try Data("invalid-json".utf8).write(to: file)
        let store = PickupStore(repository: PickupRepository(fileURL: file))
        var failures: [Bool] = []
        let subscription = store.$loadFailed.sink { failures.append($0) }
        await store.load()
        XCTAssertEqual(failures.last, true)
        guard case .error = store.notice else { return XCTFail("read failure must remain an error") }
        try Data("[]".utf8).write(to: file)
        await store.load()
        XCTAssertEqual(failures.last, false)
        XCTAssertTrue(store.records.isEmpty)
        withExtendedLifetime(subscription) {}
    }
}
