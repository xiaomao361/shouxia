import ActivityKit
import Foundation

@available(iOS 16.1, *)
struct PickupActivityAttributes: ActivityAttributes {
    typealias ContentState = PickupActivityContent
    let sessionID: UUID
    let expiresAt: Date
}
