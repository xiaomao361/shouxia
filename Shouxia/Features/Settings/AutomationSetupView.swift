import SwiftUI
import UIKit

struct AutomationSetupView: View {
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
