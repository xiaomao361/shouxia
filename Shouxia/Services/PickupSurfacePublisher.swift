import Foundation
import OSLog
import WidgetKit

enum PickupSurfacePublisher {
    static func publish(_ snapshot: PickupSurfaceSnapshot) throws {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: PickupSnapshotFile.appGroup
        ) else { throw PickupSnapshotFile.SnapshotError.missingAppGroup }
        let url = container.appendingPathComponent(PickupSnapshotFile.filename)
        do {
            try PickupSnapshotFile.write(snapshot, to: url)
        } catch {
            // Never leave a known-old successful snapshot after a failed replacement.
            do { try FileManager.default.removeItem(at: url) }
            catch { Logger(subsystem: "com.zhouwei.shouxia", category: "surfaces").error("Snapshot invalidation failed: \(error.localizedDescription, privacy: .public)") }
            WidgetCenter.shared.reloadAllTimelines()
            throw error
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}
