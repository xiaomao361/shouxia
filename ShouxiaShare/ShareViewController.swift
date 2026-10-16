import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ImageIO

@MainActor
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = PickupShareModel(context: extensionContext)
        let host = UIHostingController(rootView: PickupShareView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }
}

@MainActor
final class PickupShareModel: ObservableObject {
    enum Phase { case loading, review, saving, saved, failed, cancelled }
    @Published var phase: Phase = .loading
    @Published var review = PickupCandidateReview()
    @Published var message = ""
    @Published var recognitionIssues: [String] = []
    private var sources: [String: PickupSource] = [:]
    private let context: NSExtensionContext?

    init(context: NSExtensionContext?) { self.context = context }

    func recognize() async {
        guard phase == .loading else { return }
        let items = context?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        let imageProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        let textProviders = providers.filter {
            !$0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
                && $0.hasItemConformingToTypeIdentifier(UTType.text.identifier)
        }
        // Content text is a fallback for text-only hosts, not image captions or titles.
        let inlineTexts = imageProviders.isEmpty && textProviders.isEmpty
            ? items.compactMap { $0.attributedContentText?.string }.filter { !$0.isEmpty } : []
        guard !imageProviders.isEmpty || !textProviders.isEmpty || !inlineTexts.isEmpty else {
            phase = .failed
            message = "没有收到取件文字或图片，请从系统分享菜单选择收下"
            return
        }
        guard imageProviders.count <= 5, textProviders.count + inlineTexts.count <= 10 else {
            phase = .failed
            message = imageProviders.count > 5
                ? PickupImageShareError.tooManyImages.localizedDescription
                : "一次最多分享十段文字，请只选择取件通知再试"
            return
        }
        var groups: [[ImagePickupCandidate]] = []
        var failures: [String] = []
        for provider in imageProviders {
            guard !Task.isCancelled, phase == .loading else { return }
            do {
                let data = try await imageData(from: provider)
                guard !Task.isCancelled, phase == .loading else { return }
                let thumbnail = try await Self.downsample(data)
                guard !Task.isCancelled, phase == .loading else { return }
                let lines = try await ImageTextRecognizer().recognize(in: thumbnail)
                let found = try ImagePickupExtractor().candidates(from: lines)
                guard !Task.isCancelled, phase == .loading else { return }
                groups.append(found)
                for candidate in found { sources[candidate.id] = .imageRecognition }
            } catch {
                guard !Task.isCancelled, phase == .loading else { return }
                failures.append(PickupShareFeedback.recognitionFailure(error, isImage: true))
            }
        }
        for provider in textProviders {
            guard !Task.isCancelled, phase == .loading else { return }
            do {
                let text = try await sharedText(from: provider)
                let found = try PickupSharedTextParser().candidates(from: text)
                guard !Task.isCancelled, phase == .loading else { return }
                groups.append(found)
                for candidate in found { sources[candidate.id] = .sharedText }
            } catch {
                guard !Task.isCancelled, phase == .loading else { return }
                failures.append(PickupShareFeedback.recognitionFailure(error, isImage: false))
            }
        }
        for text in inlineTexts {
            guard !Task.isCancelled, phase == .loading else { return }
            do {
                let found = try PickupSharedTextParser().candidates(from: text)
                guard !Task.isCancelled, phase == .loading else { return }
                groups.append(found)
                for candidate in found { sources[candidate.id] = .sharedText }
            } catch {
                guard !Task.isCancelled, phase == .loading else { return }
                failures.append(PickupShareFeedback.recognitionFailure(error, isImage: false))
            }
        }
        guard !Task.isCancelled, phase == .loading else { return }
        recognitionIssues = PickupShareFeedback.groupedFailures(failures)
        let candidates = ImagePickupBatchMerger().merge(groups)
        review = PickupCandidateReview(candidates: candidates, sources: sources)
        let unresolved = candidates.map(\.unresolvedNotificationCount).max() ?? 0
        if unresolved > 0 { recognitionIssues.append("另有 \(unresolved) 条通知未找到明确取件码，请单独核对") }
        if candidates.isEmpty {
            phase = .failed
            message = "没有找到可用的取件码，请分享完整取件通知、单独的取件码或清晰截图"
        } else {
            phase = .review
        }
    }

    func setSelected(_ selected: Bool, id: UUID) {
        guard phase == .review else { return }
        review.setSelected(selected, id: id)
        message = ""
    }

    func save() {
        guard phase == .review else { return }
        message = ""
        do {
            let selected = try review.validatedSelection()
            guard !selected.isEmpty else { return }
            let items = selected.map { item in
                PickupImageShareBatch.Item(code: item.candidate.code, location: item.candidate.location,
                                           platform: item.candidate.platform, source: item.source)
            }
            phase = .saving
            try PickupImageShareQueue.shared().enqueue(PickupImageShareBatch(items: items))
            message = "已保存 \(items.count) 个取件码，下次打开收下时自动加入待取"
            phase = .saved
        } catch let error as PickupCandidateReviewError {
            message = error.localizedDescription
            phase = .review
        } catch {
            message = PickupShareFeedback.saveFailure(error)
            phase = .review
        }
    }

