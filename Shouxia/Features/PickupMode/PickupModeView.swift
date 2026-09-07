import SwiftUI
import UIKit

struct PickupModeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let store: PickupStore
    let onComplete: (PickupRecord) -> Void
    let groupRecordIDs: [UUID]
    @State private var selectedRecordID: UUID
    @State private var editingRecord: PickupRecord?

    init(
        store: PickupStore,
        records: [PickupRecord],
        initialRecordID: UUID,
        onComplete: @escaping (PickupRecord) -> Void
    ) {
        self.store = store
        self.onComplete = onComplete
        groupRecordIDs = records.map(\.id)
        _selectedRecordID = State(initialValue: initialRecordID)
    }

    private var records: [PickupRecord] {
        groupRecordIDs.compactMap { id in
            store.pendingRecords.first { $0.id == id }
        }
    }

    private var selectedRecord: PickupRecord? {
        records.first { $0.id == selectedRecordID } ?? records.first
    }

    private var selectedIndex: Int {
        records.firstIndex { $0.id == selectedRecordID } ?? 0
    }

    var body: some View {
        ZStack {
            ShouxiaBackground()

            VStack(spacing: 0) {
                topBar

                TabView(selection: $selectedRecordID) {
                    ForEach(records) { record in
                        PickupCodePage(
                            record: record,
                            onEdit: { editingRecord = record }
                        )
                            .tag(record.id)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(
                    reduceMotion ? nil : ShouxiaMotion.settle,
                    value: selectedRecordID
                )

                bottomControls
            }
            .padding(.bottom, 18)
        }
        .tint(ShouxiaPalette.ink)
        .sheet(item: $editingRecord) { record in
            PickupRecordEditView(record: record, store: store)
                .presentationDetents([.medium])
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("取件台")
                    .font(.title3.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(groupDescription)
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.supportingInk)
            }

            Spacer()

            if let selectedRecord {
                Button {
                    editingRecord = selectedRecord
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(ShouxiaPalette.ink)
                        .frame(width: 44, height: 44)
                        .background(ShouxiaPalette.paper.opacity(0.94), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
                        }
                }
                .accessibilityLabel("更正取件信息")
                .accessibilityHint("修改当前包裹的取件码或地点")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(ShouxiaPalette.ink)
                    .frame(width: 44, height: 44)
                    .background(ShouxiaPalette.paper.opacity(0.94), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
                    }
            }
            .accessibilityLabel("关闭大字取件模式")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            pageStatus

            Button {
                completeSelectedRecord()
            } label: {
                Label("已取到，收下", systemImage: "shippingbox.fill")
            }
            .buttonStyle(ShouxiaPrimaryButtonStyle())
            .disabled(selectedRecord == nil)
            .accessibilityHint(
                records.count > 1
                    ? "完成当前包裹并显示这一组的下一件"
                    : "完成当前包裹并返回待取列表"
            )

            completionFeedback
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var completionFeedback: some View {
        if let lastCompleted = store.lastCompleted {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ShouxiaPalette.breezePressed)
                Text("已收下 \(lastCompleted.code)")
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("撤销") {
                    undoLastCompletion(lastCompleted)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(ShouxiaPalette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(ShouxiaPalette.paper, in: Capsule())
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .foregroundStyle(ShouxiaPalette.paper)
            .background(
                ShouxiaPalette.ink,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .accessibilityElement(children: .contain)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.98)))
        } else {
            Color.clear
                .frame(height: 44)
                .accessibilityHidden(true)
        }
    }

    private var pageStatus: some View {
        VStack(spacing: 9) {
            if records.count > 1 {
                HStack(spacing: 7) {
                    ForEach(records) { record in
                        Capsule()
                            .fill(
                                record.id == selectedRecordID
                                    ? ShouxiaPalette.apricot
                                    : ShouxiaPalette.softInk.opacity(0.22)
                            )
                            .frame(
                                width: record.id == selectedRecordID ? 22 : 7,
                                height: 7
                            )
                    }
                }
                .animation(
                    reduceMotion ? nil : ShouxiaMotion.threshold,
                    value: selectedRecordID
                )

                Text("第 \(selectedIndex + 1) 个，共 \(records.count) 个 · 左右滑动切换")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.supportingInk)
            } else {
                Text("长按取件码可以复制")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.supportingInk)
            }
        }
        .frame(minHeight: 46)
    }

    private var groupDescription: String {
        guard records.count > 1 else {
            return "把取件码给工作人员看"
        }
        if let batchID = selectedRecord?.importBatchID,
           records.allSatisfy({ $0.importBatchID == batchID }) {
            return "同批导入有 \(records.count) 个包裹"
        }
        return "同一地点有 \(records.count) 个包裹"
    }

    private func completeSelectedRecord() {
        guard let record = selectedRecord else { return }
        let currentRecords = records
        let currentIndex = currentRecords.firstIndex { $0.id == record.id } ?? 0
        let remaining = currentRecords.filter { $0.id != record.id }
        let nextRecord = currentRecords.count > 1
            ? currentRecords[(currentIndex + 1) % currentRecords.count]
            : nil

        if let nextRecord {
            withAnimation(reduceMotion ? nil : ShouxiaMotion.settle) {
                selectedRecordID = nextRecord.id
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onComplete(record)

        if remaining.isEmpty {
            if reduceMotion {
                dismiss()
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(260))
                    dismiss()
                }
            }
        }
    }

    private func undoLastCompletion(_ record: PickupRecord) {
        Task {
            await store.undoLastCompletion()
            guard store.pendingRecords.contains(where: { $0.id == record.id }) else {
                return
            }
            withAnimation(reduceMotion ? nil : ShouxiaMotion.settle) {
                selectedRecordID = record.id
            }
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
