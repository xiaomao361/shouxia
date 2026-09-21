import XCTest
@testable import Shouxia

final class PickupActivityTests: XCTestCase {
    func testStateUsesAllPendingIncludesNewArrivalsAndAlwaysShowsCode() {
        let now = Date()
        var first = record("1111", time: now)
        let second = record("2222", time: now.addingTimeInterval(1))
        let session = PickupActivitySession(now: now)
        XCTAssertEqual(session.state(records: [first], now: now)?.code, "1111")
        XCTAssertEqual(session.state(records: [first, second], now: now)?.code, "2222")
        XCTAssertEqual(session.state(records: [first, second], now: now)?.remainingCount, 2)
        first.completedAt = now
        XCTAssertEqual(session.state(records: [first, second], now: now)?.remainingCount, 1)
        XCTAssertNil(session.state(records: [first, second], now: now.addingTimeInterval(8 * 3600)))
        XCTAssertNil(session.state(records: [first], now: now))
    }

    @MainActor
    func testSettingStartsWithoutPickupModeAndDisablingDoesNotCompleteRecords() async throws {
        let c = try await makeContext(); defer { c.cleanup() }
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 0)
        c.controller.setEnabled(true); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 1)
        XCTAssertEqual(c.client.lastState?.code, "1234")
        c.controller.setEnabled(false); await c.controller.waitUntilIdle()
        let records = try await c.repository.records()
        XCTAssertFalse(records[0].isCompleted)
        XCTAssertNil(c.controller.session)
        XCTAssertFalse(c.defaults.bool(forKey: "pickupLiveActivityEnabled"))
    }

    @MainActor
    func testCompletionEndsAndUndoAutomaticallyRestoresWhenEnabled() async throws {
        let c = try await makeContext(); defer { c.cleanup() }
        c.controller.setEnabled(true); await c.controller.waitUntilIdle()
        _ = try await c.repository.complete(id: c.records[0].id)
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertNil(c.controller.session)
        XCTAssertTrue(c.controller.isEnabled)
        _ = try await c.repository.undoCompletion(id: c.records[0].id)
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 2)
    }

    @MainActor
    func testBackgroundUpdatesExistingButWaitsForForegroundToStart() async throws {
        let c = try await makeContext(); defer { c.cleanup() }
        c.client.canStart = false
        c.controller.setEnabled(true); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 0)
        XCTAssertTrue(c.controller.isEnabled)
        c.client.canStart = true
        c.controller.refresh(); await c.controller.waitUntilIdle()
        c.client.canStart = false
        _ = try await c.repository.importText("取件码 5678", source: .smsAutomation)
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 1)
        XCTAssertEqual(c.client.lastState?.remainingCount, 2)
        c.client.activeSessionIDs = []
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 1)
        c.client.canStart = true
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 2)
    }

    @MainActor
    func testRelaunchRestoresPreferenceAndRenewsExpiredSystemSession() async throws {
        let c = try await makeContext(); defer { c.cleanup() }
        c.controller.setEnabled(true); await c.controller.waitUntilIdle()
        let restored = PickupLiveActivityController(client: c.client, repository: c.repository, defaults: c.defaults)
        restored.refresh(); await restored.waitUntilIdle()
        XCTAssertTrue(restored.isEnabled)
        XCTAssertEqual(c.client.starts, 1)
        let expired = PickupLiveActivityController(client: c.client, repository: c.repository, defaults: c.defaults,
                                                  now: { Date().addingTimeInterval(9 * 3600) })
        expired.refresh(); await expired.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 2)
        XCTAssertEqual(c.client.lastState?.remainingCount, 1)
    }

    @MainActor
    func testFailuresRemainDistinctAndDoNotLoseUserPreference() async throws {
        let c = try await makeContext(); defer { c.cleanup() }
        c.client.failStart = true
        c.controller.setEnabled(true); await c.controller.waitUntilIdle()
        XCTAssertNil(c.controller.session)
        XCTAssertTrue(c.controller.isEnabled)
        XCTAssertEqual(c.defaults.dictionary(forKey: "pickupActivityDiagnostic.v1")?["status"] as? String, "startFailed")
        c.client.failStart = false
        c.controller.refresh(); await c.controller.waitUntilIdle()
        try Data("broken".utf8).write(to: c.url)
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertNil(c.controller.session)
        XCTAssertTrue(c.client.activeSessionIDs.isEmpty)
        XCTAssertTrue(c.controller.isEnabled)
        XCTAssertEqual(c.defaults.dictionary(forKey: "pickupActivityDiagnostic.v1")?["status"] as? String, "readFailed")
    }

    @MainActor
    func testDisablingDuringSuspendedStartPreventsLateActivity() async throws {
        let c = try await makeContext(); defer { c.cleanup() }
        c.client.suspendNextEnd = true
        c.controller.setEnabled(true)
        while c.client.endContinuation == nil { await Task.yield() }
        c.controller.setEnabled(false)
        c.client.endContinuation?.resume(); c.client.endContinuation = nil
        await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 0)
        XCTAssertNil(c.controller.session)
    }

    @MainActor
    func testSystemPermissionDeniedRetainsPreferenceAndDoesNotStart() async throws {
        let c = try await makeContext(); defer { c.cleanup() }
        c.client.isAuthorized = false
        c.controller.setEnabled(true); await c.controller.waitUntilIdle()
        XCTAssertTrue(c.controller.isEnabled)
        XCTAssertEqual(c.client.starts, 0)
        XCTAssertNotNil(c.controller.message)
        c.client.isAuthorized = true
        c.controller.refresh(); await c.controller.waitUntilIdle()
        XCTAssertEqual(c.client.starts, 1)
    }

    private func record(_ code: String, time: Date) -> PickupRecord {
        PickupRecord(id: UUID(), rawText: "取件码 \(code)", code: code, location: "北门", platform: nil,
                     createdAt: time, source: .paste, fingerprint: code, completedAt: nil, archivedAt: nil)
    }

    @MainActor private func makeContext() async throws -> Context {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("records.json")
        let repository = PickupRepository(fileURL: url)
        _ = try await repository.importText("取件码 1234", source: .paste)
        let records = try await repository.records()
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let client = FakeActivityClient()
        return Context(url: url, suite: suite, repository: repository, records: records, defaults: defaults, client: client,
                       controller: PickupLiveActivityController(client: client, repository: repository, defaults: defaults))
    }

    @MainActor private struct Context {
        let url: URL
        let suite: String
        let repository: PickupRepository
        let records: [PickupRecord]
        let defaults: UserDefaults
        let client: FakeActivityClient
        let controller: PickupLiveActivityController
        func cleanup() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
        }
    }
}

@MainActor private final class FakeActivityClient: PickupActivityClient {
    var isAuthorized = true
    var canStart = true
    var activeSessionIDs: [UUID] = []
    var starts = 0
    var lastState: PickupActivityContent?
    var failStart = false
    var suspendNextEnd = false
    var endContinuation: CheckedContinuation<Void, Never>?
    func start(session: PickupActivitySession, state: PickupActivityContent) throws {
        if failStart { throw CocoaError(.featureUnsupported) }
        starts += 1
        activeSessionIDs = [session.id]
        lastState = state
    }
    func update(session: PickupActivitySession, state: PickupActivityContent) async { lastState = state }
    func end() async {
        if suspendNextEnd {
            suspendNextEnd = false
            await withCheckedContinuation { endContinuation = $0 }
        }
        activeSessionIDs = []
        lastState = nil
    }
}
