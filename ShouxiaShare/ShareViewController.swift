import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ImageIO

@MainActor
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let model = ImageShareModel(context: extensionContext)
        let host = UIHostingController(rootView: ImageShareView(model: model))
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
final class ImageShareModel: ObservableObject {
    enum Phase { case loading, review, saving, saved, failed }
    @Published var phase: Phase = .loading
    @Published var candidates: [ImagePickupCandidate] = []
    @Published var selectedCodes: Set<String> = []
    @Published var message = ""
    @Published var failedImageCount = 0
    private let context: NSExtensionContext?

    init(context: NSExtensionContext?) { self.context = context }

    func recognize() async {
        guard phase == .loading else { return }
        let items = context?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
        guard !providers.isEmpty else {
            phase = .failed
            message = "没有收到图片，请从图片的系统分享菜单选择收下"
            return
        }
        guard providers.count <= 5 else {
            phase = .failed
            message = PickupImageShareError.tooManyImages.localizedDescription
            return
        }
        var groups: [[ImagePickupCandidate]] = []
        for provider in providers {
            guard !Task.isCancelled else { return }
            do {
                let data = try await imageData(from: provider)
                let thumbnail = try await Self.downsample(data)
                let lines = try await ImageTextRecognizer().recognize(in: thumbnail)
                groups.append(try ImagePickupExtractor().candidates(from: lines))
            } catch {
                failedImageCount += 1
            }
        }
        candidates = ImagePickupBatchMerger().merge(groups)
        selectedCodes = Set(candidates.map(\.code))
        if candidates.isEmpty {
            phase = .failed
            message = "没有识别到可用的取件码，请换一张清晰截图，或在收下里粘贴取件文字"
        } else {
            phase = .review
        }
    }

    func save() {
        guard phase == .review else { return }
        let items = candidates.filter { selectedCodes.contains($0.code) }.map {
            PickupImageShareBatch.Item(code: $0.code, location: $0.location, platform: $0.platform)
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

private struct ImageShareView: View {
    @ObservedObject var model: ImageShareModel

    var body: some View {
        NavigationStack {
            ZStack {
                ShouxiaBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        switch model.phase {
                        case .loading, .saving:
                            ProgressView(model.phase == .loading ? "正在识别取件码" : "正在保存")
                                .padding(.top, 36)
                        case .review:
                            Text("找到 \(model.candidates.count) 个取件码")
                                .font(.title2.weight(.semibold))
                            if model.failedImageCount > 0 {
                                Text("有 \(model.failedImageCount) 张图片没有识别成功，请检查是否遗漏")
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
                            Text("只保存选中的取件信息，不保存原图。下次打开收下时加入待取，地点缺失时使用当时的常用取件点。")
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
