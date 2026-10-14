import XCTest
@testable import Shouxia

final class PickupImageShareTests: XCTestCase {
    private func workspace() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: url) }
        return url
    }

    private func batch(id: UUID = UUID(), code: String = "3-2-4012", location: String? = "北门驿站") -> PickupImageShareBatch {
        PickupImageShareBatch(id: id, items: [.init(code: code, location: location, platform: "菜鸟")])
    }

    func testQueueContainsOnlySelectedMinimumFields() throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let expected = batch()
        try queue.enqueue(expected)
        let file = try XCTUnwrap(queue.pendingFiles().first)
        XCTAssertEqual(try queue.read(file), expected)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["version", "id", "items"])
        let items = try XCTUnwrap(json["items"] as? [[String: Any]])
        XCTAssertEqual(Set(items[0].keys), ["code", "location", "platform"])
    }

    func testInvalidAndEmptyBatchesCannotEnterQueue() throws {
        let queue = PickupImageShareQueue(directory: try workspace().appendingPathComponent("queue"))
        XCTAssertThrowsError(try queue.enqueue(.init(items: [])))
        XCTAssertThrowsError(try queue.enqueue(batch(code: "13812345678")))
        XCTAssertThrowsError(try queue.enqueue(batch(location: "联系电话13812345678")))
        XCTAssertThrowsError(try queue.enqueue(batch(location: "北门\n取件码 9999")))
        let item = batch().items[0]
        XCTAssertThrowsError(try queue.enqueue(.init(items: [item, item])))
        XCTAssertEqual(try queue.pendingFiles().count, 0)
    }

    func testReceiveSavesSourceFieldsAndAcknowledgesAfterCommit() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let expected = batch(location: "一号柜")
        try queue.enqueue(expected)
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 1)
        XCTAssertEqual(receipt.failedBatchCount, 0)
        XCTAssertTrue(try queue.pendingFiles().isEmpty)
        let records = try await repository.records()
        let record = try XCTUnwrap(records.first)
        XCTAssertEqual(record.location, "一号柜")
        XCTAssertEqual(record.locationSource, .recognized)
        XCTAssertEqual(record.source, .imageRecognition)
        XCTAssertEqual(record.importBatchID, expected.id)
        let reopened = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let persisted = try await reopened.records()
        XCTAssertEqual(persisted.count, 1)
        XCTAssertEqual(persisted.first?.code, expected.items.first?.code)
    }

    func testRetryAfterCompletionDoesNotRestoreConsumedPackage() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let package = batch()
        try queue.enqueue(package)
        _ = try await repository.receiveSharedImages(from: queue)
        let records = try await repository.records()
        _ = try await repository.complete(id: XCTUnwrap(records.first).id)
        // Models a crash after database commit and before queue acknowledgement.
        try queue.enqueue(package)
        let retried = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(retried.addedCount, 0)
        XCTAssertEqual(retried.duplicateCount, 1)
        let after = try await repository.records()
        XCTAssertEqual(after.count, 1)
        XCTAssertTrue(try XCTUnwrap(after.first).isCompleted)
    }

    func testFuturePackageMayReuseCompletedCodeAndDefaultLocation() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        try queue.enqueue(batch())
        _ = try await repository.receiveSharedImages(from: queue)
        let first = try await repository.records()
        _ = try await repository.complete(id: XCTUnwrap(first.first).id)
        try queue.enqueue(batch(location: nil))
        let next = try await repository.receiveSharedImages(from: queue, defaultLocation: "南门驿站")
        XCTAssertEqual(next.addedCount, 1)
        let records = try await repository.records()
        let pending = try XCTUnwrap(records.first { !$0.isCompleted })
        XCTAssertEqual(pending.location, "南门驿站")
        XCTAssertEqual(pending.locationSource, .commonDefault)
    }

    func testBrokenPackageRetainedWhileValidPackageContinues() async throws {
        let root = try workspace()
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(batch())
        let corrupt = queue.directory.appendingPathComponent("bad.json")
        try Data("invalid json".utf8).write(to: corrupt)
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 1)
        XCTAssertEqual(receipt.failedBatchCount, 1)
        XCTAssertEqual(try queue.pendingFiles().map { $0.resolvingSymlinksInPath() }, [corrupt.resolvingSymlinksInPath()])
    }

    func testDatabaseFailureDoesNotAcknowledgeOrOverwriteOldData() async throws {
        let root = try workspace()
        let file = root.appendingPathComponent("pickups.json")
        let original = Data("broken existing records".utf8)
        try original.write(to: file)
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(batch())
        let repository = PickupRepository(fileURL: file)
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 0)
        XCTAssertEqual(receipt.failedBatchCount, 1)
        XCTAssertEqual(try queue.pendingFiles().count, 1)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testMatchesExistingSMSPendingCode() async throws {
        let root = try workspace()
        let repository = PickupRepository(fileURL: root.appendingPathComponent("pickups.json"))
        _ = try await repository.importText("取件码 3-2-4012", source: .smsAutomation)
        let queue = PickupImageShareQueue(directory: root.appendingPathComponent("queue"))
        try queue.enqueue(batch())
        let receipt = try await repository.receiveSharedImages(from: queue)
        XCTAssertEqual(receipt.addedCount, 0)
        XCTAssertEqual(receipt.duplicateCount, 1)
        let records = try await repository.records()
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.source, .smsAutomation)
    }
}
