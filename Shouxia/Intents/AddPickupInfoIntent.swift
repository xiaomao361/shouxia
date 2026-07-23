import AppIntents

struct AddPickupInfoIntent: AppIntent {
    static let title: LocalizedStringResource = "添加取件信息"
    static let description = IntentDescription("把短信或购物平台通知中的取件码添加到收下。")
    static let openAppWhenRun = false

    @Parameter(
        title: "通知内容",
        description: "包含取件码和地点的完整通知文字",
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var text: String

    static var parameterSummary: some ParameterSummary {
        Summary("添加 \(\.$text) 到收下")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let result = try await PickupRepository.shared.importText(text, source: .notificationAutomation)
            switch result {
            case let .added(record):
                return .result(dialog: "已收好取件码 \(record.code)")
            case .duplicate:
                return .result(dialog: "这条取件通知已经收过了")
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
            intent: AddPickupInfoIntent(),
            phrases: [
                "用 \(.applicationName) 添加取件信息",
                "添加取件信息到 \(.applicationName)",
            ],
            shortTitle: "添加取件信息",
            systemImageName: "shippingbox.and.arrow.backward"
        )
    }
}
