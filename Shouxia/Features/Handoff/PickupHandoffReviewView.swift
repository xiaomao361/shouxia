import SwiftUI

struct PickupHandoffReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let package: PickupHandoffPackage
    let store: PickupStore
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 7) {
                            Text("有人托你取 \(package.items.count) 件")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ShouxiaPalette.ink)

                            Text("确认后加入待取。")
                                .font(.subheadline)
                                .foregroundStyle(ShouxiaPalette.mutedInk)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        VStack(spacing: 10) {
                            ForEach(package.items) { item in
                                HandoffSelectionRow(
                                    code: item.code,
                                    location: item.location,
                                    platform: item.platform,
                                    isSelected: true
                                )
                            }
                        }

                        Button {
                            Task {
                                isImporting = true
                                if await store.importHandoffPackage(package) {
                                    dismiss()
                                }
                                isImporting = false
                            }
                        } label: {
                            if isImporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("收下这 \(package.items.count) 件")
                            }
                        }
                        .buttonStyle(ShouxiaPrimaryButtonStyle())
                        .disabled(isImporting)

                        Text("内容以发送时为准，双方取件状态不会同步。")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.softInk)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("收下交接包")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .fontDesign(.rounded)
    }
}

struct HandoffSelectionRow: View {
    let code: String
    let location: String?
    let platform: String?
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(
                    isSelected ? ShouxiaPalette.breezePressed : ShouxiaPalette.softInk
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(code)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(location ?? "地点待确认")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let platform {
                Text(platform)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(ShouxiaPalette.skyWash, in: Capsule())
            }
        }
        .padding(16)
        .background(
            ShouxiaPalette.paper.opacity(isSelected ? 0.98 : 0.76),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isSelected ? ShouxiaPalette.cardHighlight : ShouxiaPalette.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(isSelected ? "已选择" : "未选择")，取件码 \(code)，\(location ?? "地点待确认")"
        )
    }
}
