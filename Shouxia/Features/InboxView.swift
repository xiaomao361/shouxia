import PhotosUI
import SwiftUI
import UIKit

private struct InboxMoodCopy: Equatable {
    let title: String
    let subtitle: String

    static func random(
        for pendingCount: Int,
        excluding current: InboxMoodCopy? = nil
    ) -> InboxMoodCopy {
        if ProcessInfo.processInfo.arguments.contains("-screenshot-mode") {
            return pendingCount == 0
                ? InboxMoodCopy(
                    title: "你要取的，都在这里",
                    subtitle: "自己的自动收，别人托的随手收。"
                )
                : InboxMoodCopy(
                    title: "有 \(pendingCount) 个包裹等你去取",
                    subtitle: "自己的自动收，别人托的随手收。"
                )
        }

        let choices = pendingCount == 0
            ? emptyChoices
            : pendingChoices(count: pendingCount)
        let alternatives = choices.filter { $0 != current }
        return (alternatives.isEmpty ? choices : alternatives).randomElement()
            ?? InboxMoodCopy(
                title: "你要取的，都在这里",
                subtitle: "自己的自动收，别人托的随手收。"
            )
    }

    private static let emptyChoices = [
        InboxMoodCopy(
            title: "你要取的，都在这里",
            subtitle: "自己的自动收，别人托的随手收。"
        ),
        InboxMoodCopy(
            title: "暂时没有要取的",
            subtitle: "有人托你取快递时，把文字或截图交给收下。"
        ),
        InboxMoodCopy(
            title: "今天不用翻消息",
            subtitle: "自己的短信可以自动进来，别人发来的也能随手收好。"
        ),
        InboxMoodCopy(
            title: "该取的都取完了",
            subtitle: "下次收到取件文字或截图，再交给收下。"
        ),
    ]

    private static func pendingChoices(count: Int) -> [InboxMoodCopy] {
        [
            InboxMoodCopy(
                title: "有 \(count) 个包裹等你去取",
                subtitle: "自己的和别人托的，取件码都放好了。"
            ),
            InboxMoodCopy(
                title: "今天要带回 \(count) 件",
                subtitle: "到驿站时，轻点卡片就能大字查看。"
            ),
            InboxMoodCopy(
                title: "\(count) 个包裹，慢慢拿",
                subtitle: "不用翻短信，取件码都在这里。"
            ),
            InboxMoodCopy(
                title: "顺路收下 \(count) 个包裹",
                subtitle: "到了地方再打开，也来得及。"
            ),
        ]
    }
}

private struct ImageImportReview: Identifiable {
    let id = UUID()
    let candidates: [ImagePickupCandidate]
}

