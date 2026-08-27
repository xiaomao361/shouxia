import SwiftUI

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let store: PickupStore

    var body: some View {
        Group {
            if store.historyRecords.isEmpty {
                ContentUnavailableView {
                    Label("还没有收下记录", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("在主页面收下包裹后，这里会保留录入与收下时间。")
                }
                .foregroundStyle(ShouxiaPalette.mutedInk)
                .background(ShouxiaBackground())
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
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button {
                                            Task { await store.archive(record) }
                                        } label: {
                                            Label("归档", systemImage: "archivebox")
                                        }
                                        .tint(ShouxiaPalette.apricot)
                                    }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(ShouxiaBackground())
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("收下记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("完成") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    ArchiveView(store: store)
                } label: {
                    Image(systemName: "archivebox")
                }
                .accessibilityLabel("查看归档，共 \(store.archivedRecords.count) 条")
            }
        }
    }

    private var historySections: [RecordSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: store.historyRecords) { record in
            calendar.startOfDay(for: record.completedAt ?? record.createdAt)
        }
        return grouped.keys
            .sorted(by: >)
            .map { day in
                RecordSection(
                    day: day,
                    title: sectionTitle(for: day, calendar: calendar),
                    records: grouped[day] ?? []
                )
            }
    }

    private func sectionTitle(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) {
            return "今天"
        }
        if calendar.isDateInYesterday(day) {
            return "昨天"
        }
        return day.formatted(.dateTime.year().month().day())
    }
}

private struct ArchiveView: View {
    let store: PickupStore
    @State private var recordToDelete: PickupRecord?

    var body: some View {
        Group {
            if store.archivedRecords.isEmpty {
                ContentUnavailableView {
                    Label("归档是空的", systemImage: "archivebox")
                } description: {
                    Text("从收下记录归档的内容会出现在这里。")
                }
                .foregroundStyle(ShouxiaPalette.mutedInk)
                .background(ShouxiaBackground())
            } else {
                List(store.archivedRecords) { record in
                    RecordRow(record: record, showsArchivedAt: true)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task { await store.restoreFromArchive(record) }
                            } label: {
                                Label("恢复", systemImage: "arrow.uturn.backward")
                            }
                            .tint(ShouxiaPalette.mutedInk)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                recordToDelete = record
                            } label: {
                                Label("永久删除", systemImage: "trash")
                            }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(ShouxiaBackground())
            }
        }
        .fontDesign(.rounded)
        .navigationTitle("归档")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "永久删除这条记录？",
            isPresented: Binding(
                get: { recordToDelete != nil },
                set: { if !$0 { recordToDelete = nil } }
            ),
            presenting: recordToDelete
        ) { record in
            Button("永久删除", role: .destructive) {
                Task { await store.permanentlyDelete(record) }
            }
            Button("取消", role: .cancel) {}
        } message: { record in
            Text("取件码 \(record.code) 将被真实删除，且无法恢复。")
        }
    }
}

private struct RecordRow: View {
    let record: PickupRecord
    var showsArchivedAt = false

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
                if showsArchivedAt, let archivedAt = record.archivedAt {
                    dateLine("归档", date: archivedAt)
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
