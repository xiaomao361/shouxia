import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct PickupLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PickupActivityAttributes.self) { context in
            PickupLockScreenActivityView(context: context)
                .widgetURL(PickupSurfaceLink.url(id: context.state.recordID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    PickupActivityView(context: context)
                }
            } compactLeading: {
                if context.pickupIsStale || context.state.ended {
                    Image(systemName: context.pickupIsStale ? "clock" : "checkmark")
                } else {
                    Text("\(context.state.remainingCount)件").font(.caption2.weight(.semibold))
                }
            } compactTrailing: {
                if context.pickupIsStale || context.state.ended {
                    Text(context.pickupIsStale ? "待更新" : "结束").font(.caption2)
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
                Image(systemName: context.pickupIsStale ? "clock" : context.state.ended ? "checkmark" : "shippingbox.fill")
            }
            .widgetURL(PickupSurfaceLink.url(id: context.state.recordID))
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct PickupLockScreenActivityView: View {
    let context: ActivityViewContext<PickupActivityAttributes>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    private var usesDarkAppearance: Bool {
        if isLuminanceReduced { return true }
        if let appearance = context.state.appearance { return appearance == .dark }
        return colorScheme == .dark
    }

    // Use concrete colors: dynamic colors can resolve against the host's wallpaper theme.
    private var background: Color {
        usesDarkAppearance
            ? Color(red: 0.10, green: 0.14, blue: 0.16)
            : Color(red: 0.96, green: 0.97, blue: 0.98)
    }
    private var ink: Color {
        usesDarkAppearance ? .white : Color(red: 0.149, green: 0.216, blue: 0.275)
    }

    var body: some View {
        PickupActivityView(context: context, ink: ink, secondaryInk: ink.opacity(0.72))
            .padding(16)
            .background(background)
            .activityBackgroundTint(background)
            .activitySystemActionForegroundColor(ink)
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct PickupActivityView: View {
    let context: ActivityViewContext<PickupActivityAttributes>
    var ink: Color = .white
    var secondaryInk: Color = .white.opacity(0.75)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if context.state.ended {
                Label("待取展示已结束", systemImage: "checkmark.circle")
            } else if context.pickupIsStale {
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
        .shouxiaRoundedFont()
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 17.0, *)
#Preview("待取信息", as: .content, using: PickupActivityAttributes(sessionID: UUID(), expiresAt: .now.addingTimeInterval(8 * 3600))) {
    PickupLiveActivity()
} contentStates: {
    PickupActivityContent(recordID: UUID(), code: "5-5-2210", location: "北门驿站", usesCommonLocation: false, remainingCount: 5, ended: false)
    PickupActivityContent.finished
}

@available(iOSApplicationExtension 16.1, *)
private extension ActivityViewContext where Attributes == PickupActivityAttributes {
    var pickupIsStale: Bool {
        if #available(iOSApplicationExtension 16.2, *) { return isStale }
        return Date() >= attributes.expiresAt
    }
}