struct InboxView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("automationSetupCardHidden") private var automationSetupCardHidden = false
    @AppStorage("automationSetupAutoHideHandled") private var automationSetupAutoHideHandled = false
    @State private var store = PickupStore()
    @State private var presentedSheet: PresentedSheet?
    @State private var selectedPickup: PickupRecord?
    @State private var completingID: UUID?
    @State private var moodCopy = InboxMoodCopy.random(for: 0)
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isRecognizingImage = false

    private let imageTextRecognizer = ImageTextRecognizer()
    private let imagePickupExtractor = ImagePickupExtractor()

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        intro

                        if ProcessInfo.processInfo.arguments.contains("-screenshot-mode")
                            || !automationSetupCardHidden {
                            automationSetupCard
                        }

                        if store.pendingRecords.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.pendingRecords) { record in
                                PickupCard(
                                    record: record,
                                    isCompleting: completingID == record.id,
                                    reduceMotion: reduceMotion,
                                    onOpen: {
                                        selectedPickup = record
                                    },
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
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !store.pendingRecords.isEmpty {
                        Button {
                            presentedSheet = .handoffCompose
                        } label: {
                            Image(systemName: "person.2")
                        }
                        .accessibilityLabel("请人帮取")
                        .accessibilityHint("选择待取包裹并生成收下交接包")
                    }

                    Button {
                        presentedSheet = .about
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("隐私与关于")

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
                case .about:
                    AboutView()
                case .handoffCompose:
                    PickupHandoffComposeView(records: store.pendingRecords)
                case let .handoffReview(package):
                    PickupHandoffReviewView(package: package, store: store)
                case .history:
                    NavigationStack {
                        HistoryView(store: store)
                    }
                    .tint(ShouxiaPalette.mutedInk)
                case .automationSetup:
                    AutomationSetupView()
                case let .imageReview(review):
                    ImageImportReviewView(
                        review: review,
                        store: store
                    )
                }
            }
            .fullScreenCover(item: $selectedPickup) { record in
                PickupModeView(
                    records: pickupModeRecords(startingAt: record),
                    initialRecordID: record.id
                )
            }
            .task {
                await store.load()
                hideAutomationSetupAfterSMSImport()
            }
            .onChange(of: store.pendingRecords.count) { _, count in
                moodCopy = InboxMoodCopy.random(for: count, excluding: moodCopy)
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    await recognizeImage(from: item)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await store.load()
                    hideAutomationSetupAfterSMSImport()
                }
            }
            .onOpenURL { url in
                openHandoffPackage(at: url)
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .fontDesign(.rounded)
    }

    private enum PresentedSheet: Identifiable {
        case about
        case automationSetup
        case handoffCompose
        case handoffReview(PickupHandoffPackage)
        case history
        case imageReview(ImageImportReview)

        var id: String {
            switch self {
            case .about:
                "about"
            case .automationSetup:
                "automationSetup"
            case .handoffCompose:
                "handoffCompose"
            case let .handoffReview(package):
                "handoffReview-\(package.id)"
            case .history:
                "history"
            case let .imageReview(review):
                "imageReview-\(review.id)"
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(moodCopy.title)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(moodCopy.subtitle)
                .font(.subheadline)
                .foregroundStyle(ShouxiaPalette.mutedInk)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            importActions
        }
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    private var importActions: some View {
        let recognizingImage = isRecognizingImage

        return VStack(alignment: .leading, spacing: 10) {
            Text("他人托你取的")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ShouxiaPalette.mutedInk)

            HStack(spacing: 10) {
                Button {
                    let text = UIPasteboard.general.string ?? ""
                    Task { await store.importText(text, source: .paste) }
                } label: {
                    Text("粘贴取件信息")
                }
                .buttonStyle(ShouxiaPrimaryButtonStyle())
                .accessibilityLabel("读取剪贴板并添加别人发来的取件信息")
                .accessibilityHint("请先从聊天或其他 App 复制对方发来的完整取件文字")

                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Group {
                        if recognizingImage {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("正在识别图片")
                        } else {
                            Label("识别取件截图", systemImage: "photo")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ShouxiaSecondaryButtonStyle())
                .disabled(recognizingImage)
                .accessibilityHint("从相册选择他人发来的取件截图")
            }
        }
    }

    private var automationSetupCard: some View {
        HStack(spacing: 10) {
            Button {
                presentedSheet = .automationSetup
            } label: {
                HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            ShouxiaPalette.warmPaper
                        )
                    Image(systemName: "message.badge")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ShouxiaPalette.ink)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("自己的取件短信，自动收好")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)

                    Text("设置一次，发到这台 iPhone 的取件短信会自动进入收下。")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ShouxiaPalette.softInk)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("为自己的快递开启短信自动收码")
            .accessibilityHint("打开快捷指令和个人自动化的两阶段设置说明")

            Button {
                automationSetupCardHidden = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ShouxiaPalette.softInk)
                    .frame(width: 30, height: 42)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("隐藏短信自动收码设置入口")
        }
        .padding(14)
        .background(
            ShouxiaPalette.paper.opacity(0.92),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ShouxiaMark(showsBackground: true)
                .frame(width: 112, height: 112)

            VStack(spacing: 7) {
                Text("别人托你取的，也能收好")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)
                Text("粘贴聊天里的取件文字，或识别对方发来的截图。")
                    .font(.subheadline)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
        .background(
            ShouxiaPalette.paper.opacity(0.88),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var completionHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: reduceMotion ? "figure.roll" : "hand.draw.fill")
                .foregroundStyle(ShouxiaPalette.breezePressed)
            Text(
                reduceMotion
                    ? "向右滑动卡片即可收下。"
                    : "向右滑，轻轻收下。"
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
                ShouxiaMark(showsBackground: true)
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text("轻轻收下了")
                        .font(.subheadline.weight(.semibold))
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
            .background(
                ShouxiaPalette.warmPaper.opacity(0.96),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
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

        withAnimation(ShouxiaMotion.completion) {
            completingID = record.id
        }

        Task {
            try? await Task.sleep(for: .milliseconds(460))
            withAnimation(ShouxiaMotion.settle) {
                store.beginCompletion(record)
                completingID = nil
            }
            await persistAndDismissUndo(record)
        }
    }

    private func pickupModeRecords(startingAt record: PickupRecord) -> [PickupRecord] {
        let recordsAtSameLocation = store.pendingRecords.filter {
            $0.id == record.id || $0.sharesPickupLocation(with: record)
        }
        return recordsAtSameLocation.isEmpty ? [record] : recordsAtSameLocation
    }

    private func hideAutomationSetupAfterSMSImport() {
        guard !ProcessInfo.processInfo.arguments.contains("-screenshot-mode"),
              !automationSetupAutoHideHandled,
              store.records.contains(where: { $0.source == .smsAutomation })
        else {
            return
        }
        automationSetupCardHidden = true
        automationSetupAutoHideHandled = true
    }

    private func openHandoffPackage(at url: URL) {
        guard url.pathExtension.lowercased() == "shouxia" else { return }
        do {
            presentedSheet = .handoffReview(
                try PickupHandoffPackage.decode(contentsOf: url)
            )
        } catch let error as PickupHandoffError {
            store.showNotice(.error(error.localizedDescription))
        } catch {
            store.showNotice(.error("这个交接包无法读取，请让对方重新发送"))
        }
    }

    @MainActor
    private func recognizeImage(from item: PhotosPickerItem) async {
        isRecognizingImage = true
        defer {
            isRecognizingImage = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ImagePickupRecognitionError.unreadableImage
            }
            let lines = try await imageTextRecognizer.recognize(in: data)
            try Task.checkCancellation()
            let candidates = try imagePickupExtractor.candidates(from: lines)

            if candidates.count == 1, candidates[0].isHighConfidence {
                await store.importImageCandidates(candidates)
            } else {
                presentedSheet = .imageReview(
                    ImageImportReview(candidates: candidates)
                )
            }
        } catch is CancellationError {
            return
        } catch let error as ImagePickupRecognitionError {
            store.showNotice(.error(error.localizedDescription))
        } catch {
            store.showNotice(.error("图片没有识别成功，请换一张再试"))
        }
    }

    private func persistCompletion(_ record: PickupRecord) {
        Task {
            await persistAndDismissUndo(record)
        }
    }

    private func persistAndDismissUndo(_ record: PickupRecord) async {
        await store.persistCompletion(record)
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-keep-undo-visible") {
            return
        }
#endif
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
            ShouxiaPalette.breezePressed
        case .neutral:
            ShouxiaPalette.mutedInk
        case .error:
            ShouxiaPalette.apricot
        }
    }
}

