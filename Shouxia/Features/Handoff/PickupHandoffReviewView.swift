import SwiftUI

struct PickupHandoffReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let package: PickupHandoffPackage
    @ObservedObject var store: PickupStore
    @State private var isImporting = false
    @State private var importError: String?

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

                        if let importError {
                            Label(importError, systemImage: "exclamationmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(ShouxiaPalette.warningInk)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("添加失败，\(importError)")
                        }

                        Button {
                            Task {
                                isImporting = true
                                importError = nil
                                if await store.importHandoffPackage(package) {
                                    dismiss()
                                } else if case let .error(message)? = store.notice {
                                    importError = message
                                } else {
                                    importError = "暂时无法添加，请重试。"
                                }
                                isImporting = false
                            }
                        } label: {
                            if isImporting {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("添加到待取（\(package.items.count) 件）")
                            }
                        }
                        .buttonStyle(ShouxiaPrimaryButtonStyle())
                        .disabled(isImporting)

                        Text("取件状态不会与对方同步。")
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
        .shouxiaRoundedFont()
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
                    isSelected ? ShouxiaPalette.accentInk : ShouxiaPalette.softInk
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(code)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(location ?? "地点待确认")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let brand = platform {
                    ShouxiaBrandBadge(brand: PickupDirectory.displayLabel(for: brand))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
