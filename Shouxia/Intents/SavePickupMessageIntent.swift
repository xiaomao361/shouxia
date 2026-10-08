import AppIntents
import Foundation

struct SavePickupMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "保存取件短信"
    static let description = IntentDescription("从快捷指令接收取件短信，提取并保存取件码。")
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
            await PickupLiveActivityController.shared.refreshAndWait()
            switch result {
            case let .added(record):
                return .result(dialog: "已添加取件码 \(record.code)")
            case .duplicate:
                return .result(dialog: "这条取件短信已添加")
            case let .batch(added, duplicateCount):
                let message = added.isEmpty ? "这些取件码已添加"
                    : (duplicateCount > 0
                        ? "已添加 \(added.count) 个取件码，\(duplicateCount) 个已存在"
                        : "已添加 \(added.count) 个取件码")
                return .result(dialog: IntentDialog(stringLiteral: message))
            }
        } catch let error as PickupImportError {
            return .result(dialog: IntentDialog(stringLiteral: error.localizedDescription))
        } catch {
            return .result(dialog: "添加失败，请稍后重试")
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
