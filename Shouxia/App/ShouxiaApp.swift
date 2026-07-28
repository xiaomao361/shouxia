import SwiftUI

@main
struct ShouxiaApp: App {
    init() {
        ShouxiaShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            InboxView()
        }
    }
}
