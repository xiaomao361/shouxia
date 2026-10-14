#if os(iOS)
import ActivityKit
import UIKit
#endif
import Foundation
import Combine

@MainActor
protocol PickupActivityClient: AnyObject {
    var isSupported: Bool { get }
    var isAuthorized: Bool { get }
    var canStart: Bool { get }
    var activeSessionIDs: [UUID] { get }
    func start(session: PickupActivitySession, state: PickupActivityContent) throws
    func update(session: PickupActivitySession, state: PickupActivityContent) async
    func end() async
}

extension PickupActivityClient {
    var isSupported: Bool { true }
}

#if os(iOS)
@MainActor
private final class UnsupportedPickupActivityClient: PickupActivityClient {
    var isSupported: Bool { false }
    var isAuthorized: Bool { false }
    var canStart: Bool { false }
    var activeSessionIDs: [UUID] { [] }
    func start(session: PickupActivitySession, state: PickupActivityContent) throws {
        throw UnsupportedActivityError.systemVersion
    }
    func update(session: PickupActivitySession, state: PickupActivityContent) async {}
    func end() async {}
    private enum UnsupportedActivityError: Error { case systemVersion }
}

@available(iOS 16.1, *)
@MainActor
final class SystemPickupActivityClient: PickupActivityClient {
    var isAuthorized: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    var canStart: Bool { UIApplication.shared.applicationState == .active }
    var activeSessionIDs: [UUID] {
        Activity<PickupActivityAttributes>.activities.filter {
            Self.isDisplayable($0.activityState)
        }.map(\.attributes.sessionID)
    }

    private nonisolated static func isDisplayable(_ state: ActivityState) -> Bool {
        if state == .active { return true }
        if #available(iOS 16.2, *) { return state == .stale }
        return false
    }

    func start(session: PickupActivitySession, state: PickupActivityContent) throws {
        let attributes = PickupActivityAttributes(sessionID: session.id, expiresAt: session.expiresAt)
        if #available(iOS 16.2, *) {
            _ = try Activity<PickupActivityAttributes>.request(attributes: attributes,
                content: ActivityContent(state: state, staleDate: session.expiresAt), pushType: nil)
        } else {
            _ = try Activity<PickupActivityAttributes>.request(attributes: attributes,
                contentState: state, pushType: nil)
        }
    }

    func update(session: PickupActivitySession, state: PickupActivityContent) async {
        await Self.updateActivity(session: session, state: state)
    }

    func end() async { await Self.endActivities() }

    private nonisolated static func updateActivity(session: PickupActivitySession, state: PickupActivityContent) async {
        guard let activity = Activity<PickupActivityAttributes>.activities.first(where: {
            $0.attributes.sessionID == session.id
        }) else { return }
        if #available(iOS 16.2, *) {
            await activity.update(ActivityContent(state: state, staleDate: session.expiresAt))
        } else {
            await activity.update(using: state)
        }
    }

    private nonisolated static func endActivities() async {
        for activity in Activity<PickupActivityAttributes>.activities {
            guard isDisplayable(activity.activityState) else { continue }
            if #available(iOS 16.2, *) {
                await activity.end(ActivityContent(state: .finished, staleDate: nil), dismissalPolicy: .immediate)
            } else {
                await activity.end(using: .finished, dismissalPolicy: .immediate)
            }
        }
    }
}
#endif

/// The setting persists independently of the system's limited activity lifetime.
/// Repository changes update existing activities; new ones require a foreground app.
@MainActor
final class PickupLiveActivityController: ObservableObject {
    #if os(iOS)
    static let shared: PickupLiveActivityController = {
        if #available(iOS 16.1, *) {
            return PickupLiveActivityController(client: SystemPickupActivityClient())
        }
        return PickupLiveActivityController(client: UnsupportedPickupActivityClient())
    }()
    #endif
    @Published private(set) var isEnabled: Bool
    @Published private(set) var session: PickupActivitySession?
    @Published private(set) var isBusy = false
    @Published private(set) var message: String?
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
            } else if !client.isSupported {
                clearSession()
                await client.end()
                if currentRevision == revision {
                    message = "锁屏与灵动岛展示需要 iOS 16.1 或更高版本"
                    recordDiagnostic("unsupportedSystem")
                }
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
