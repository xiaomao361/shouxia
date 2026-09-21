import ActivityKit
import SwiftUI
import WidgetKit

struct PickupLiveActivity: Widget {
    private let cream = Color(red: 1, green: 0.956, blue: 0.925)
    private let ink = Color(red: 0.149, green: 0.216, blue: 0.275)

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PickupActivityAttributes.self) { context in
            PickupActivityView(context: context, onLockScreen: true)
                .padding(16)
                .background(LinearGradient(colors: [cream, Color(red: 1, green: 0.992, blue: 0.988)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                .activityBackgroundTint(cream)
                .activitySystemActionForegroundColor(ink)
                .widgetURL(PickupSurfaceLink.url(id: context.state.recordID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PickupActivityView(context: context, onLockScreen: false)
                }
            } compactLeading: {
                if context.isStale || context.state.ended {
                    Image(systemName: context.isStale ? "clock" : "checkmark")
                } else {
                    Text("\(context.state.remainingCount)件").font(.caption2.weight(.semibold))
                }
            } compactTrailing: {
                if context.isStale || context.state.ended {
                    Text(context.isStale ? "待更新" : "结束").font(.caption2)
                } else if let code = context.state.code {
                    ViewThatFits(in: .horizontal) {
                        Text(code).font(.system(size: 13, weight: .semibold, design: .rounded))
                            .monospacedDigit().fixedSize()
                        Text("长按看码").font(.system(size: 10)).fixedSize()
                    }
                    .foregroundStyle(Color(red: 1, green: 0.76, blue: 0.6))
                    .privacySensitive()
                }
            } minimal: {
                Image(systemName: context.isStale ? "clock" : context.state.ended ? "checkmark" : "shippingbox.fill")
            }
            .widgetURL(PickupSurfaceLink.url(id: context.state.recordID))
            .keylineTint(Color(red: 0.95, green: 0.63, blue: 0.49))
        }
    }
}

private struct PickupActivityView: View {
    let context: ActivityViewContext<PickupActivityAttributes>
    let onLockScreen: Bool
    private var ink: Color { onLockScreen ? Color(red: 0.149, green: 0.216, blue: 0.275) : .white }
    private var secondaryInk: Color { onLockScreen ? Color(red: 0.36, green: 0.43, blue: 0.47) : .white.opacity(0.75) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if context.state.ended {
                Label("待取展示已结束", systemImage: "checkmark.circle")
            } else if context.isStale {
                Label("打开收下更新待取信息", systemImage: "clock")
            } else {
                HStack {
                    Label("待取 \(context.state.remainingCount) 件", systemImage: "shippingbox.fill")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 8)
                    Text("收下").font(.caption).foregroundStyle(secondaryInk)
                }
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.state.location).font(.caption.weight(.medium)).lineLimit(2)
                        if context.state.usesCommonLocation {
                            Text("常用地点 · 请确认").font(.system(size: 10)).foregroundStyle(secondaryInk)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .privacySensitive()
                    PickupSurfaceCode(code: context.state.code ?? "", hidden: false, size: 32)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("待取信息", as: .content, using: PickupActivityAttributes(sessionID: UUID(), expiresAt: .now.addingTimeInterval(8 * 3600))) {
    PickupLiveActivity()
} contentStates: {
    PickupActivityContent(recordID: UUID(), code: "5-5-2210", location: "北门驿站", usesCommonLocation: false, remainingCount: 5, ended: false)
    PickupActivityContent.finished
}
