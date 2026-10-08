import Foundation

struct InboxMoodCopy: Equatable {
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
                    subtitle: "粘贴取件信息，或选择截图。"
                )
                : InboxMoodCopy(
                    title: "待取 \(pendingCount) 件",
                    subtitle: "粘贴取件信息，或选择截图。"
                )
        }

        let choices = pendingCount == 0
            ? emptyChoices
            : pendingChoices(count: pendingCount)
        let alternatives = choices.filter { $0 != current }
        return (alternatives.isEmpty ? choices : alternatives).randomElement()
            ?? InboxMoodCopy(
                title: "你要取的，都在这里",
                subtitle: "粘贴取件信息，或选择截图。"
            )
    }

    private static let emptyChoices = [
        InboxMoodCopy(
            title: "你要取的，都在这里",
            subtitle: "粘贴取件信息，或选择截图。"
        ),
        InboxMoodCopy(
            title: "暂时没有要取的",
            subtitle: "也可以添加别人发来的取件信息。"
        ),
        InboxMoodCopy(
            title: "取件码，集中放好",
            subtitle: "设置短信自动收码后，新取件短信会自动添加。"
        ),
        InboxMoodCopy(
            title: "暂时没有待取包裹",
            subtitle: "收到取件信息后，在这里添加。"
        ),
    ]

    private static func pendingChoices(count: Int) -> [InboxMoodCopy] {
        [
            InboxMoodCopy(
                title: "待取 \(count) 件",
                subtitle: "点开卡片，放大取件码。"
            ),
            InboxMoodCopy(
                title: "有 \(count) 件待取",
                subtitle: "点开卡片，放大取件码。"
            ),
            InboxMoodCopy(
                title: "还有 \(count) 件待取",
                subtitle: "取到后右滑卡片，标记完成。"
            ),
            InboxMoodCopy(
                title: "\(count) 件包裹待取",
                subtitle: "取到后右滑卡片，标记完成。"
            ),
        ]
    }
}