private struct PickupHandoffComposeView: View {
    @Environment(\.dismiss) private var dismiss

    let records: [PickupRecord]
    @State private var selectedIDs: Set<UUID>

    init(records: [PickupRecord]) {
        self.records = records
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
                                ShareLink(
                                    item: PickupHandoffPackage(records: selectedRecords),
                                    subject: Text("收下交接包 · \(selectedRecords.count) 件"),
                                    message: Text("请帮我取这 \(selectedRecords.count) 件，点开交接包即可导入收下。"),
                                    preview: SharePreview(
                                        Text("收下交接包 · \(selectedRecords.count) 件"),
                                        icon: Image(systemName: "shippingbox.fill")
                                    )
                                ) {
                                    Label(
                                        "发送交接包（\(selectedRecords.count) 件）",
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                                .buttonStyle(ShouxiaPrimaryButtonStyle())
                            }

                            Text("交接包只包含取件码、地点和平台，不包含短信原文、手机号、运单号或商品信息。发送后不会自动删除你这里的记录。")
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
        .fontDesign(.rounded)
    }

    private func toggle(_ record: PickupRecord) {
        if selectedIDs.contains(record.id) {
            selectedIDs.remove(record.id)
        } else if selectedIDs.count < PickupHandoffPackage.maximumItemCount {
            selectedIDs.insert(record.id)
        }
    }
}

private struct PickupHandoffReviewView: View {
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

                            Text("确认后，这些取件信息会加入你的待取列表。")
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

                        Text("交接包是对方发出时的快照，不会建立账号、云同步或双方状态联动。")
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

private struct HandoffSelectionRow: View {
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

private struct ImageImportReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let review: ImageImportReview
    let store: PickupStore

    @State private var selectedIDs: Set<String>
    @State private var isSaving = false

