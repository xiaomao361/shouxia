import Foundation

/// System activity lifetime only; the persistent preference owns user intent.
/// No pickup-mode selection, fixed membership or privacy mode is stored here.
struct PickupActivitySession: Codable, Equatable, Sendable {
    let id: UUID
    let expiresAt: Date

    init(now: Date = Date()) {
        id = UUID()
        expiresAt = now.addingTimeInterval(8 * 60 * 60)
    }

    func state(records: [PickupRecord], now: Date = Date()) -> PickupActivityContent? {
        guard now < expiresAt else { return nil }
        return PickupActivityContent.make(records: records)
    }
}

struct PickupActivityContent: Codable, Hashable, Sendable {
    let recordID: UUID?
    let code: String?
    let location: String
    let usesCommonLocation: Bool
    let remainingCount: Int
    let ended: Bool

    static func make(records: [PickupRecord]) -> Self? {
        let pending = PickupSurfaceSnapshot.make(records: records).items
        guard let first = pending.first else { return nil }
        return Self(recordID: first.id, code: first.code, location: first.location,
                    usesCommonLocation: first.usesCommonLocation, remainingCount: pending.count, ended: false)
    }

    static let finished = Self(recordID: nil, code: nil, location: "待取展示已结束",
                               usesCommonLocation: false, remainingCount: 0, ended: true)
}
