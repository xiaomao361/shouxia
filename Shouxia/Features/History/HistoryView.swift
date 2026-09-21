import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let store: PickupStore
    @State private var range: PickupHistoryRange = .recent
    @State private var recordToDelete: PickupRecord?

    var body: some View {
        VStack(spacing: 0) {
            Picker("记录范围", selection: $range) {
                ForEach(PickupHistoryRange.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if case let .error(message) = store.notice {
                Text(message).font(.caption).foregroundStyle(.red).padding(.horizontal)
            }
            if store.loadFailed {
                ContentUnavailableView("暂时无法读取记录", systemImage: "exclamationmark.triangle",
                                       description: Text("请稍后重新打开收下。"))
            } else if visibleRecords.isEmpty {
                ContentUnavailableView {
                    Label(store.historyRecords.isEmpty ? "还没有收下记录" : "最近 30 天没有记录",
                          systemImage: "clock.arrow.circlepath")
                } description: {
                    Text(store.historyRecords.isEmpty ? "取完的包裹会留在这里。" : "切换“全部”查看更早的记录。")
                }
                .foregroundStyle(ShouxiaPalette.mutedInk)
            } else {
                List {
                    ForEach(historySections) { section in
                        Section(section.title) {
                            ForEach(section.records) { record in
                                RecordRow(record: record)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            Task { await store.restoreToPending(record) }
                                        } label: {
                                            Label("设为待取", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(ShouxiaPalette.mutedInk)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) { recordToDelete = record } label: {
                                            Label("删除", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(ShouxiaBackground())
        .fontDesign(.rounded)
        .navigationTitle("收下记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") { dismiss() }
            }
        }
        .alert("删除这条记录？", isPresented: Binding(
            get: { recordToDelete != nil },
            set: { if !$0 { recordToDelete = nil } }
        ), presenting: recordToDelete) { record in
            Button("永久删除", role: .destructive) {
                Task { await store.permanentlyDelete(record) }
            }
            Button("取消", role: .cancel) {}
        } message: { record in
            Text("取件码 \(record.code) 的记录将永久删除，无法恢复。")
        }
    }

    private var visibleRecords: [PickupRecord] {
        range.records(from: store.historyRecords)
    }

    private var historySections: [RecordSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: visibleRecords) { calendar.startOfDay(for: $0.historyDate) }
        return grouped.keys.sorted(by: >).map { day in
            RecordSection(day: day, title: sectionTitle(for: day, calendar: calendar), records: grouped[day] ?? [])
        }
    }

    private func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "今天" }
        if calendar.isDateInYesterday(day) { return "昨天" }
        return day.formatted(.dateTime.year().month().day())
    }
}

private struct RecordRow: View {
    let record: PickupRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(record.location ?? "地点待确认")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)
                    .lineLimit(1)
                Spacer()
                if record.isHandedOff {
                    Text("交给别人")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ShouxiaPalette.breezePressed)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ShouxiaPalette.skyWash, in: Capsule())
                }
                if let platform = record.platform {
                    Text(platform)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(ShouxiaPalette.mutedInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ShouxiaPalette.skyWash, in: Capsule())
                }
            }

            Text(record.code)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(ShouxiaPalette.ink)
                .textSelection(.enabled)
                .accessibilityLabel("取件码 \(record.code)")

            VStack(alignment: .leading, spacing: 4) {
                dateLine("录入", date: record.createdAt)
                if let completedAt = record.completedAt {
                    dateLine(record.isHandedOff ? "交接" : "收下", date: completedAt)
                }
            }
            .font(.caption)
            .foregroundStyle(ShouxiaPalette.softInk)
        }
        .padding(.vertical, 16)
        .padding(.leading, 36)
        .padding(.trailing, 16)
        .background(
            ShouxiaPalette.paper,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(ShouxiaPalette.accent(for: record))
                .frame(width: 7, height: 7)
                .padding(.leading, 16)
                .padding(.top, 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ShouxiaPalette.line, lineWidth: 1)
        }
        .shadow(color: ShouxiaPalette.ink.opacity(0.045), radius: 10, y: 5)
        .accessibilityElement(children: .combine)
    }

    private func dateLine(_ label: String, date: Date) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .frame(width: 30, alignment: .leading)
            Text(date, format: .dateTime.year().month().day().hour().minute())
        }
    }
}

private struct RecordSection: Identifiable {
    let day: Date
    let title: String
    let records: [PickupRecord]

    var id: Date { day }
}
