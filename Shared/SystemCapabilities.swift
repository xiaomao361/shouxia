import Foundation

/// Resolve once per view; every instruction and hint uses the same capability.
enum SMSAutomationFlow: Equatable {
    case confirmationRequired, personalAutomation, inlineAutomation

    static func resolve(majorVersion: Int) -> Self {
        if majorVersion >= 27 { return .inlineAutomation }
        if majorVersion >= 17 { return .personalAutomation }
        return .confirmationRequired
    }

    static var current: Self {
        resolve(majorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
    }

    var requiresConfirmation: Bool { self == .confirmationRequired }
    var introduction: String {
        requiresConfirmation ? "设置后，收到取件短信时确认运行，即可添加。" : "设置一次，收到取件短信就自动添加。"
    }
    var verification: String {
        requiresConfirmation ? "收到下一条取件短信后，确认运行并检查是否添加" : "收到下一条取件短信后，看看是否自动添加"
    }
    var inboxDescription: String {
        requiresConfirmation ? "设置后，收到取件短信时确认添加。" : "设置后，取件短信自动加入待取。"
    }
}
