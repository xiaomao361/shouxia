import SwiftUI
import UIKit

struct AutomationSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("automationSetupCardHidden") private var automationSetupCardHidden = false

    private let shortcutURL = URL(
        string: "https://www.icloud.com/shortcuts/cd785f47a8244d32b1cf3c7c6f4dad8a"
    )

    private let flow = SMSAutomationFlow.current
    private var usesInlineAutomation: Bool { flow == .inlineAutomation }
    private var introduction: String { flow.introduction }

    private var troubleshooting: String {
        usesInlineAutomation
            ? "1. 启用“信息”触发器。\n2. 短信中包含“取件”。\n3. “获取文本”的输入选“快捷指令输入”。\n4. “保存取件短信”的“短信内容”选上一步的“文本”。\n仅锁屏时不运行：在快捷指令的“信息”按钮 →“隐私”中检查锁定时运行权限。"
            : "1. 启用自动化，\(flow.requiresConfirmation ? "收到短信后确认运行" : "选择“立即运行”")。\n2. 短信中包含“取件”。\n3. 运行的是“收下自动收码”。\n4. “获取文本”的输入选“快捷指令输入”，“保存取件短信”的“短信内容”选该文本。"
    }

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
                            Text("短信自动收码")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(ShouxiaPalette.ink)

                            Text(introduction)
                            .font(.subheadline)
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("第一步")
                                .font(.caption2.weight(.bold))
                                .tracking(1.2)
                                .foregroundStyle(ShouxiaPalette.apricot)

                            Text("添加快捷指令")
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
                            .accessibilityHint("打开 iCloud 页面后，确认添加快捷指令")

                            Text("从 iCloud 添加。已能自动收码的用户无需重设。")
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

                        if usesInlineAutomation {
                            AutomationSetupSection(
                                eyebrow: "第二步",
                                title: "设置收到短信时运行",
                                steps: [
                                    AutomationSetupStepContent(
                                        title: "添加“信息”触发器",
                                        detail: "编辑“收下自动收码”，在“自动化”中选“信息”。已有信息卡片可跳过。"
                                    ),
                                    AutomationSetupStepContent(
                                        title: "设置“信息包含取件”",
                                        detail: "设为“信息”“包含”“取件”，发件人不限。"
                                    ),
                                    AutomationSetupStepContent(
                                        title: "检查两个操作",
                                        detail: "信息卡片下方保留：获取输入文本 → 保存取件短信“文本”。"
                                    ),
                                ]
                            )
                        } else {
                            AutomationSetupSection(
                                eyebrow: "第二步",
                                title: "新建短信自动化",
                                steps: [
                                    AutomationSetupStepContent(
                                        title: "选择“信息”",
                                        detail: "在快捷指令中点“自动化”→“+”→“信息”，发件人不限。"
                                    ),
                                    AutomationSetupStepContent(
                                        title: "设置短信条件",
                                        detail: flow.requiresConfirmation
                                            ? "“信息包含”填“取件”。此系统收到短信后需要确认运行。"
                                            : "“信息包含”填“取件”，选择“立即运行”。"
                                    ),
                                    AutomationSetupStepContent(
                                        title: "选择“收下自动收码”",
                                        detail: "添加“运行快捷指令”，选“收下自动收码”并保存。"
                                    ),
                                ]
                            )
                        }

                        VStack(spacing: 12) {
                            Button {
                                guard let url = URL(string: "shortcuts://") else { return }
                                openURL(url)
                            } label: {
                                Label("打开快捷指令", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(ShouxiaPrimaryButtonStyle())
                            .accessibilityHint(usesInlineAutomation
                                ? "打开后，编辑收下自动收码并检查信息触发器"
                                : "打开后，请点底部的自动化")

                            Label(
                                flow.verification,
                                systemImage: "hourglass"
                            )
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                        }

                        DisclosureGroup("链接打不开？手动创建") {
                            AutomationSetupSection(
                                eyebrow: "链接打不开时",
                                title: "也可以手动创建",
                                steps: [
                                    AutomationSetupStepContent(
                                        title: "新建“收下自动收码”",
                                        detail: "新建快捷指令，命名为“收下自动收码”。"
                                    ),
                                    AutomationSetupStepContent(
                                        title: "获取短信文字",
                                        detail: "添加“获取文本”，输入选“快捷指令输入”。"
                                    ),
                                    AutomationSetupStepContent(
                                        title: "保存到收下",
                                        detail: "添加“保存取件短信”，“短信内容”选上一步的“文本”，然后保存。"
                                    ),
                                ]
                            )
                        }
                        .font(.subheadline)
                        .padding(16)
                        .background(ShouxiaPalette.paper, in: RoundedRectangle(cornerRadius: 22))

                        DisclosureGroup(flow.requiresConfirmation ? "确认后没有添加？" : "没有自动添加？") {
                            Text(troubleshooting)
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

                        Text("适用于苹果“信息”App 中的短信和 iMessage。收下不会读取短信历史或其他 App 通知。")
                            .font(.caption)
                            .foregroundStyle(ShouxiaPalette.softInk)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.horizontal, 12)

                        Button {
                            automationSetupCardHidden = true
                            dismiss()
                        } label: {
                            Text("隐藏首页入口")
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
        .shouxiaRoundedFont()
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
