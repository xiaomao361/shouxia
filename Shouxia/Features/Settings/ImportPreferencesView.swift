import SwiftUI

struct ImportPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("automaticClipboardImportEnabled") private var storedAutomaticClipboardImportEnabled = false
    @AppStorage("commonPickupLocation") private var storedCommonPickupLocation = ""

    @State private var automaticClipboardImportEnabled: Bool
    @State private var commonPickupLocation: String
    @AppStorage("automationSetupCardHidden") private var automationSetupCardHidden = false
    @State private var showsAutomationSetup = false
    @State private var validationMessage: String?

    init() {
        let defaults = UserDefaults.standard
        _automaticClipboardImportEnabled = State(
            initialValue: defaults.bool(forKey: "automaticClipboardImportEnabled")
        )
        _commonPickupLocation = State(
            initialValue: defaults.string(forKey: "commonPickupLocation") ?? ""
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("例如 小区北门驿站", text: $commonPickupLocation)
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("常用取件点")

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(ShouxiaPalette.apricot)
                        .accessibilityLabel("保存失败，\(validationMessage)")
                }
            } header: {
                Text("常用取件点")
            } footer: {
                Text("未识别到地点时使用，仅影响新导入的包裹。")
            }

            Section {
                Toggle(
                    "打开时识别剪贴板",
                    isOn: $automaticClipboardImportEnabled
                )
            } footer: {
                Text("打开 App 时识别新复制的取件信息，无关文字不保存。iOS 可能询问粘贴权限。")
            }
            Section {
                Button("设置短信自动收码") {
                    showsAutomationSetup = true
                }
                if automationSetupCardHidden {
                    Button("重新显示首页设置入口") {
                        automationSetupCardHidden = false
                    }
                } else {
                    Label("首页设置入口已显示", systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("短信自动收码")
            } footer: {
                Text("隐藏首页入口不影响已配置的自动收码。")
            }
        }
        .sheet(isPresented: $showsAutomationSetup) {
            AutomationSetupView()
        }
        .scrollContentBackground(.hidden)
        .background(ShouxiaBackground())
        .navigationTitle("导入设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { save() }
            }
        }
    }

    private func save() {
        let normalizedLocation = commonPickupLocation
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedLocation.count <= 80 else {
            validationMessage = "常用取件点请控制在 80 个字符以内"
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }

        storedCommonPickupLocation = normalizedLocation
        storedAutomaticClipboardImportEnabled = automaticClipboardImportEnabled
        dismiss()
    }
}
