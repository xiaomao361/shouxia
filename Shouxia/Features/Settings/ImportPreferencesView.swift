import SwiftUI

struct ImportPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("automaticClipboardImportEnabled") private var storedAutomaticClipboardImportEnabled = false
    @AppStorage("commonPickupLocation") private var storedCommonPickupLocation = ""

    @State private var automaticClipboardImportEnabled: Bool
    @State private var commonPickupLocation: String
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
                Text("图片或文字没有识别出地点时，用它补全新导入的包裹。修改后不会改变旧记录。")
            }

            Section {
                Toggle(
                    "打开时识别剪贴板",
                    isOn: $automaticClipboardImportEnabled
                )
            } footer: {
                Text("默认关闭。开启后，收下只在进入前台且剪贴板发生变化时读取一次；无关文字不会保存。首次使用时 iOS 可能询问是否允许粘贴。")
            }
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