    init(review: ImageImportReview, store: PickupStore) {
        self.review = review
        self.store = store
        _selectedIDs = State(initialValue: Set(review.candidates.map(\.id)))
    }

    private var selectedCandidates: [ImagePickupCandidate] {
        review.candidates.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 7) {
                            Text(title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ShouxiaPalette.ink)

                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(ShouxiaPalette.mutedInk)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 10)

                        VStack(spacing: 10) {
                            ForEach(review.candidates) { candidate in
                                Button {
                                    toggle(candidate)
                                } label: {
                                    ImageCandidateRow(
                                        candidate: candidate,
                                        isSelected: selectedIDs.contains(candidate.id)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("原图和未选中的其他文字不会保存在收下里。")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.softInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)

                        Button {
                            Task {
                                isSaving = true
                                await store.importImageCandidates(selectedCandidates)
                                dismiss()
                            }
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text(
                                    selectedCandidates.count > 1
                                        ? "添加 \(selectedCandidates.count) 个取件码"
                                        : "添加这个取件码"
                                )
                            }
                        }
                        .buttonStyle(ShouxiaPrimaryButtonStyle())
                        .disabled(selectedCandidates.isEmpty || isSaving)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("确认图片识别结果")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .fontDesign(.rounded)
    }

    private var title: String {
        review.candidates.count > 1
            ? "找到了 \(review.candidates.count) 个可能的取件码"
            : "请确认这个取件码"
    }

    private var detail: String {
        review.candidates.count > 1
            ? "勾选这张图片里真正需要收下的取件码。"
            : "图片里没有足够明确的标签，请核对后再添加。"
    }

    private func toggle(_ candidate: ImagePickupCandidate) {
        if selectedIDs.contains(candidate.id) {
            selectedIDs.remove(candidate.id)
        } else {
            selectedIDs.insert(candidate.id)
        }
    }
}

private struct ImageCandidateRow: View {
    let candidate: ImagePickupCandidate
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(
                    isSelected
                        ? ShouxiaPalette.breezePressed
                        : ShouxiaPalette.softInk
                )

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.code)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(candidate.location ?? "地点没有识别出来")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let platform = candidate.platform {
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
                .stroke(
                    isSelected
                        ? ShouxiaPalette.breezePressed.opacity(0.52)
                        : ShouxiaPalette.line,
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(isSelected ? "已选择" : "未选择")，取件码 \(candidate.code)，\(candidate.location ?? "地点未识别")"
        )
    }
}

private struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("automationSetupCardHidden") private var automationSetupCardHidden = false

    private var versionText: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0.0"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "1"
        return "版本 \(version)（\(build)）"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                ScrollView {
                    VStack(spacing: 22) {
                        ShouxiaMark(showsBackground: true)
                            .frame(width: 92, height: 92)
                            .padding(.top, 10)

                        VStack(spacing: 5) {
                            Text("收下")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(ShouxiaPalette.ink)
                            Text(versionText)
                                .font(.caption)
                                .foregroundStyle(ShouxiaPalette.softInk)
                        }

                        VStack(alignment: .leading, spacing: 0) {
                            PrivacyRow(
                                icon: "iphone",
                                title: "只在本机处理",
                                detail: "取件通知、取件码、地点和历史记录只保存在你的设备上，不会发送到开发者服务器。"
                            )
                            PrivacyDivider()
                            PrivacyRow(
                                icon: "doc.on.clipboard",
                                title: "由你主动粘贴",
                                detail: "只有点击“粘贴取件信息”后，收下才会读取当前剪贴板内容。"
                            )
                            PrivacyDivider()
                            PrivacyRow(
                                icon: "photo",
                                title: "图片只在本机识别",
                                detail: "你选择的物流图片由 Apple Vision 在设备上识别；收下不保存原图，也不保留手机号、运单号或商品等无关文字。"
                            )
                            PrivacyDivider()
                            PrivacyRow(
                                icon: "message",
                                title: "短信自动化由你控制",
                                detail: "收下只能处理你在快捷指令个人自动化中明确交给它的短信文本，不能读取短信历史或其他 App 的通知。"
                            )
                            PrivacyDivider()
                            PrivacyRow(
                                icon: "person.2",
                                title: "交接包由你主动发送",
                                detail: "交接包只包含你选中的取件码、地点和平台；不包含短信原文、手机号、运单号或商品信息。"
                            )
                            PrivacyDivider()
                            PrivacyRow(
                                icon: "person.crop.circle.badge.xmark",
                                title: "不跟踪、不建账号",
                                detail: "当前版本不包含广告、分析 SDK、用户账号、云同步或跨 App 跟踪。"
                            )
                        }
                        .background(
                            ShouxiaPalette.paper.opacity(0.94),
                            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
                        }

                        if automationSetupCardHidden {
                            Button {
                                automationSetupCardHidden = false
                                dismiss()
                            } label: {
                                Label(
                                    "重新显示短信自动收码设置",
                                    systemImage: "message.badge"
                                )
                            }
                            .buttonStyle(ShouxiaSecondaryButtonStyle())
                            .accessibilityHint("关闭本页后，设置入口会重新出现在首页")
                        }

                        Text("你可以在“收下记录”中归档内容，并在归档页永久删除。永久删除后无法恢复。")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.softInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 10)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("隐私与关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .fontDesign(.rounded)
    }
}

private struct PrivacyRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ShouxiaPalette.breezePressed)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 17)
        .accessibilityElement(children: .combine)
    }
}

