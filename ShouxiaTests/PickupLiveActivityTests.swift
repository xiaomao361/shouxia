import XCTest
@testable import Shouxia

@MainActor
final class PickupLiveActivityTests: XCTestCase {
    func testDisabledPermissionDoesNotStartOrClaimSuccess() async {
        let client = FakePickupActivityClient()
        client.isAuthorized = false
        let controller = PickupLiveActivityController(client: client)
        controller.start(state("1234"))
        await controller.waitUntilIdle()
        XCTAssertFalse(controller.isEnabled)
        XCTAssertNotNil(controller.message)
        XCTAssertTrue(client.events.isEmpty)
    }

    func testRequestFailureIsVisibleAndCanBeRetried() async {
        let client = FakePickupActivityClient()
        client.failStart = true
        let controller = PickupLiveActivityController(client: client)
        controller.start(state("1234"))
        await controller.waitUntilIdle()
        XCTAssertFalse(controller.isEnabled)
        XCTAssertNotNil(controller.message)
        client.failStart = false
        controller.start(state("5678"))
        await controller.waitUntilIdle()
        XCTAssertTrue(controller.isEnabled)
        XCTAssertNil(controller.message)
        XCTAssertEqual(client.current?.code, "5678")
    }

    func testSwitchCorrectionAndStopUpdateTheSameActivity() async {
        let client = FakePickupActivityClient()
        let controller = PickupLiveActivityController(client: client)
        controller.start(state("1234"))
        await controller.waitUntilIdle()
        controller.update(state("5678"))
        await controller.waitUntilIdle()
        controller.update(state("5679"))
        await controller.waitUntilIdle()
        controller.stop()
        await controller.waitUntilIdle()
        XCTAssertEqual(client.events, ["end", "start:1234", "update:5678", "update:5679", "end"])
        XCTAssertNil(client.current)
        XCTAssertFalse(controller.isEnabled)
    }

    func testClosingDuringStartupCleanupNeverStartsAnActivity() async {
        let client = FakePickupActivityClient()
        client.pauseEnd = true
        let controller = PickupLiveActivityController(client: client)
        controller.start(state("1234"))
        await client.waitForPause()
        controller.stop()
        client.resume()
        await controller.waitUntilIdle()
        XCTAssertFalse(client.events.contains(where: { $0.hasPrefix("start:") }))
        XCTAssertFalse(controller.isEnabled)
    }

    func testStopWinsAgainstAnInFlightUpdate() async {
        let client = FakePickupActivityClient()
        let controller = PickupLiveActivityController(client: client)
        controller.start(state("1234"))
        await controller.waitUntilIdle()
        client.pauseUpdate = true
        controller.update(state("5678"))
        await client.waitForPause()
        controller.update(state("9999"))
        controller.stop()
        client.resume()
        await controller.waitUntilIdle()
        XCTAssertEqual(client.events.last, "end")
        XCTAssertFalse(client.events.contains("update:9999"))
        XCTAssertNil(client.current)
    }

    func testSystemDismissalDoesNotAutomaticallyRestart() async {
        let client = FakePickupActivityClient()
        let controller = PickupLiveActivityController(client: client)
        controller.start(state("1234"))
        await controller.waitUntilIdle()
        client.isActive = false
        controller.update(state("5678"))
        await controller.waitUntilIdle()
        XCTAssertFalse(controller.isEnabled)
        XCTAssertNotNil(controller.message)
        XCTAssertEqual(client.events.filter { $0.hasPrefix("start:") }.count, 1)
    }

    func testEmptyGroupEndsActivityAndLaterUpdatesCannotReopenIt() async {
        let client = FakePickupActivityClient()
        let controller = PickupLiveActivityController(client: client)
        controller.start(state("1234"))
        await controller.waitUntilIdle()
        controller.update(nil)
        await controller.waitUntilIdle()
        controller.update(state("5678"))
        await controller.waitUntilIdle()
        XCTAssertEqual(client.events, ["end", "start:1234", "end"])
        XCTAssertFalse(controller.isEnabled)
    }

    func testPayloadPreservesUnknownAndCommonLocationWithoutNotificationText() throws {
        var record = record("1234", location: "  \n ")
        let unknown = try XCTUnwrap(PickupActivityState.make(records: [record], selectedID: record.id))
        XCTAssertEqual(unknown.location, "地点待确认")
        record.location = "北门"
        record.locationSource = .commonDefault
        let common = try XCTUnwrap(PickupActivityState.make(records: [record], selectedID: record.id))
        XCTAssertTrue(common.usesCommonLocation)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(common)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["code", "location", "usesCommonLocation", "remainingCount"])
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(common), as: UTF8.self).contains("13800138000"))
    }

    func testGroupCountExcludesCompletedAndArchivedAndMissingSelectionIsNotSubstituted() throws {
        let first = record("1234", location: "北门")
        let second = record("5678", location: "北门")
        var completed = record("8888", location: "北门")
        completed.completedAt = Date()
        var archived = record("9999", location: "北门")
        archived.archivedAt = Date()
        let records = [first, second, completed, archived]
        let payload = try XCTUnwrap(PickupActivityState.make(records: records, selectedID: second.id))
        XCTAssertEqual(payload.remainingCount, 2)
        XCTAssertEqual(payload.code, "5678")
        XCTAssertNil(PickupActivityState.make(records: records, selectedID: completed.id))
        XCTAssertNil(PickupActivityState.make(records: records, selectedID: UUID()))
        XCTAssertNil(PickupActivityState.make(records: [], selectedID: first.id))
    }

    private func state(_ code: String) -> PickupActivityState {
        .init(code: code, location: "北门", usesCommonLocation: false, remainingCount: 2)
    }

    private func record(_ code: String, location: String?) -> PickupRecord {
        PickupRecord(id: UUID(), rawText: "13800138000 私人短信", code: code, location: location,
                     platform: nil, createdAt: Date(), source: .paste, fingerprint: "private-fingerprint",
                     completedAt: nil, archivedAt: nil)
    }
}

@MainActor
private final class FakePickupActivityClient: PickupActivityClient {
    var isAuthorized = true
    var isActive = false
    var failStart = false
    var events: [String] = []
    var current: PickupActivityState?
    var pauseEnd = false
    var pauseUpdate = false
    private var continuation: CheckedContinuation<Void, Never>?
    private var pauseObserver: CheckedContinuation<Void, Never>?

    func start(_ state: PickupActivityState) throws {
        if failStart { throw NSError(domain: "ActivityTest", code: 1) }
        events.append("start:\(state.code)")
        current = state
        isActive = true
    }

    func update(_ state: PickupActivityState) async {
        if pauseUpdate { pauseUpdate = false; await pause() }
        events.append("update:\(state.code)")
        current = state
    }

    func end() async {
        if pauseEnd { pauseEnd = false; await pause() }
        events.append("end")
        current = nil
        isActive = false
    }

    func waitForPause() async {
        if continuation != nil { return }
        await withCheckedContinuation { pauseObserver = $0 }
    }

    func resume() { continuation?.resume(); continuation = nil }

    private func pause() async {
        await withCheckedContinuation {
            continuation = $0
            pauseObserver?.resume()
            pauseObserver = nil
        }
    }
}
