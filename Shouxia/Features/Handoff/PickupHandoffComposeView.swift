import SwiftUI
import UIKit

struct PickupHandoffComposeView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [PickupRecord]
    let store: PickupStore
    @State private var selectedIDs: Set<UUID>
    @State private var sharePayload: HandoffSharePayload?
    @State private var shareErrorMessage: String?
    @State private var shareAsText = false
    @State private var copiedText: String?

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

    private var shareText: String {
        PickupShareText.make(records: selectedRecords)
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

                            Text("选好这次要取的包裹，发给帮忙的人。")
                                .font(.subheadline)
                                .foregroundStyle(ShouxiaPalette.mutedInk)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 8)

                        Picker("分享方式", selection: $shareAsText) {
                            Text("收下交接包").tag(false)
                            Text("普通文字").tag(true)
                        }
                        .pickerStyle(.segmented)

                        Text(shareAsText
                            ? "对方不用安装收下，在聊天里就能查看。"
                            : "对方需要安装收下，打开交接包即可导入。")
                            .font(.subheadline)
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                            .multilineTextAlignment(.center)

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
                                if shareAsText {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("文字预览")
                                            .font(.headline)
                                        Text(shareText)
                                            .font(.body)
                                            .textSelection(.enabled)
                                    }
                                    .foregroundStyle(ShouxiaPalette.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(ShouxiaPalette.paper, in: RoundedRectangle(cornerRadius: 18))
                                }

                                if shareAsText {
                                    Button {
                                        let text = shareText
                                        UIPasteboard.general.string = text
                                        copiedText = text
                                    } label: {
                                        Label(
                                            copiedText == shareText ? "已复制文字" : "复制文字",
                                            systemImage: "doc.on.doc"
                                        )
                                    }
                                    .buttonStyle(ShouxiaPrimaryButtonStyle())
                                } else {
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
                            } else {
                                Text("先选择要请人帮取的包裹")
                                    .font(.subheadline)
                                    .foregroundStyle(ShouxiaPalette.mutedInk)
                            }

                            Text(shareAsText
                                ? "复制后粘贴到聊天即可。包裹仍保留在待取列表，确认取到后再手动收下。文字只包含所选包裹的取件码、地点和平台。"
                                : "系统分享成功结束后，这些包裹会从你的待取列表移走，并在收下记录中标记为“交给别人”。交接包不包含短信原文、手机号、运单号或商品信息。")
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
                    Button("完成") { dismiss() }
                }
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .sheet(item: $sharePayload) { payload in
            HandoffActivityView(content: payload.content) { completed, error in
                sharePayload = nil
                guard error == nil else {
                    shareErrorMessage = "系统分享没有成功完成，包裹仍保留在待取列表，请再试一次。"
                    return
                }
                let handedOffRecords = payload.content.recordsToHandOff(completed: completed, error: error)
                guard !handedOffRecords.isEmpty else { return }

                Task {
                    guard await store.handOff(handedOffRecords) else {
                        shareErrorMessage = "交接包已经分享，但本地记录没有成功更新，请再试一次。"
                        return
                    }
                    dismiss()
                }
            }
            .ignoresSafeArea()
        }
        .alert(
            "分享未完成",
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
        guard !shareAsText, !selectedRecords.isEmpty else { return }
        do {
            let package = PickupHandoffPackage(records: selectedRecords)
            sharePayload = HandoffSharePayload(
                content: HandoffShareContent(url: try package.exportURL(), records: selectedRecords)
            )
        } catch {
            shareErrorMessage = "交接包没有生成成功，请再试一次。"
        }
    }
}
