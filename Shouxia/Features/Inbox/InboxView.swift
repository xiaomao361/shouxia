import PhotosUI
import SwiftUI
import UIKit

struct InboxView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("automationSetupCardHidden") private var automationSetupCardHidden = false
    @AppStorage("automationSetupAutoHideHandled") private var automationSetupAutoHideHandled = false
    @AppStorage("automaticClipboardImportEnabled") private var automaticClipboardImportEnabled = false
    @AppStorage("commonPickupLocation") private var commonPickupLocation = ""
    @AppStorage("lastProcessedPasteboardChangeCount") private var lastProcessedPasteboardChangeCount = -1
    @State private var store = PickupStore()
    @State private var presentedSheet: PresentedSheet?
    @State private var selectedPickup: PickupRecord?
    @State private var completingID: UUID?
    @State private var moodCopy = InboxMoodCopy.random(for: 0)
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var isRecognizingImage = false
    @State private var isCheckingClipboard = false
    @State private var clipboardCheckRequestID = 0

    private let imageTextRecognizer = ImageTextRecognizer()
    private let imagePickupExtractor = ImagePickupExtractor()
    private let imagePickupBatchMerger = ImagePickupBatchMerger()

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()

                List {
                    intro
                        .listRowInsets(
                            EdgeInsets(top: 0, leading: 18, bottom: 7, trailing: 18)
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)

                    if ProcessInfo.processInfo.arguments.contains("-screenshot-mode")
                        || !automationSetupCardHidden {
                        automationSetupCard
                            .listRowInsets(
                                EdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18)
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }

                    if store.pendingRecords.isEmpty {
                        emptyState
                            .listRowInsets(
                                EdgeInsets(top: 7, leading: 18, bottom: 120, trailing: 18)
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(store.pendingRecords) { record in
                            PickupCard(
                                record: record,
                                isCompleting: completingID == record.id,
                                onOpen: {
                                    selectedPickup = record
                                },
                                onComplete: { complete(record) }
                            )
                            .listRowInsets(
                                EdgeInsets(top: 7, leading: 18, bottom: 7, trailing: 18)
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    complete(record)
                                } label: {
                                    Label("收下", systemImage: "shippingbox.fill")
                                }
                                .tint(ShouxiaPalette.breezePressed)
                            }
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
                            .listRowInsets(
                                EdgeInsets(top: 7, leading: 18, bottom: 120, trailing: 18)
                            )
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.defaultMinListRowHeight, 1)
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
                    PickupHandoffComposeView(
                        records: store.pendingRecords,
                        store: store
                    )
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
                    store: store,
                    records: pickupModeRecords(startingAt: record),
                    initialRecordID: record.id,
                    onComplete: completeFromPickupMode
                )
            }
            .task {
                await store.load()
                hideAutomationSetupAfterSMSImport()
                clipboardCheckRequestID &+= 1
            }
            .task(id: clipboardCheckRequestID) {
                guard clipboardCheckRequestID > 0 else { return }
                await Task.yield()
                guard !Task.isCancelled else { return }
                await importClipboardIfNeeded()
            }
            .onChange(of: store.pendingRecords.count) { _, count in
                moodCopy = InboxMoodCopy.random(for: count, excluding: moodCopy)
            }
            .onChange(of: selectedPhotos) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    await recognizeImages(from: items)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task {
                    await store.load()
                    hideAutomationSetupAfterSMSImport()
                    clipboardCheckRequestID &+= 1
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
                .foregroundStyle(ShouxiaPalette.supportingInk)
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
                .foregroundStyle(ShouxiaPalette.supportingInk)

            HStack(spacing: 10) {
                PasteButton(payloadType: String.self) { strings in
                    Task {
                        await store.importText(
                            strings.joined(separator: "\n"),
                            source: .paste,
                            defaultLocation: normalizedCommonPickupLocation
                        )
                    }
                }
                .controlSize(.large)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .labelStyle(.titleAndIcon)
                .font(.headline)
                .frame(minWidth: 112, minHeight: 50)
                .layoutPriority(1)
                .tint(ShouxiaPalette.breezePressed)
                .accessibilityLabel("粘贴并添加取件码或取件信息")
                .accessibilityHint("可以粘贴单独的四至八位数字取件码，或完整取件通知")

                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 5,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Group {
                        if recognizingImage {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("正在识别图片")
                        } else {
                            Label("识别取件截图", systemImage: "photo.on.rectangle")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ShouxiaImportButtonStyle())
                .disabled(recognizingImage)
                .accessibilityHint("从相册一次选择最多五张取件截图")
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
        let relatedRecords = store.pendingRecords.filter {
            $0.id == record.id || $0.sharesPickupGroup(with: record)
        }
        return relatedRecords.isEmpty ? [record] : relatedRecords
    }

    private func completeFromPickupMode(_ record: PickupRecord) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : ShouxiaMotion.settle) {
            store.beginCompletion(record)
        }
        persistCompletion(record)
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
    private func recognizeImages(from items: [PhotosPickerItem]) async {
        isRecognizingImage = true
        defer {
            isRecognizingImage = false
            selectedPhotos = []
        }

        var candidateGroups: [[ImagePickupCandidate]] = []
        var failedImageCount = 0
        var lastRecognitionError: ImagePickupRecognitionError?

        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw ImagePickupRecognitionError.unreadableImage
                }
                let lines = try await imageTextRecognizer.recognize(in: data)
                try Task.checkCancellation()
                candidateGroups.append(try imagePickupExtractor.candidates(from: lines))
            } catch is CancellationError {
                return
            } catch let error as ImagePickupRecognitionError {
                failedImageCount += 1
                lastRecognitionError = error
            } catch {
                failedImageCount += 1
            }
        }

        let candidates = imagePickupBatchMerger.merge(candidateGroups)
        guard !candidates.isEmpty else {
            store.showNotice(
                .error(
                    lastRecognitionError?.localizedDescription
                        ?? "图片没有识别成功，请换一张再试"
                )
            )
            return
        }

        if items.count == 1, candidates.count == 1, candidates[0].isHighConfidence {
            await store.importImageCandidates(
                candidates,
                defaultLocation: normalizedCommonPickupLocation
            )
        } else {
            presentedSheet = .imageReview(
                ImageImportReview(
                    candidates: candidates,
                    imageCount: items.count,
                    failedImageCount: failedImageCount
                )
            )
        }
    }

    @MainActor
    private func importClipboardIfNeeded() async {
        guard automaticClipboardImportEnabled, !isCheckingClipboard else { return }

        let pasteboard = UIPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastProcessedPasteboardChangeCount else { return }

        isCheckingClipboard = true
        lastProcessedPasteboardChangeCount = changeCount
        defer { isCheckingClipboard = false }

        guard let text = pasteboard.string else { return }
        await store.importClipboardAutomatically(
            text,
            defaultLocation: normalizedCommonPickupLocation
        )
    }

    private var normalizedCommonPickupLocation: String? {
        let normalized = commonPickupLocation
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
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