    func finish() { context?.completeRequest(returningItems: nil) }
    func cancel() {
        guard phase != .saved && phase != .saving else { return }
        phase = .cancelled
        context?.cancelRequest(withError: CocoaError(.userCancelled))
    }

    private func sharedText(from provider: NSItemProvider) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadObject(ofClass: NSString.self) { value, error in
                if let error { continuation.resume(throwing: error) }
                else if let value = value as? NSString { continuation.resume(returning: value as String) }
                else { continuation.resume(throwing: PickupSharedTextParser.SharedTextError.noCode) }
            }
        }
    }

    private func imageData(from provider: NSItemProvider) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: ImagePickupRecognitionError.unreadableImage) }
            }
        }
    }

    nonisolated private static func downsample(_ data: Data) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            guard data.count <= 20 * 1024 * 1024 else { throw PickupImageShareError.oversizedImage }
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 2400,
                    kCGImageSourceShouldCacheImmediately: true
                  ] as CFDictionary),
                  let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.95) else {
                throw ImagePickupRecognitionError.unreadableImage
            }
            return jpeg
        }.value
    }
}

private struct PickupShareView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var model: PickupShareModel
    @State private var editingItem: PickupCandidateReview.Item?

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        switch model.phase {
                        case .loading, .saving:
                            ProgressView(model.phase == .loading ? "正在识别取件信息" : "正在保存")
                                .padding(.top, 36)
                        case .review:
                            Text("核对取件信息")
                                .font(.title2.weight(.semibold))
                            if !model.recognitionIssues.isEmpty {
                                Text("部分内容未识别，请核对是否遗漏")
                                    .font(.subheadline.weight(.semibold))
                                recognitionIssues
                            }
                            ForEach(model.review.items) { item in
                                reviewRowLayout {
                                    Toggle(isOn: Binding(
                                        get: { item.selected },
                                        set: { model.setSelected($0, id: item.id) }
                                    )) {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(item.candidate.code).font(.title3.bold().monospacedDigit())
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(item.candidate.location ?? "地点未识别")
                                                .font(.subheadline).foregroundStyle(ShouxiaPalette.supportingInk)
                                            if let brand = item.candidate.platform {
                                                ShouxiaBrandBadge(brand: PickupDirectory.displayLabel(for: brand))
                                            }
                                            if let hint = item.candidate.confirmationHint {
                                                Label(hint, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(ShouxiaPalette.warningInk)
                                            }
                                        }
                                    }
                                    .disabled(item.candidate.reviewIssue == .truncated || item.candidate.locationRequiresConfirmation)
                                    .accessibilityLabel("取件码 \(item.candidate.code)，\(item.candidate.location ?? "地点未识别")")
                                    .accessibilityHint(item.candidate.confirmationHint ?? "取消选择后不会添加这条取件信息")
                                    Button("更正") { editingItem = item }
                                        .frame(minWidth: 44, minHeight: 44)
                                        .accessibilityLabel("更正取件码 \(item.candidate.code) 的信息")
                                }
                                .padding(16)
                                .background(ShouxiaPalette.paper, in: RoundedRectangle(cornerRadius: 20))
                            }
                            Text("保存后打开收下，所选内容会加入待取。不保存原图或分享原文。")
                                .font(.caption).foregroundStyle(ShouxiaPalette.supportingInk)
                            if !model.message.isEmpty { Text(model.message).foregroundStyle(ShouxiaPalette.warningInk) }
                            Button(model.review.selectedCount == 0 ? "请先选择取件码" : "保存 \(model.review.selectedCount) 个取件码", action: model.save)
                                .buttonStyle(ShouxiaPrimaryButtonStyle())
                                .disabled(model.review.selectedCount == 0)
                        case .saved:
                            Image(systemName: "checkmark.circle.fill").font(.largeTitle)
                                .foregroundStyle(ShouxiaPalette.accentInk)
                            Text(model.message)
                            Button("完成", action: model.finish).buttonStyle(ShouxiaPrimaryButtonStyle())
                        case .failed:
                            Text(model.message)
                            recognitionIssues
                            Button("关闭", action: model.cancel).buttonStyle(ShouxiaPrimaryButtonStyle())
                        case .cancelled:
                            EmptyView()
                        }
                    }
                    .foregroundStyle(ShouxiaPalette.ink)
                    .padding(20)
                }
            }
            .navigationTitle("收下")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.phase != .saved && model.phase != .saving && model.phase != .cancelled {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消", action: model.cancel)
                    }
                }
            }
        }
        .sheet(item: $editingItem) { item in
            PickupCandidateEditView(item: item, review: $model.review)
        }
        .tint(ShouxiaPalette.accentInk)
        .shouxiaRoundedFont()
        .task { await model.recognize() }
    }

    private var reviewRowLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    private var recognitionIssues: some View {
        ForEach(model.recognitionIssues, id: \.self) { issue in
            Text(issue)
                .font(.subheadline)
                .foregroundStyle(ShouxiaPalette.supportingInk)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
