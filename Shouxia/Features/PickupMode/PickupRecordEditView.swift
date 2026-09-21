import SwiftUI

struct PickupRecordEditView: View {
    private enum Field: Hashable {
        case code
        case location
    }

    @Environment(\.dismiss) private var dismiss

    let record: PickupRecord
    let store: PickupStore
    @State private var code: String
    @State private var location: String
    @State private var validationMessage: String?
    @State private var isSaving = false
    @FocusState private var focusedField: Field?

    init(record: PickupRecord, store: PickupStore) {
        self.record = record
        self.store = store
        _code = State(initialValue: record.code)
        _location = State(initialValue: record.location ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("取件码") {
                    TextField("例如 3-2-4012", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .code)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .location }
                        .accessibilityLabel("取件码")

                    if let validationMessage {
                        Label(validationMessage, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.apricot)
                            .accessibilityLabel("保存失败，\(validationMessage)")
                    }
                }

                Section {
                    TextField("例如 北门菜鸟驿站", text: $location)
                        .focused($focusedField, equals: .location)
                        .submitLabel(.done)
                        .onSubmit { save() }
                        .accessibilityLabel("取件地点")
                } header: {
                    Text("取件地点")
                } footer: {
                    Text("可留空，之后可更正。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShouxiaBackground())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("更正取件信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "正在保存" : "保存") {
                        save()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear { focusedField = .code }
        }
        .tint(ShouxiaPalette.mutedInk)
        .fontDesign(.rounded)
    }

    private func save() {
        guard !isSaving else { return }
        validationMessage = nil
        isSaving = true

        Task {
            do {
                _ = try await store.update(record, code: code, location: location)
                dismiss()
            } catch {
                validationMessage = (error as? LocalizedError)?.errorDescription
                    ?? "暂时无法保存，请再试一次"
                focusedField = .code
                isSaving = false
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

#Preview("正式空状态") {
    InboxView()
}
