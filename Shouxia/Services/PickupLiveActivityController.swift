#if os(iOS)
import ActivityKit
import UIKit
#endif
import Foundation
import Observation

@MainActor
protocol PickupActivityClient: AnyObject {
    var isAuthorized: Bool { get }
    var canStart: Bool { get }
    var activeSessionIDs: [UUID] { get }
    func start(session: PickupActivitySession, state: PickupActivityContent) throws
    func update(session: PickupActivitySession, state: PickupActivityContent) async
    func end() async
}

#if os(iOS)
@MainActor
final class SystemPickupActivityClient: PickupActivityClient {
    var isAuthorized: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    var canStart: Bool { UIApplication.shared.applicationState == .active }
    var activeSessionIDs: [UUID] {
        Activity<PickupActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }.map(\.attributes.sessionID)
    }

    func start(session: PickupActivitySession, state: PickupActivityContent) throws {
        _ = try Activity<PickupActivityAttributes>.request(
            attributes: PickupActivityAttributes(sessionID: session.id, expiresAt: session.expiresAt),
            content: ActivityContent(state: state, staleDate: session.expiresAt), pushType: nil)
    }

    func update(session: PickupActivitySession, state: PickupActivityContent) async {
        await Self.updateActivity(session: session, state: state)
    }

    func end() async { await Self.endActivities() }

    private nonisolated static func updateActivity(session: PickupActivitySession, state: PickupActivityContent) async {
        guard let activity = Activity<PickupActivityAttributes>.activities.first(where: {
            $0.attributes.sessionID == session.id
        }) else { return }
        await activity.update(ActivityContent(state: state, staleDate: session.expiresAt))
    }

    private nonisolated static func endActivities() async {
        for activity in Activity<PickupActivityAttributes>.activities {
            guard activity.activityState == .active || activity.activityState == .stale else { continue }
            await activity.end(ActivityContent(state: .finished, staleDate: nil),
                               dismissalPolicy: .immediate)
        }
    }
}
#endif

/// The setting persists independently of the system's limited activity lifetime.
/// Repository changes update existing activities; new ones require a foreground app.
@MainActor
@Observable
final class PickupLiveActivityController {
    #if os(iOS)
    static let shared = PickupLiveActivityController(client: SystemPickupActivityClient())
    #endif
    private(set) var isEnabled: Bool
    private(set) var session: PickupActivitySession?
    private(set) var isBusy = false
    private(set) var message: String?
    private let client: any PickupActivityClient
    private let repository: PickupRepository
    private let defaults: UserDefaults
    private let now: () -> Date
    private let persistenceKey = "pickupLiveActivitySession.v2"
    private let enabledKey = "pickupLiveActivityEnabled"
    private var revision = 0
    private var worker: Task<Void, Never>?

    init(client: any PickupActivityClient, repository: PickupRepository = .shared,
         defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.client = client
        self.repository = repository
        self.defaults = defaults
        self.now = now
        isEnabled = defaults.bool(forKey: enabledKey)
        if let data = defaults.data(forKey: persistenceKey) {
            do { session = try JSONDecoder().decode(PickupActivitySession.self, from: data) }
            catch { message = "展示将在下次打开收下时恢复" }
        }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: enabledKey)
        message = nil
        enqueue()
    }

    func refresh() { enqueue() }
    func refreshAndWait() async { enqueue(); await worker?.value }
    func waitUntilIdle() async { await worker?.value }

    /// A source failure ends display, but does not change the user's preference.
    func sourceBecameUnavailable() {
        clearSession()
        recordDiagnostic("sourceUnavailable")
        message = "暂时无法读取待取信息"
        // Do not enqueue a source read here: this signal can originate inside drain.
        // The caller's next refresh also verifies current source truth.
        enqueueEndOnly()
    }

    private var mustEndForSourceFailure = false
    private func enqueueEndOnly() { mustEndForSourceFailure = true; enqueue() }

    private func enqueue() {
        revision &+= 1
        guard worker == nil else { return }
        isBusy = true
        worker = Task { await drain() }
    }

    private func drain() async {
        while true {
            let currentRevision = revision
            if mustEndForSourceFailure {
                mustEndForSourceFailure = false
                clearSession()
                await client.end()
            } else if !isEnabled {
                clearSession()
                await client.end()
                if currentRevision == revision { message = nil }
            } else if !client.isAuthorized {
                clearSession()
                await client.end()
                if currentRevision == revision {
                    message = "请在系统设置中允许收下使用实时活动"
                    recordDiagnostic("permissionDenied")
                }
            } else {
                var phase = "readFailed"
                do {
                    let records = try await repository.records()
                    if currentRevision != revision { continue }
                    if let state = PickupActivityContent.make(records: records) {
                        if let current = session, current.expiresAt > now(),
                           client.activeSessionIDs == [current.id] {
                            phase = "refreshFailed"
                            await client.update(session: current, state: state)
                            if currentRevision == revision { message = "正在显示待取信息" }
                        } else {
                            clearSession()
                            await client.end()
                            if currentRevision != revision { continue }
                            if client.canStart {
                                phase = "startFailed"
                                let current = PickupActivitySession(now: now())
                                let data = try JSONEncoder().encode(current)
                                try client.start(session: current, state: state)
                                session = current
                                defaults.set(data, forKey: persistenceKey)
                                recordDiagnostic("started")
                                message = "正在显示待取信息"
                            } else {
                                recordDiagnostic("waitingForForeground")
                                message = "下次打开收下时自动恢复展示"
                            }
                        }
                    } else {
                        clearSession()
                        await client.end()
                        if currentRevision == revision {
                            message = "暂无待取包裹，有待取时自动显示"
                            recordDiagnostic("empty")
                        }
                    }
                } catch {
                    if currentRevision != revision { continue }
                    clearSession()
                    recordDiagnostic(phase, error: error)
                    await client.end()
                    if currentRevision == revision {
                        message = "暂时无法显示待取信息，下次打开收下时重试"
                    }
                }
            }
            if currentRevision == revision { break }
        }
        worker = nil
        isBusy = false
    }

    private func clearSession() {
        session = nil
        defaults.removeObject(forKey: persistenceKey)
    }

    /// Never include pickup codes, locations or record IDs in support evidence.
    private func recordDiagnostic(_ status: String, error: Error? = nil) {
        var value: [String: Any] = ["status": status, "at": now()]
        if let error {
            let nsError = error as NSError
            value["errorDomain"] = nsError.domain
            value["errorCode"] = nsError.code
        }
        defaults.set(value, forKey: "pickupActivityDiagnostic.v1")
    }
}
