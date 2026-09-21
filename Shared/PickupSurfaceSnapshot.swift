import Foundation

/// Display-only contract. No SMS body, fingerprint, history or write commands.
struct PickupSurfaceSnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let maximumAge: TimeInterval = 24 * 60 * 60
    let version: Int
    let updatedAt: Date
    let isAvailable: Bool
    let items: [Item]

    struct Item: Codable, Equatable, Identifiable, Sendable {
        let id: UUID
        let code: String
        let location: String
        let locationKey: String
        let usesCommonLocation: Bool
    }

    static func make(records: [PickupRecord], at date: Date = Date()) -> Self {
        let pending = records.filter { !$0.isCompleted && !$0.isArchived }
            .sorted { $0.createdAt == $1.createdAt
                ? $0.id.uuidString < $1.id.uuidString : $0.createdAt > $1.createdAt }
        return Self(version: schemaVersion, updatedAt: date, isAvailable: true, items: pending.map {
            Item(id: $0.id, code: $0.code, location: $0.locationDisplayName,
                 locationKey: $0.normalizedLocation ?? "", usesCommonLocation: $0.locationSource == .commonDefault)
        })
    }

    static func unavailable(at date: Date = Date()) -> Self {
        Self(version: schemaVersion, updatedAt: date, isAvailable: false, items: [])
    }

    func isUsable(at date: Date = Date()) -> Bool {
        version == Self.schemaVersion && isAvailable && updatedAt <= date.addingTimeInterval(60)
            && date.timeIntervalSince(updatedAt) < Self.maximumAge
    }

    /// Keep newest-first order within each place; place order follows its newest item.
    func items(at locationKey: String?) -> [Item] {
        let filtered = items.filter { locationKey == nil || $0.locationKey == locationKey }
        var keys: [String] = []
        for item in filtered where !keys.contains(item.locationKey) { keys.append(item.locationKey) }
        return keys.flatMap { key in filtered.filter { $0.locationKey == key } }
    }
}

enum PickupSurfaceLink {
    static func url(id: UUID? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "shouxia"
        components.host = "pickup"
        if let id { components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)] }
        return components.url!
    }

    static func recordID(in url: URL) -> UUID? {
        guard url.scheme == "shouxia", url.host == "pickup" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first { $0.name == "id" }?.value.flatMap(UUID.init(uuidString:))
    }
}

enum PickupSnapshotFile {
    static let appGroup = "group.com.zhouwei.shouxia"
    static let filename = "pickup-surface-v1.json"

    static func read(from url: URL, at date: Date = Date()) throws -> PickupSurfaceSnapshot {
        let snapshot = try JSONDecoder().decode(PickupSurfaceSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.isUsable(at: date) else { throw SnapshotError.unavailable }
        return snapshot
    }

    static func write(_ snapshot: PickupSurfaceSnapshot, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    enum SnapshotError: Error { case unavailable, missingAppGroup }
}
