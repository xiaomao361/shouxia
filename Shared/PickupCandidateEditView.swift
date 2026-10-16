import SwiftUI

/// Local draft only. Cancel never mutates the review or writes to the database/queue.
struct PickupCandidateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var review: PickupCandidateReview
    let item: PickupCandidateReview.Item
    @State private var code: String
    @State private var location: String
    @State private var validationMessage: String?

    init(item: PickupCandidateReview.Item, review: Binding<PickupCandidateReview>) {
        self.item = item
        _review = review
        _code = State(initialValue: item.candidate.code)
        _location = State(initialValue: item.candidate.location ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("取件码") {
                    TextField("例如 3-2-4012", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .accessibilityLabel("取件码")
                }
                Section {
                    TextField("例如 北门菜鸟驿站", text: $location)
                        .accessibilityLabel("取件地点")
                } header: {
                    Text("取件地点")
                } footer: {
                    Text("地点可留空；添加时若已设置常用取件点，将使用该地点。")
                }
                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.warningInk)
                            .accessibilityLabel("更正未应用，\(validationMessage)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShouxiaBackground())
            .navigationTitle("更正取件信息")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("应用更正") {
                        do {
                            try review.update(id: item.id, code: code, location: location)
                            dismiss()
                        } catch {
                            validationMessage = error.localizedDescription
                        }
                    }
                }
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .shouxiaRoundedFont()
    }
}