private struct PrivacyDivider: View {
    var body: some View {
        Rectangle()
            .fill(ShouxiaPalette.line)
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

private struct AutomationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("automationSetupCardHidden") private var automationSetupCardHidden = false

    private let shortcutURL = URL(
        string: "https://www.icloud.com/shortcuts/cd785f47a8244d32b1cf3c7c6f4dad8a"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        ShouxiaMark(showsBackground: true)
                            .frame(width: 88, height: 88)
                            .padding(.top, 12)

                        VStack(spacing: 8) {
                            Text("自己的取件短信，自动收好")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(ShouxiaPalette.ink)

                            Text("先一键添加“收下自动收码”，再手动创建一次“信息”个人自动化。以后收到自己的取件短信，不用复制，也不用打开收下。")
                            .font(.subheadline)
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("第一段")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(ShouxiaPalette.apricot)

                            Text("一键添加普通快捷指令")
                                .font(.headline)
                                .foregroundStyle(ShouxiaPalette.ink)

                            Button {
                                guard let shortcutURL else { return }
                                openURL(shortcutURL)
                            } label: {
                                Label(
                                    "添加“收下自动收码”",
                                    systemImage: "square.and.arrow.down"
                                )
                            }
                            .buttonStyle(ShouxiaPrimaryButtonStyle())
                            .accessibilityHint("打开苹果快捷指令导入页，仍需确认添加")

                            Text("苹果会显示快捷指令内容，请确认名称和两个操作后点“添加快捷指令”。")
                                .font(.caption)
                                .foregroundStyle(ShouxiaPalette.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            ShouxiaPalette.paper.opacity(0.94),
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
                        }

                        AutomationSetupSection(
                            eyebrow: "链接打不开时",
                            title: "也可以手动创建",
                            steps: [
                                AutomationSetupStepContent(
                                    title: "新建“收下自动收码”",
                                    detail: "打开快捷指令，在“快捷指令”页新建一个普通快捷指令，并命名为“收下自动收码”。"
                                ),
                                AutomationSetupStepContent(
                                    title: "取得输入文字",
                                    detail: "添加“从快捷指令输入中获取文本”，让系统把收到的信息转换成文字。"
                                ),
                                AutomationSetupStepContent(
                                    title: "把文字交给收下",
                                    detail: "添加“保存取件短信”，把它的“短信内容”连接到上一步输出的“文本”，然后保存。"
                                ),
                            ]
                        )

                        AutomationSetupSection(
                            eyebrow: "第二段",
                            title: "再建“信息”个人自动化",
                            steps: [
                                AutomationSetupStepContent(
                                    title: "选择“信息”",
                                    detail: "点底部“自动化”和右上角“+”，选择“信息”；发件人保持“任何发件人”。"
                                ),
                                AutomationSetupStepContent(
                                    title: "设置短信条件",
                                    detail: "将“信息包含”设为“取件”，选择“立即运行”，然后继续。"
                                ),
                                AutomationSetupStepContent(
                                    title: "运行刚建的快捷指令",
                                    detail: "选择“运行快捷指令”，再选择“收下自动收码”，最后保存。不要直接选择“保存取件短信”。"
                                ),
                            ]
                        )

                        VStack(spacing: 12) {
                            Button {
                                guard let url = URL(string: "shortcuts://") else { return }
                                openURL(url)
                            } label: {
                                Label("去创建个人自动化", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(ShouxiaPrimaryButtonStyle())
                            .accessibilityHint("打开后，请点底部的自动化")

                            Label(
                                "设置后，请用第一条真实取件短信验证",
                                systemImage: "hourglass"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Label("没有自动添加？按这个顺序检查", systemImage: "wrench.and.screwdriver")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(ShouxiaPalette.ink)

                            Text("自动化已启用且选择“立即运行” → 正在运行“收下自动收码” → 快捷指令输入已转换成文本 → “短信内容”连接的是该文本变量。")
                                .font(.caption)
                                .foregroundStyle(ShouxiaPalette.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            ShouxiaPalette.warmPaper.opacity(0.9),
                            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                        )

                        Text("收下无法查询个人自动化是否配置成功。只有第一条真实短信自动进入 App，才能证明整条链路完成。仅支持进入苹果“信息”App 的 SMS 或 iMessage；支付宝及其他 App 的通知无法读取。")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.softInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 12)

                        Button {
                            automationSetupCardHidden = true
                            dismiss()
                        } label: {
                            Text("我已设置，隐藏首页入口")
                        }
                        .buttonStyle(ShouxiaSecondaryButtonStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("短信自动收码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .tint(ShouxiaPalette.mutedInk)
        .fontDesign(.rounded)
    }
}

private struct AutomationSetupStepContent {
    let title: String
    let detail: String
}

private struct AutomationSetupSection: View {
    let eyebrow: String
    let title: String
    var startingNumber = 1
    let steps: [AutomationSetupStepContent]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.breezePressed)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(ShouxiaPalette.ink)
            }
            .padding(.horizontal, 16)
            .padding(.top, 17)
            .padding(.bottom, 8)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    AutomationSetupDivider()
                }
                AutomationSetupStep(
                    number: startingNumber + index,
                    title: step.title,
                    detail: step.detail
                )
            }
        }
        .background(
            ShouxiaPalette.paper.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
        }
    }
}

private struct AutomationSetupStep: View {
    let number: Int
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(ShouxiaPalette.ink)
                .frame(width: 30, height: 30)
                .background(ShouxiaPalette.breeze.opacity(0.76), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 17)
        .accessibilityElement(children: .combine)
    }
}

