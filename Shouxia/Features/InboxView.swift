import SwiftUI
import UniformTypeIdentifiers

struct InboxView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = PickupStore()
    @State private var presentedSheet: PresentedSheet?
    @State private var completingID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaPalette.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        intro

                        if store.pendingRecords.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.pendingRecords) { record in
                                PickupCard(
                                    record: record,
                                    isCompleting: completingID == record.id,
                                    reduceMotion: reduceMotion,
                                    onComplete: { complete(record) }
                                )
                                .transition(
                                    reduceMotion
                                        ? .opacity
                                        : .asymmetric(
                                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                            removal: .opacity.combined(with: .scale(scale: 0.82))
                                        )
                                )
                            }

                            completionHint
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("收下")
            .navigationBarTitleDisplayMode(.inline)
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
                    .tint(ShouxiaPalette.evergreen)
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
        .tint(ShouxiaPalette.evergreen)
    }

    private enum PresentedSheet: String, Identifiable {
        case history

        var id: String { rawValue }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(headerText)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(
                    store.pendingRecords.isEmpty
                        ? "轻轻松松，今天也都带回家了。"
                        : "取件码已经替你整理好，到站打开就能看见。"
                )
                .font(.subheadline)
                .foregroundStyle(ShouxiaPalette.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            pasteAction
        }
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    private var headerText: String {
        switch store.pendingRecords.count {
        case 0:
            "都收下了"
        case 1:
            "有 1 个包裹在等你"
        default:
            "有 \(store.pendingRecords.count) 个包裹在等你"
        }
    }

    private var pasteAction: some View {
        PasteButton(payloadType: String.self) { strings in
            guard let text = strings.first else { return }
            Task { await store.importText(text, source: .paste) }
        }
        .labelStyle(.titleAndIcon)
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(ShouxiaPalette.evergreen)
        .frame(maxWidth: .infinity)
        .shadow(color: ShouxiaPalette.evergreen.opacity(0.20), radius: 16, y: 8)
        .accessibilityLabel("读取剪贴板并添加取件信息")
        .accessibilityHint("请先从短信或购物平台复制完整的取件通知")
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(ShouxiaPalette.apricot.opacity(0.18))
                    .frame(width: 112, height: 112)

                Image(systemName: "house.and.flag.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(ShouxiaPalette.apricot, ShouxiaPalette.evergreen)
            }

            VStack(spacing: 7) {
                Text("今天的包裹都收下了")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(ShouxiaPalette.ink)
                Text("下一条取件通知来时，粘贴到这里就好。")
                    .font(.subheadline)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .background(
            ShouxiaPalette.paper.opacity(0.72),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private var completionHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reduceMotion ? "figure.roll" : "hand.draw.fill")
                .foregroundStyle(ShouxiaPalette.apricot)
            Text(
                reduceMotion
                    ? "向右滑动卡片即可收下。"
                    : "向右滑过圆点后松手，把包裹收进家里。"
            )
            .font(.caption)
            .foregroundStyle(ShouxiaPalette.mutedInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var bottomMessage: some View {
        if let lastCompleted = store.lastCompleted {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(ShouxiaPalette.apricot.opacity(0.18))
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(ShouxiaPalette.apricot)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("收下啦")
                        .font(.subheadline.weight(.bold))
                    Text(lastCompleted.code)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Button("撤销") {
                    Task { await store.undoLastCompletion() }
                }
                .font(.subheadline.weight(.bold))
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 14)
            .frame(height: 64)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: ShouxiaPalette.ink.opacity(0.12), radius: 22, y: 8)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let notice = store.notice {
            HStack(spacing: 10) {
                Image(systemName: iconName(for: notice))
                    .foregroundStyle(noticeColor(for: notice))
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
            .frame(minHeight: 52)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func complete(_ record: PickupRecord) {
        guard completingID == nil else { return }

        if reduceMotion {
            withAnimation(.easeOut(duration: 0.16)) {
                store.beginCompletion(record)
            }
            persistCompletion(record)
            return
        }

        withAnimation(.spring(duration: 0.42, bounce: 0.12)) {
            completingID = record.id
        }

        Task {
            try? await Task.sleep(for: .milliseconds(460))
            withAnimation(.spring(duration: 0.38, bounce: 0.16)) {
                store.beginCompletion(record)
                completingID = nil
            }
            await persistAndDismissUndo(record)
        }
    }

    private func persistCompletion(_ record: PickupRecord) {
        Task {
            await persistAndDismissUndo(record)
        }
    }

    private func persistAndDismissUndo(_ record: PickupRecord) async {
        await store.persistCompletion(record)
        try? await Task.sleep(for: .seconds(5))
        withAnimation(.easeOut(duration: 0.2)) {
            store.dismissUndo(for: record.id)
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

    private func noticeColor(for notice: PickupStore.Notice) -> Color {
        switch notice {
        case .success:
            ShouxiaPalette.sage
        case .neutral:
            ShouxiaPalette.evergreen
        case .error:
            ShouxiaPalette.apricot
        }
    }
}

private struct PickupCard: View {
    let record: PickupRecord
    let isCompleting: Bool
    let reduceMotion: Bool
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var crossedThreshold = false

    private let completionThreshold: CGFloat = 108

    var body: some View {
        ZStack(alignment: .leading) {
            swipeTrack
            card
                .offset(x: isCompleting ? 118 : dragOffset, y: isCompleting ? 360 : 0)
                .scaleEffect(isCompleting ? 0.22 : 1)
                .rotationEffect(.degrees(isCompleting ? 7 : Double(dragOffset / 36)))
                .opacity(isCompleting ? 0.08 : 1)
                .simultaneousGesture(dragGesture)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "收下", onComplete)
    }

    private var swipeTrack: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.26))
                Image(systemName: crossedThreshold ? "checkmark" : "shippingbox.fill")
                    .font(.subheadline.weight(.bold))
            }
            .frame(width: 38, height: 38)
            Text(crossedThreshold ? "松手收下" : "向右滑")
                .font(.subheadline.weight(.bold))
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, minHeight: 148)
        .background(ShouxiaPalette.sage, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Label(record.location ?? "地点待确认", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let platform = record.platform {
                    Text(platform)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(ShouxiaPalette.evergreen)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ShouxiaPalette.evergreen.opacity(0.09), in: Capsule())
                }
            }

            Text(record.code)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.62)
                .lineLimit(1)
                .foregroundStyle(ShouxiaPalette.ink)
                .tracking(0.8)
                .textSelection(.enabled)
                .accessibilityLabel("取件码 \(record.code)")

            HStack {
                Label {
                    Text(record.createdAt, style: .relative)
                } icon: {
                    Image(systemName: "clock")
                }
                Spacer()
                Text(record.source.displayName)
            }
            .font(.caption)
            .foregroundStyle(ShouxiaPalette.softInk)
        }
        .padding(19)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(
            LinearGradient(
                colors: [ShouxiaPalette.paper, ShouxiaPalette.warmPaper],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3)
                .fill(ShouxiaPalette.accent(for: record))
                .frame(width: 5)
                .padding(.vertical, 18)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ShouxiaPalette.line, lineWidth: 1)
        }
        .shadow(color: ShouxiaPalette.ink.opacity(0.07), radius: 18, y: 9)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard !isCompleting else { return }
                let nextOffset = min(max(value.translation.width, 0), 148)
                dragOffset = nextOffset
                crossedThreshold = nextOffset >= completionThreshold
            }
            .onEnded { _ in
                if crossedThreshold {
                    onComplete()
                }
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.14)
                        : .spring(duration: 0.32, bounce: 0.18)
                ) {
                    dragOffset = 0
                    crossedThreshold = false
                }
            }
    }
}

#Preview("正式空状态") {
    InboxView()
}
