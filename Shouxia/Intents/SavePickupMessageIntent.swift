import AppIntents
import Foundation

struct SavePickupMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "保存取件短信"
    static let description = IntentDescription("接收普通快捷指令传来的完整取件短信，解析后保存到收下。")
    static let openAppWhenRun = false

    @Parameter(
        title: "短信内容",
        description: "“收下自动收码”快捷指令提供的完整取件短信",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("保存取件短信 \(\.$text)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await PickupRepository.shared.importText(
                text,
                source: .smsAutomation,
                defaultLocation: UserDefaults.standard.string(
                    forKey: "commonPickupLocation"
                )
            )
            switch result {
            case let .added(record):
                return .result(dialog: "已收好取件码 \(record.code)")
            case .duplicate:
                return .result(dialog: "这条取件短信已经收过了")
            }
        } catch let error as PickupImportError {
            return .result(dialog: IntentDialog(stringLiteral: error.localizedDescription))
        } catch {
            return .result(dialog: "没有收好，请稍后再试")
        }
    }
}

struct ShouxiaShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SavePickupMessageIntent(),
            phrases: [
                "用 \(.applicationName) 保存取件短信",
                "保存取件短信到 \(.applicationName)",
            ],
            shortTitle: "保存取件短信",
            systemImageName: "message.badge"
        )
    }
}