private struct AutomationSetupDivider: View {
    var body: some View {
        Rectangle()
            .fill(ShouxiaPalette.line)
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

private struct PickupCard: View {
    private enum DragDirection {
        case horizontal
        case vertical
    }

    let record: PickupRecord
    let isCompleting: Bool
    let reduceMotion: Bool
    let onOpen: () -> Void
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var crossedThreshold = false
    @State private var dragDirection: DragDirection?

    private let completionThreshold: CGFloat = 108

    private var dragProgress: CGFloat {
        min(dragOffset / completionThreshold, 1)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            swipeTrack
            card
                .offset(
                    x: isCompleting ? 132 : dragOffset,
                    y: isCompleting ? 52 : 0
                )
                .scaleEffect(
                    isCompleting
                        ? 0.78
                        : 1 - (dragProgress * 0.018)
                )
                .rotationEffect(
                    .degrees(
                        isCompleting
                            ? 4
                            : Double(dragProgress * 2.4)
                    )
                )
                .opacity(isCompleting ? 0 : 1)
                .simultaneousGesture(dragGesture)
                .onTapGesture(perform: onOpen)
        }
        .sensoryFeedback(
            .impact(weight: .medium, intensity: 0.72),
            trigger: crossedThreshold
        ) { oldValue, newValue in
            !oldValue && newValue
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("轻点用大字查看取件码，向右滑动可以收下")
        .accessibilityAction {
            onOpen()
        }
        .accessibilityAction(named: "收下", onComplete)
    }

    private var swipeTrack: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ShouxiaPalette.paper.opacity(0.44))
                Image(systemName: crossedThreshold ? "checkmark" : "shippingbox.fill")
                    .font(.subheadline.weight(.bold))
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 38, height: 38)
            Text(crossedThreshold ? "松手就好" : "向右滑")
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(ShouxiaPalette.ink)
        .padding(.leading, 16)
        .frame(maxWidth: .infinity, minHeight: 148)
        .background(
            LinearGradient(
                colors: crossedThreshold
                    ? [ShouxiaPalette.breezePressed, ShouxiaPalette.breeze]
                    : [ShouxiaPalette.breeze, ShouxiaPalette.skyWash],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .animation(ShouxiaMotion.threshold, value: crossedThreshold)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(record.location ?? "地点待确认")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)
                    .lineLimit(1)

                Spacer(minLength: 8)

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
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.62)
                .lineLimit(1)
                .foregroundStyle(ShouxiaPalette.ink)
                .tracking(0.8)
                .accessibilityLabel("取件码 \(record.code)")

