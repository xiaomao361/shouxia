import ActivityKit
import Foundation

/// Shared by the app and its widget extension. Never include notification text.
struct PickupActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        let code: String
        let location: String
        let usesCommonLocation: Bool
        let remainingCount: Int
    }

    let sessionID: UUID
}
