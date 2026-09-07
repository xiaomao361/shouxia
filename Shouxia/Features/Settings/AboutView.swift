import SwiftUI
import UIKit

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("automationSetupCardHidden") private var automationSetupCardHidden = false
    @AppStorage("automaticClipboardImportEnabled") private var automaticClipboardImportEnabled = false
    @AppStorage("commonPickupLocation") private var commonPickupLocation = ""

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

                        NavigationLink {
                            ImportPreferencesView()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "shippingbox.and.arrow.backward")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(ShouxiaPalette.ink)
                                    .frame(width: 42, height: 42)
                                    .background(ShouxiaPalette.warmPaper, in: Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("导入设置")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(ShouxiaPalette.ink)
                                    Text(importPreferencesSummary)
                                        .font(.caption)
                                        .foregroundStyle(ShouxiaPalette.mutedInk)
                                        .lineLimit(2)
                                }

                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(ShouxiaPalette.softInk)
                            }
                            .padding(14)
                            .background(
                                ShouxiaPalette.paper.opacity(0.94),
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("设置常用取件点和打开时剪贴板识别")

                        VStack(alignment: .leading, spacing: 0) {
                            PrivacyRow(
                                icon: "iphone",
                                title: "只在本机处理",
                                detail: "取件通知、取件码、地点和历史记录只保存在你的设备上，不会发送到开发者服务器。"
                            )
                            PrivacyDivider()
                            PrivacyRow(
                                icon: "doc.on.clipboard",
                                title: automaticClipboardImportEnabled
                                    ? "剪贴板自动识别由你开启"
                                    : "由你主动粘贴",
                                detail: automaticClipboardImportEnabled
                                    ? "打开收下时只检查发生变化的剪贴板内容；识别和筛选都在本机完成，无关文字不会保存。iOS 可能询问是否允许粘贴。"
                                    : "只有点击系统粘贴按钮后，收下才会读取当前剪贴板内容。"
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

                        Text("你可以在“收下记录”中归档内容，并在归档页永久删除。删除后无法恢复；为避免同一剪贴板内容再次自动出现，本机会保留不可读的阻止标记。")
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

    private var importPreferencesSummary: String {
        let location = commonPickupLocation
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch (location.isEmpty, automaticClipboardImportEnabled) {
        case (false, true):
            return "常用地点：\(location) · 自动识别剪贴板"
        case (false, false):
            return "常用地点：\(location)"
        case (true, true):
            return "已开启自动识别剪贴板"
        case (true, false):
            return "设置常用取件点和剪贴板识别"
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
