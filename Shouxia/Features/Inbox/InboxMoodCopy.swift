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
                    subtitle: "自己的自动收，别人托的随手收。"
                )
                : InboxMoodCopy(
                    title: "有 \(pendingCount) 个包裹等你去取",
                    subtitle: "自己的自动收，别人托的随手收。"
                )
        }

        let choices = pendingCount == 0
            ? emptyChoices
            : pendingChoices(count: pendingCount)
        let alternatives = choices.filter { $0 != current }
        return (alternatives.isEmpty ? choices : alternatives).randomElement()
            ?? InboxMoodCopy(
                title: "你要取的，都在这里",
                subtitle: "自己的自动收，别人托的随手收。"
            )
    }

    private static let emptyChoices = [
        InboxMoodCopy(
            title: "你要取的，都在这里",
            subtitle: "自己的自动收，别人托的随手收。"
        ),
        InboxMoodCopy(
            title: "暂时没有要取的",
            subtitle: "有人托你取快递时，把文字或截图交给收下。"
        ),
        InboxMoodCopy(
            title: "今天不用翻消息",
            subtitle: "自己的短信可以自动进来，别人发来的也能随手收好。"
        ),
        InboxMoodCopy(
            title: "该取的都取完了",
            subtitle: "下次收到取件文字或截图，再交给收下。"
        ),
    ]

    private static func pendingChoices(count: Int) -> [InboxMoodCopy] {
        [
            InboxMoodCopy(
                title: "有 \(count) 个包裹等你去取",
                subtitle: "自己的和别人托的，取件码都放好了。"
            ),
            InboxMoodCopy(
                title: "今天要带回 \(count) 件",
                subtitle: "到驿站时，轻点卡片就能大字查看。"
            ),
            InboxMoodCopy(
                title: "\(count) 个包裹，慢慢拿",
                subtitle: "不用翻短信，取件码都在这里。"
            ),
            InboxMoodCopy(
                title: "顺路收下 \(count) 个包裹",
                subtitle: "到了地方再打开，也来得及。"
            ),
        ]
    }
}