            HStack {
                Label {
                    Text(record.createdAt, style: .relative)
                } icon: {
                    Image(systemName: "clock")
                }
                Spacer()
                Label("大字查看", systemImage: "rectangle.expand.vertical")
            }
            .font(.caption)
            .foregroundStyle(ShouxiaPalette.softInk)
        }
        .padding(.vertical, 19)
        .padding(.leading, 39)
        .padding(.trailing, 19)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(
            ShouxiaPalette.paper,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(ShouxiaPalette.accent(for: record))
                .frame(width: 7, height: 7)
                .padding(.leading, 18)
                .padding(.top, 22)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ShouxiaPalette.line, lineWidth: 1)
        }
        .shadow(
            color: isCompleting
                ? ShouxiaPalette.celebrationGlow
                : ShouxiaPalette.ink.opacity(0.07 + (dragProgress * 0.02)),
            radius: isCompleting ? 28 : 18 - (dragProgress * 6),
            y: isCompleting ? 10 : 9 - (dragProgress * 4)
        )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !isCompleting else { return }

                if dragDirection == nil {
                    dragDirection = abs(value.translation.width) > abs(value.translation.height)
                        ? .horizontal
                        : .vertical
                }

                guard dragDirection == .horizontal else { return }

                let nextOffset = min(max(value.translation.width, 0), 148)
                dragOffset = nextOffset
                crossedThreshold = nextOffset >= completionThreshold
            }
            .onEnded { _ in
                if dragDirection == .horizontal, crossedThreshold {
                    onComplete()
                }
                withAnimation(
                    reduceMotion
                        ? .easeOut(duration: 0.14)
                        : ShouxiaMotion.threshold
                ) {
                    dragOffset = 0
                    crossedThreshold = false
                }
                dragDirection = nil
            }
    }
}

private struct PickupModeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    let records: [PickupRecord]
    @State private var selectedRecordID: UUID

    init(records: [PickupRecord], initialRecordID: UUID) {
        self.records = records
        _selectedRecordID = State(initialValue: initialRecordID)
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
                        PickupCodePage(record: record)
                            .tag(record.id)
                            .padding(.horizontal, 20)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(
                    reduceMotion ? nil : ShouxiaMotion.settle,
                    value: selectedRecordID
                )

                pageFooter
            }
            .padding(.bottom, 18)
        }
        .fontDesign(.rounded)
        .tint(ShouxiaPalette.ink)
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("取件现场")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)

                Text(records.count > 1 ? "同一地点有 \(records.count) 个包裹" : "把取件码给工作人员看")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
            }

            Spacer()

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

    private var pageFooter: some View {
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
                    .foregroundStyle(ShouxiaPalette.mutedInk)
            } else {
                Text("长按取件码可以复制")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
            }
        }
        .frame(minHeight: 46)
        .padding(.horizontal, 20)
    }
}

private struct PickupCodePage: View {
    let record: PickupRecord

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)

            VStack(spacing: 10) {
                Text(record.location ?? "地点待确认")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                if let platform = record.platform {
                    Text(platform)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(ShouxiaPalette.mutedInk)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(ShouxiaPalette.skyWash, in: Capsule())
                }
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Text("取件码")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ShouxiaPalette.mutedInk)

                Text(record.code)
                    .font(.system(size: 78, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(1.2)
                    .foregroundStyle(ShouxiaPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.34)
                    .textSelection(.enabled)
                    .accessibilityLabel("取件码 \(record.code)")
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            Label("请核对地点后出示", systemImage: "shippingbox")
                .font(.caption.weight(.medium))
                .foregroundStyle(ShouxiaPalette.softInk)

            Spacer(minLength: 30)
        }
        .padding(.horizontal, 24)
        .background(
            ShouxiaPalette.paper.opacity(0.96),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(ShouxiaPalette.accent(for: record))
                .frame(width: 10, height: 10)
                .padding(24)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
        }
        .shadow(color: ShouxiaPalette.ink.opacity(0.08), radius: 26, y: 12)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
    }
}

#Preview("正式空状态") {
    InboxView()
}
