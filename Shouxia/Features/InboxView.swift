import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = PickupStore()
    @State private var presentedSheet: PresentedSheet?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    pasteAction
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if store.pendingRecords.isEmpty {
                    emptyState
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    Section {
                        ForEach(store.pendingRecords) { record in
                            PickupCard(record: record) {
                                complete(record)
                            }
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        complete(record)
                                    } label: {
                                        Label("收下", systemImage: "shippingbox.fill")
                                    }
                                    .tint(.green)
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                    removal: .opacity.combined(with: .scale(scale: 0.86))
                                ))
                        }
                    } header: {
                        Text(headerText)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .textCase(nil)
                            .padding(.bottom, 4)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("收下")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentedSheet = .history
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("查看收下记录，共 \(store.historyRecords.count) 条")
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomMessage
            }
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .history:
                    NavigationStack {
                        HistoryView(store: store)
                    }
                }
            }
            .task {
                await store.load()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await store.load() }
            }
        }
    }

    private enum PresentedSheet: String, Identifiable {
        case history

        var id: String { rawValue }
    }

    private var headerText: String {
        "有 \(store.pendingRecords.count) 个包裹在等你"
    }

    private var pasteAction: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let text = strings.first else { return }
            Task { await store.importText(text, source: .paste) }
        }
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.indigo)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityLabel("读取剪贴板并添加取件信息")
        .accessibilityHint("请先从短信或购物平台复制完整的取件通知")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("今天的包裹都收下了", systemImage: "house.and.flag.fill")
        } description: {
            Text("从短信或购物平台复制取件通知，然后点上方按钮。")
        }
        .padding(.top, 72)
    }

    @ViewBuilder
    private var bottomMessage: some View {
        if store.lastCompleted != nil {
            HStack(spacing: 12) {
                Label("收下啦", systemImage: "shippingbox.fill")
                    .font(.headline)
                Spacer()
                Button("撤销") {
                    Task { await store.undoLastCompletion() }
                }
                .fontWeight(.semibold)
            }
            .padding(.horizontal, 18)
            .frame(height: 54)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let notice = store.notice {
            HStack(spacing: 10) {
                Image(systemName: iconName(for: notice))
                Text(notice.message)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 0)
                Button {
                    store.dismissNotice()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("关闭提示")
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(.regularMaterial, in: Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func complete(_ record: PickupRecord) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(duration: 0.38, bounce: 0.18)) {
            store.beginCompletion(record)
        }
        Task {
            await store.persistCompletion(record)
            try? await Task.sleep(for: .seconds(5))
            withAnimation(.easeOut(duration: 0.2)) {
                store.dismissUndo(for: record.id)
            }
        }
    }

    private func iconName(for notice: PickupStore.Notice) -> String {
        switch notice {
        case .success:
            "checkmark.circle.fill"
        case .neutral:
            "info.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        }
    }
}

private struct PickupCard: View {
    let record: PickupRecord
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(record.location ?? "地点待确认", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if let platform = record.platform {
                    Text(platform)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(record.code)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .textSelection(.enabled)
                .accessibilityLabel("取件码 \(record.code)")

            HStack {
                Text(record.createdAt, style: .relative)
                Spacer()
                Text(record.source.displayName)
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.12), Color.white.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.indigo.opacity(0.1), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "收下", onComplete)
    }
}

#Preview("空列表") {
    InboxView()
}
