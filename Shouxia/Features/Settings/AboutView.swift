import SwiftUI
import UIKit
import ActivityKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ImportPreferencesView()
                    } label: {
                        Label("导入设置", systemImage: "shippingbox.and.arrow.backward")
                    }
                    NavigationLink {
                        if #available(iOS 16.1, *) {
                            PickupActivityPreferencesView()
                        } else {
                            Text("锁屏与灵动岛展示需要 iOS 16.1 或更高版本。")
                                .padding().navigationTitle("锁屏与灵动岛")
                        }
                    } label: {
                        Label("锁屏与灵动岛", systemImage: "lock.iphone")
                    }
                }
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("隐私与关于", systemImage: "info.circle")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ShouxiaBackground())
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .tint(ShouxiaPalette.breezePressed)
        .shouxiaRoundedFont()
    }
}

struct AboutView: View {
    @AppStorage("automaticClipboardImportEnabled") private var automaticClipboardImportEnabled = false

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
                            detail: "记录只保存在本机，不上传服务器。"
                        )
                        PrivacyDivider()
                        PrivacyRow(
                            icon: "doc.on.clipboard",
                            title: automaticClipboardImportEnabled
                                ? "已开启剪贴板识别"
                                : "由你主动粘贴",
                            detail: automaticClipboardImportEnabled
                                ? "打开时识别新复制的取件信息。无关文字不保存。"
                                : "点击粘贴后才读取剪贴板。"
                        )
                        PrivacyDivider()
                        PrivacyRow(
                            icon: "photo",
                            title: "图片只在本机识别",
                            detail: "不保存原图、手机号、运单号或商品信息。"
                        )
                        PrivacyDivider()
                        PrivacyRow(
                            icon: "message",
                            title: "不读取短信历史",
                            detail: "只处理你导入的文字或快捷指令传来的短信，不读取其他 App 通知。"
                        )
                        PrivacyDivider()
                        PrivacyRow(
                            icon: "person.2",
                            title: "分享由你决定",
                            detail: "只分享所选取件码、地点和平台，不含短信原文。"
                        )
                        PrivacyDivider()
                        PrivacyRow(
                            icon: "person.crop.circle.badge.xmark",
                            title: "不跟踪、不建账号",
                            detail: "无广告、统计跟踪、账号或云同步。"
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

                    Text("可在“收下记录”中永久删除。删除后仅保留不含原文的标记，防止剪贴板重复导入。")
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
        .tint(ShouxiaPalette.mutedInk)
        .shouxiaRoundedFont()
    }

}


@available(iOS 16.1, *)
private struct PickupActivityPreferencesView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var isAllowed = ActivityAuthorizationInfo().areActivitiesEnabled
    @ObservedObject private var activity = PickupLiveActivityController.shared

    var body: some View {
        Form {
            Section {
                Toggle("在锁屏和灵动岛显示待取", isOn: Binding(
                    get: { activity.isEnabled },
                    set: { activity.setEnabled($0) }
                ))
                if let message = activity.message {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            } footer: {
                Text("有待取就展示，取完自动收起。关闭不影响待取记录。")
            }
            Section {
                LabeledContent("系统实时活动权限", value: isAllowed ? "已允许" : "未允许")
                Button("前往系统设置") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                }
            } footer: {
                Text(isAllowed ? "取件码会显示在锁屏和灵动岛上。" : "请在收下的系统设置中开启实时活动。")
            }
            Section {
                Text("每次最多显示 8 小时。到期或被移除后，打开收下即可恢复（需保持开关开启）。")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("开始新的展示需要打开 App。")
                    .font(.subheadline).foregroundStyle(.secondary)
            } header: {
                Text("为什么不显示了？")
            }
        }
        .navigationTitle("锁屏与灵动岛")
        .navigationBarTitleDisplayMode(.inline)
        .tint(ShouxiaPalette.breezePressed)
        .onAppear { isAllowed = ActivityAuthorizationInfo().areActivitiesEnabled }
        .onChange(of: scenePhase) { phase in
            if phase == .active { isAllowed = ActivityAuthorizationInfo().areActivitiesEnabled }
        }
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
