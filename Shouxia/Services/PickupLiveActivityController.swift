import ActivityKit
import Foundation
import Observation

typealias PickupActivityState = PickupActivityAttributes.ContentState

extension PickupActivityState {
    /// Count only the pending records in the current pickup group, not the inbox.
    static func make(records: [PickupRecord], selectedID: UUID) -> Self? {
        let pending = records.filter { !$0.isCompleted && !$0.isArchived }
        guard let record = pending.first(where: { $0.id == selectedID }) else { return nil }
        let location = record.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Self(
            code: record.code,
            location: location.isEmpty ? "地点待确认" : location,
            usesCommonLocation: record.locationSource == .commonDefault,
            remainingCount: pending.count
        )
    }
}

@MainActor
protocol PickupActivityClient: AnyObject {
    var isAuthorized: Bool { get }
    var isActive: Bool { get }
    func start(_ state: PickupActivityState) throws
    func update(_ state: PickupActivityState) async
    func end() async
}

@MainActor
final class SystemPickupActivityClient: PickupActivityClient {
    // Keep only the ID: ActivityKit's Activity reference is not Sendable in this SDK.
    private var activityID: String?

    var isAuthorized: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    var isActive: Bool {
        guard let activity = Activity<PickupActivityAttributes>.activities.first(where: { $0.id == activityID }) else { return false }
        return activity.activityState == .active || activity.activityState == .stale
    }

    func start(_ state: PickupActivityState) throws {
        let activity = try Activity<PickupActivityAttributes>.request(
            attributes: PickupActivityAttributes(sessionID: UUID()),
            content: Self.content(state),
            pushType: nil
        )
        activityID = activity.id
    }

    func update(_ state: PickupActivityState) async {
        await Self.updateActivity(id: activityID, state: state)
    }

    func end() async {
        await Self.endActivities()
        activityID = nil
    }

    // Activity references stay on the nonisolated executor that runs their async APIs.
    private nonisolated static func updateActivity(id: String?, state: PickupActivityState) async {
        guard let activity = Activity<PickupActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(content(state))
    }

    private nonisolated static func endActivities() async {
        // Include activities left behind by a previous process that was terminated.
        for item in Activity<PickupActivityAttributes>.activities {
            await item.end(nil, dismissalPolicy: .immediate)
        }
    }

    private nonisolated static func content(_ state: PickupActivityState) -> ActivityContent<PickupActivityState> {
        ActivityContent(state: state, staleDate: Date().addingTimeInterval(30 * 60))
    }
}

/// Serializes ActivityKit operations; a late update must never overtake an end.
@MainActor
@Observable
final class PickupLiveActivityController {
    private(set) var isEnabled = false
    private(set) var isBusy = false
    private(set) var message: String?
    private let client: any PickupActivityClient
    private var desiredState: PickupActivityState?
    private var revision = 0
    private var needsStart = false
    private var worker: Task<Void, Never>?

    init(client: any PickupActivityClient = SystemPickupActivityClient()) {
        self.client = client
    }

    func start(_ state: PickupActivityState) {
        guard !isEnabled else { return }
        message = nil
        guard client.isAuthorized else {
            message = "实时活动未开启，请在系统设置中允许收下使用实时活动。"
            return
        }
        desiredState = state
        needsStart = true
        isEnabled = true
        enqueue()
    }

    func update(_ state: PickupActivityState?) {
        guard isEnabled else { return }
        guard let state else { stop(); return }
        desiredState = state
        enqueue()
    }

    func stop() {
        isEnabled = false
        needsStart = false
        desiredState = nil
        message = nil
        enqueue()
    }

    func dismissMessage() { message = nil }

    func waitUntilIdle() async { await worker?.value }

    private func enqueue() {
        revision &+= 1
        guard worker == nil else { return }
        isBusy = true
        worker = Task { await drain() }
    }

    private func drain() async {
        while true {
            let currentRevision = revision
            if let state = desiredState {
                if needsStart {
                    await client.end()
                    // Closing the pickup view while cleanup runs cancels this start.
                    if currentRevision != revision { continue }
                    needsStart = false
                    do {
                        try client.start(state)
                    } catch {
                        isEnabled = false
                        desiredState = nil
                        message = "暂时无法开启实时活动，请稍后重试。手机取件仍可正常使用。"
                    }
                } else if client.isActive {
                    await client.update(state)
                } else {
                    isEnabled = false
                    desiredState = nil
                    message = "实时活动已结束，需要时可以重新开启。"
                }
            } else {
                await client.end()
            }
            if currentRevision == revision { break }
        }
        isBusy = false
        worker = nil
    }
}
