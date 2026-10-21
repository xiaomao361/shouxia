import AVKit
import Combine
import SwiftUI

enum AutomationTutorial: String, Identifiable {
    case smsTrigger = "sms-trigger-ios27"
    case manualCreation = "manual-creation-ios27"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smsTrigger: "看操作演示"
        case .manualCreation: "看完整创建演示"
        }
    }

    var detail: String {
        switch self {
        case .smsTrigger: "约 10 秒 · 离线可看"
        case .manualCreation: "约 28 秒 · 离线可看"
        }
    }

    var playerTitle: String {
        switch self {
        case .smsTrigger: "设置短信触发条件"
        case .manualCreation: "手动创建快捷指令"
        }
    }

    func resourceURL(extension fileExtension: String, in bundle: Bundle = .main) -> URL? {
        bundle.url(
            forResource: rawValue, withExtension: fileExtension, subdirectory: "Tutorials"
        )
    }
}

struct AutomationTutorialCard: View {
    let tutorial: AutomationTutorial
    var play: () -> Void

    var body: some View {
        Button(action: play) {
            HStack(spacing: 14) {
                ZStack {
                    if let url = tutorial.resourceURL(extension: "jpg"),
                       let poster = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: poster)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ShouxiaPalette.skyWash
                    }
                }
                .frame(width: 72, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ShouxiaPalette.ink)
                        .offset(x: 1)
                        .frame(width: 36, height: 36)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(tutorial.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(ShouxiaPalette.ink)
                    Text(tutorial.detail)
                        .font(.caption)
                        .foregroundStyle(ShouxiaPalette.mutedInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShouxiaPalette.softInk)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .background(
                ShouxiaPalette.skyWash.opacity(0.46),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tutorial.title)，\(tutorial.detail)")
        .accessibilityHint("在应用内全屏播放，可暂停、拖动和重播")
    }
}

@MainActor
final class AutomationTutorialPlayback: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var failure: String?

    private let tutorial: AutomationTutorial
    private let bundle: Bundle
    private var prepared = false
    private var statusObservation: NSKeyValueObservation?
    private var failureObservation: AnyCancellable?
    private var loadID = UUID()

    init(tutorial: AutomationTutorial, bundle: Bundle = .main) {
        self.tutorial = tutorial
        self.bundle = bundle
        player.isMuted = true
        player.allowsExternalPlayback = false
        player.actionAtItemEnd = .pause
    }

    func play() {
        if !prepared { prepare() }
        guard failure == nil else { return }
        player.play()
    }

    func pause() { player.pause() }

    func replay() {
        if failure != nil { prepare() }
        guard failure == nil else { return }
        player.seek(to: .zero)
        play()
    }

    private func prepare() {
        player.pause()
        loadID = UUID()
        let currentLoadID = loadID
        statusObservation = nil
        failureObservation = nil
        failure = nil
        guard let url = tutorial.resourceURL(extension: "mp4", in: bundle) else {
            failure = "教学视频未能加载。可以返回查看文字步骤。"
            return
        }
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        prepared = true
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in
                guard self?.loadID == currentLoadID else { return }
                self?.showPlaybackFailure()
            }
        }
        failureObservation = NotificationCenter.default.publisher(
            for: .AVPlayerItemFailedToPlayToEndTime, object: item
        ).sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard self?.loadID == currentLoadID else { return }
                self?.showPlaybackFailure()
            }
        }
    }

    private func showPlaybackFailure() {
        player.pause()
        failure = "视频暂时无法播放。请重试，或返回查看文字步骤。"
    }

}

struct AutomationTutorialPlayerView: View {
    let tutorial: AutomationTutorial
    @ObservedObject var playback: AutomationTutorialPlayback
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            ShouxiaBackground()

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(ShouxiaPalette.paper.opacity(0.94), in: Circle())
                    }
                    .accessibilityLabel("关闭教程")

                    Text(tutorial.playerTitle)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Button { playback.replay() } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(ShouxiaPalette.paper.opacity(0.94), in: Circle())
                    }
                    .accessibilityLabel("重播教程")
                }
                .buttonStyle(.plain)
                .foregroundStyle(ShouxiaPalette.ink)
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if let failure = playback.failure {
                    VStack(spacing: 18) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(ShouxiaPalette.warningInk)
                            .accessibilityHidden(true)
                        Text(failure)
                            .multilineTextAlignment(.center)
                        Button("重试播放") { playback.replay() }
                            .buttonStyle(ShouxiaPrimaryButtonStyle())
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(ShouxiaPalette.ink)
                } else {
                    GeometryReader { proxy in
                        // Both bundled videos are 9:16. Match the actual video
                        // bounds so rounded corners don't reveal letterboxing.
                        let width = max(0, min(proxy.size.width, proxy.size.height * 9 / 16))
                        AutomationTutorialNativePlayer(player: playback.player)
                            .frame(width: width, height: width * 16 / 9)
                            .background(ShouxiaPalette.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
                            }
                            .shadow(color: ShouxiaPalette.shadow.opacity(0.08), radius: 18, y: 8)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.horizontal, 20)
                }

                Text("切换到快捷指令时暂停，返回后可继续播放。")
                    .font(.caption)
                    .foregroundStyle(ShouxiaPalette.mutedInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }
        }
        .tint(ShouxiaPalette.accentInk)
        .shouxiaRoundedFont()
        .onAppear { playback.play() }
        .onDisappear { playback.pause() }
        .onChange(of: scenePhase) { phase in
            if phase != .active { playback.pause() }
        }
    }
}

private struct AutomationTutorialNativePlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = false
        controller.view.backgroundColor = .clear
        controller.view.clipsToBounds = true
        controller.view.layer.cornerCurve = .continuous
        controller.view.layer.cornerRadius = 28
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {}

    static func dismantleUIViewController(_ controller: AVPlayerViewController, coordinator: ()) {
        controller.player?.pause()
        controller.player = nil
    }
}
