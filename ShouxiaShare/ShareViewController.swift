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
    enum Phase { case loading, review, saving, saved, failed }
    @Published var phase: Phase = .loading
    @Published var candidates: [ImagePickupCandidate] = []
    @Published var selectedCodes: Set<String> = []
    @Published var message = ""
    @Published var failedImageCount = 0
    @Published var failedTextCount = 0
    private var sources: [ImagePickupCandidate: PickupSource] = [:]
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
        for provider in imageProviders {
            guard !Task.isCancelled else { return }
            do {
                let data = try await imageData(from: provider)
                let thumbnail = try await Self.downsample(data)
                let lines = try await ImageTextRecognizer().recognize(in: thumbnail)
                let found = try ImagePickupExtractor().candidates(from: lines)
                groups.append(found)
                for candidate in found { sources[candidate] = .imageRecognition }
            } catch {
                failedImageCount += 1
            }
        }
        for provider in textProviders {
            guard !Task.isCancelled else { return }
            do {
                let text = try await sharedText(from: provider)
                let found = try PickupSharedTextParser().candidates(from: text)
                groups.append(found)
                for candidate in found { sources[candidate] = .sharedText }
            } catch {
                failedTextCount += 1
            }
        }
        for text in inlineTexts {
            do {
                let found = try PickupSharedTextParser().candidates(from: text)
                groups.append(found)
                for candidate in found { sources[candidate] = .sharedText }
            } catch {
                failedTextCount += 1
            }
        }
        candidates = ImagePickupBatchMerger().merge(groups)
        selectedCodes = Set(candidates.map(\.code))
        if candidates.isEmpty {
            phase = .failed
            message = "没有找到可用的取件码，请分享完整取件通知、单独的取件码或清晰截图"
        } else {
            phase = .review
        }
    }

    func save() {
        guard phase == .review else { return }
        let items = candidates.filter { selectedCodes.contains($0.code) }.map {
            PickupImageShareBatch.Item(code: $0.code, location: $0.location, platform: $0.platform,
                                      source: sources[$0] ?? .imageRecognition)
        }
        guard !items.isEmpty else { return }
        phase = .saving
        do {
            try PickupImageShareQueue.shared().enqueue(PickupImageShareBatch(items: items))
            message = "已保存 \(items.count) 个取件码，下次打开收下时自动加入待取"
            phase = .saved
        } catch {
            message = error.localizedDescription
            phase = .review
        }
    }

    func finish() { context?.completeRequest(returningItems: nil) }
    func cancel() { context?.cancelRequest(withError: CocoaError(.userCancelled)) }

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
    @ObservedObject var model: PickupShareModel

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
                            Text("找到 \(model.candidates.count) 个取件码")
                                .font(.title2.weight(.semibold))
                            if model.failedImageCount + model.failedTextCount > 0 {
                                Text("有 \(model.failedImageCount + model.failedTextCount) 项内容没有识别成功，请检查是否遗漏")
                                    .foregroundStyle(ShouxiaPalette.supportingInk)
                            }
                            ForEach(model.candidates) { candidate in
                                Toggle(isOn: Binding(
                                    get: { model.selectedCodes.contains(candidate.code) },
                                    set: { selected in
                                        if selected { model.selectedCodes.insert(candidate.code) }
                                        else { model.selectedCodes.remove(candidate.code) }
                                    }
                                )) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(candidate.code).font(.title3.bold().monospacedDigit())
                                        Text(candidate.location ?? "地点未识别")
                                            .font(.subheadline).foregroundStyle(ShouxiaPalette.supportingInk)
                                    }
                                }
                                .padding(16)
                                .background(ShouxiaPalette.paper, in: RoundedRectangle(cornerRadius: 20))
                                .accessibilityLabel("取件码 \(candidate.code)，\(candidate.location ?? "地点未识别")")
                            }
                            Text("只保存选中的取件信息，不保存原图或分享原文。下次打开收下时加入待取，地点缺失时使用当时的常用取件点。")
                                .font(.caption).foregroundStyle(ShouxiaPalette.supportingInk)
                            if !model.message.isEmpty { Text(model.message).foregroundStyle(.red) }
                            Button("保存 \(model.selectedCodes.count) 个取件码", action: model.save)
                                .buttonStyle(ShouxiaPrimaryButtonStyle())
                                .disabled(model.selectedCodes.isEmpty)
                        case .saved:
                            Image(systemName: "checkmark.circle.fill").font(.largeTitle)
                                .foregroundStyle(ShouxiaPalette.breezePressed)
                            Text(model.message)
                            Button("完成", action: model.finish).buttonStyle(ShouxiaPrimaryButtonStyle())
                        case .failed:
                            Text(model.message)
                            Button("返回", action: model.cancel).buttonStyle(ShouxiaPrimaryButtonStyle())
                        }
                    }
                    .foregroundStyle(ShouxiaPalette.ink)
                    .padding(20)
                }
            }
            .navigationTitle("收下")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.phase != .saved && model.phase != .saving {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消", action: model.cancel)
                    }
                }
            }
        }
        .tint(ShouxiaPalette.breezePressed)
        .shouxiaRoundedFont()
        .task { await model.recognize() }
    }
}
