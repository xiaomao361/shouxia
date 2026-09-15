import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ShouxiaLiveActivityBundle: WidgetBundle {
    var body: some Widget { PickupLiveActivity() }
}

struct PickupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PickupActivityAttributes.self) { context in
            AdaptivePickupActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PickupActivityContent(context: context, compact: false)
                }
            } compactLeading: {
                Image(systemName: "shippingbox")
            } compactTrailing: {
                // A long code must not become a misleading clipped code.
                Text(context.isStale ? "待更新" : "\(context.state.remainingCount)件")
            } minimal: {
                Image(systemName: context.isStale ? "clock" : "shippingbox")
            }
        }
        .supplementalActivityFamilies([.small])
    }
}

private struct AdaptivePickupActivityView: View {
    @Environment(\.activityFamily) private var family
    let context: ActivityViewContext<PickupActivityAttributes>

    var body: some View {
        PickupActivityContent(context: context, compact: family == .small)
    }
}

private struct PickupActivityContent: View {
    let context: ActivityViewContext<PickupActivityAttributes>
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            if context.isStale {
                Label("取件信息待更新", systemImage: "clock")
                    .font(.headline)
                Text("请打开手机确认")
                    .font(.caption)
            } else {
                Text(context.state.location)
                    .font(compact ? .caption : .subheadline)
                    .lineLimit(1)
                    .privacySensitive()
                ViewThatFits(in: .horizontal) {
                    Text(context.state.code)
                        .font(.system(size: compact ? 30 : 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .fixedSize()
                    // Do not shrink a 40-character code into unreadable watch text.
                    Text("长码请在手机查看")
                        .font(.headline)
                }
                .privacySensitive()
                .accessibilityLabel("取件码 \(context.state.code)")
                Text(context.state.usesCommonLocation
                     ? "常用地点，请确认 · 本组剩\(context.state.remainingCount)件"
                     : "本组剩\(context.state.remainingCount)件 · 请核对地点")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 10 : 16)
    }
}

#Preview("取件中", as: .content, using: PickupActivityAttributes(sessionID: UUID())) {
    PickupLiveActivity()
} contentStates: {
    PickupActivityAttributes.ContentState(code: "3-2-4012", location: "北门驿站", usesCommonLocation: false, remainingCount: 3)
    PickupActivityAttributes.ContentState(code: "1234567890-1234567890-1234567890", location: "地点待确认", usesCommonLocation: false, remainingCount: 1)
}
