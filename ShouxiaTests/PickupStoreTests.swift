import Combine
import XCTest
@testable import Shouxia

final class PickupStoreTests: XCTestCase {
    @MainActor
    func testHandoffImportFailureKeepsRecordsAndProvidesVisibleRecoveryMessage() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appendingPathComponent("blocker")
        let original = Data("keep this file".utf8)
        try original.write(to: blocker)
        let store = PickupStore(repository: PickupRepository(fileURL: blocker.appendingPathComponent("records.json")))
        let record = PickupRecord(id: UUID(), rawText: "取件码1234", code: "1234", location: "北门驿站",
                                  platform: nil, createdAt: Date(), source: .paste, fingerprint: "test-handoff",
                                  completedAt: nil, archivedAt: nil)
        let imported = await store.importHandoffPackage(PickupHandoffPackage(records: [record]))
        XCTAssertFalse(imported)
        XCTAssertTrue(store.records.isEmpty)
        guard case let .error(message)? = store.notice else { return XCTFail("Failed import needs an error for the review sheet") }
        XCTAssertFalse(message.isEmpty)
        XCTAssertEqual(try Data(contentsOf: blocker), original)
    }

    @MainActor
    func testReviewGateRejectsWholeUnconfirmedSelectionBeforeAnyWrite() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("records.json")
        let store = PickupStore(repository: PickupRepository(fileURL: file))
        let valid = ImagePickupCandidate(code: "1234", location: "北门驿站", platform: nil, confidence: 0.95, isLabelled: true)
        let truncated = ImagePickupCandidate(code: "5678", location: "南门驿站", platform: nil, confidence: 0.95,
                                              isLabelled: true, reviewIssue: .truncated)
        let saved = await store.importImageCandidates([valid, truncated])
        XCTAssertFalse(saved)
        XCTAssertTrue(store.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        guard case .error = store.notice else { return XCTFail("Rejected review must stay an error") }
    }

    @MainActor
    func testReviewedFieldsAreSavedWithoutReparsingAndWriteFailureKeepsReview() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let candidate = ImagePickupCandidate(code: "1234", location: "幸福里[A区]快递柜", platform: "中通", confidence: 0.95, isLabelled: true)
        let store = PickupStore(repository: PickupRepository(fileURL: root.appendingPathComponent("records.json")))
        let saved = await store.importImageCandidates([candidate])
        XCTAssertTrue(saved)
        XCTAssertEqual(store.records.first?.location, "幸福里[A区]快递柜")
        let blocker = root.appendingPathComponent("blocker")
        try Data("do not overwrite".utf8).write(to: blocker)
        let failing = PickupStore(repository: PickupRepository(fileURL: blocker.appendingPathComponent("records.json")))
        let review = PickupCandidateReview(candidates: [candidate])
        let failed = await failing.importImageCandidates(try review.validatedSelection().map(\.candidate))
        XCTAssertFalse(failed)
        XCTAssertEqual(review.selectedCount, 1)
        XCTAssertEqual(try Data(contentsOf: blocker), Data("do not overwrite".utf8))
    }

    @MainActor
    func testPartialRecognitionSavesValidNoticeAndReportsMissingOneAcrossSources() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let text = "【中通】已到北门驿站，取件码1234\n【丰巢】取件码****，已到南门快递柜"
        let store = PickupStore(repository: PickupRepository(fileURL: root.appendingPathComponent("manual.json")))
        await store.importText(text, source: .paste)
        XCTAssertEqual(store.records.count, 1)
        guard case let .error(message)? = store.notice else { return XCTFail("Partial import must remain visible") }
        XCTAssertTrue(message.contains("已添加 1 个"))
        XCTAssertTrue(message.contains("另有 1 条"))
        await store.importText(text, source: .paste)
        guard case let .error(retry)? = store.notice else { return XCTFail("Partial duplicate retry must remain visible") }
        XCTAssertTrue(retry.contains("已存在"))
        XCTAssertFalse(retry.contains("已添加 0"))

        let images = PickupStore(repository: PickupRepository(fileURL: root.appendingPathComponent("images.json")))
        let candidates = try ImagePickupExtractor().candidates(from: text.components(separatedBy: .newlines).map {
            RecognizedTextLine(text: $0, confidence: 0.95, minX: 0, midY: 0)
        })
        XCTAssertEqual(candidates.first?.unresolvedNotificationCount, 1)
        XCTAssertEqual(try PickupSharedTextParser().candidates(from: text).first?.unresolvedNotificationCount, 1)
        await images.importImageCandidates(candidates)
        guard case let .error(imageMessage)? = images.notice else { return XCTFail("Image omission must remain visible") }
        XCTAssertTrue(imageMessage.contains("另有 1 条"))

        let automatic = PickupStore(repository: PickupRepository(fileURL: root.appendingPathComponent("automatic.json")))
        await automatic.importClipboardAutomatically(text)
        XCTAssertEqual(automatic.records.count, 1)
        guard case .error = automatic.notice else { return XCTFail("Automatic partial import cannot be plain success") }
    }

    @MainActor
    func testImageSaveKeepsSameCodeAtTwoPlacesAndExactRetryDeduplicates() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PickupStore(repository: PickupRepository(fileURL: root.appendingPathComponent("records.json")))
        let candidates = [
            ImagePickupCandidate(code: "1234", location: "北门驿站", platform: "中通", confidence: 0.95, isLabelled: true),
            ImagePickupCandidate(code: "1234", location: "南门便利店", platform: "圆通", confidence: 0.95, isLabelled: true),
        ]
        await store.importImageCandidates(candidates)
        XCTAssertEqual(store.records.map(\.location), ["北门驿站", "南门便利店"])
        await store.importImageCandidates(candidates)
        XCTAssertEqual(store.records.count, 2)
        XCTAssertEqual(store.notice, .neutral("这些取件码已添加"))
    }

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
