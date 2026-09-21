import ActivityKit
import Foundation

struct PickupActivityAttributes: ActivityAttributes {
    typealias ContentState = PickupActivityContent
    let sessionID: UUID
    let expiresAt: Date
}
