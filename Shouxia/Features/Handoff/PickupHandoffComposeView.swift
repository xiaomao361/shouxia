import SwiftUI

struct PickupHandoffComposeView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [PickupRecord]
    let store: PickupStore
    @State private var selectedIDs: Set<UUID>
    @State private var sharePayload: HandoffSharePayload?
    @State private var shareErrorMessage: String?

    init(records: [PickupRecord], store: PickupStore) {
        self.records = records
        self.store = store
        _selectedIDs = State(
            initialValue: Set(
                records
                    .prefix(PickupHandoffPackage.maximumItemCount)
                    .map(\.id)
            )
        )
    }

    private var selectedRecords: [PickupRecord] {
        records.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 7) {
                            Text("交给实际去取的人")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ShouxiaPalette.ink)

                            Text("选择待取包裹，生成一份收下专用的本地交接包。")
                                .font(.subheadline)
                                .foregroundStyle(ShouxiaPalette.mutedInk)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        VStack(spacing: 10) {
                            ForEach(records) { record in
                                Button {
                                    toggle(record)
                                } label: {
                                    HandoffSelectionRow(
                                        code: record.code,
                                        location: record.location,
                                        platform: record.platform,
                                        isSelected: selectedIDs.contains(record.id)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(
                                    !selectedIDs.contains(record.id)
                                        && selectedIDs.count >= PickupHandoffPackage.maximumItemCount
                                )
                            }
                        }

                        VStack(spacing: 12) {
                            if !selectedRecords.isEmpty {
                                Button {
                                    prepareShare()
                                } label: {
                                    Label(
                                        "发送并完成交接（\(selectedRecords.count) 件）",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                                .buttonStyle(ShouxiaPrimaryButtonStyle())
                            }

                            Text("系统分享成功结束后，这些包裹会从你的待取列表移走，并在收下记录中标记为“交给别人”。交接包不包含短信原文、手机号、运单号或商品信息。")
                                .font(.caption)
                                .foregroundStyle(ShouxiaPalette.softInk)
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("请人帮取")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .sheet(item: $sharePayload) { payload in
            HandoffActivityView(url: payload.url) { completed in
                sharePayload = nil
                guard completed else { return }

                Task {
                    guard await store.handOff(payload.records) else {
                        shareErrorMessage = "交接包已经分享，但本地记录没有成功更新，请再试一次。"
                        return
                    }
                    dismiss()
                }
            }
            .ignoresSafeArea()
        }
        .alert(
            "没有完成交接",
            isPresented: Binding(
                get: { shareErrorMessage != nil },
                set: { if !$0 { shareErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(shareErrorMessage ?? "请再试一次。")
        }
    }

    private func toggle(_ record: PickupRecord) {
        if selectedIDs.contains(record.id) {
            selectedIDs.remove(record.id)
        } else if selectedIDs.count < PickupHandoffPackage.maximumItemCount {
            selectedIDs.insert(record.id)
        }
    }

    private func prepareShare() {
        do {
            let package = PickupHandoffPackage(records: selectedRecords)
            sharePayload = HandoffSharePayload(
                packageID: package.id,
                records: selectedRecords,
                url: try package.exportURL()
            )
        } catch {
            shareErrorMessage = "交接包没有生成成功，请再试一次。"
        }
    }
}
