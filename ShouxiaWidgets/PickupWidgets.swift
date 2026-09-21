import AppIntents
import SwiftUI
import WidgetKit

private func readSnapshot() throws -> PickupSurfaceSnapshot {
    guard let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: PickupSnapshotFile.appGroup
    ) else { throw PickupSnapshotFile.SnapshotError.missingAppGroup }
    return try PickupSnapshotFile.read(from: container.appendingPathComponent(PickupSnapshotFile.filename))
}

struct PickupPlace: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "取件地点")
    static let defaultQuery = PickupPlaceQuery()
    let id: String
    var locationKey: String { String(id.dropFirst("location:".count)) }
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(locationKey.isEmpty ? "地点待确认" : locationKey)")
    }
}

struct PickupPlaceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PickupPlace] {
        // Preserve deleted filters instead of silently reverting to all locations.
        identifiers.map { PickupPlace(id: $0) }
    }

    func suggestedEntities() async throws -> [PickupPlace] {
        let snapshot = try readSnapshot()
        var seen = Set<String>()
        return snapshot.items.compactMap {
            seen.insert($0.locationKey).inserted ? PickupPlace(id: "location:" + $0.locationKey) : nil
        }
    }
}

struct PickupWidgetConfiguration: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "待取包裹"
    static let description = IntentDescription("选择取件地点，以及是否显示取件码。")
    @Parameter(title: "地点（不选则显示全部）") var place: PickupPlace?
    @Parameter(title: "隐藏取件码", default: false) var hideCodes: Bool
}

struct PickupWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: PickupSurfaceSnapshot
    let placeKey: String?
    let hideCodes: Bool
}

struct PickupWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PickupWidgetEntry {
        PickupWidgetEntry(date: Date(), snapshot: .preview, placeKey: nil, hideCodes: false)
    }

    func snapshot(for configuration: PickupWidgetConfiguration, in context: Context) async -> PickupWidgetEntry {
        entry(configuration)
    }

    func timeline(for configuration: PickupWidgetConfiguration, in context: Context) async -> Timeline<PickupWidgetEntry> {
        let current = entry(configuration)
        let expiry = current.snapshot.updatedAt.addingTimeInterval(PickupSurfaceSnapshot.maximumAge)
        let expired = PickupWidgetEntry(date: expiry, snapshot: .unavailable(at: expiry),
                                       placeKey: current.placeKey, hideCodes: current.hideCodes)
        return Timeline(entries: expiry > current.date ? [current, expired] : [current],
                        policy: .after(Date().addingTimeInterval(60 * 60)))
    }

    private func entry(_ configuration: PickupWidgetConfiguration) -> PickupWidgetEntry {
        let snapshot: PickupSurfaceSnapshot
        do { snapshot = try readSnapshot() }
        catch { snapshot = .unavailable() }
        return PickupWidgetEntry(date: Date(), snapshot: snapshot,
                                 placeKey: configuration.place?.locationKey, hideCodes: configuration.hideCodes)
    }
}

struct PickupWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PickupWidgetEntry
    private var items: [PickupSurfaceSnapshot.Item] { entry.snapshot.items(at: entry.placeKey) }
    private var available: Bool { entry.snapshot.isUsable(at: entry.date) }
    private var isAccessory: Bool {
        family == .accessoryCircular || family == .accessoryInline || family == .accessoryRectangular
    }

    var body: some View {
        Group {
            if isAccessory {
                accessory
            } else if !available {
                VStack(alignment: .leading, spacing: 8) {
                    Label("暂时无法读取", systemImage: "exclamationmark.triangle")
                    Text("打开收下更新取件信息").font(.caption)
                }
            } else {
                desktop
            }
        }
        .widgetURL(PickupSurfaceLink.url(id: isAccessory || !available ? nil : items.first?.id))
        .containerBackground(for: .widget) {
            if isAccessory {
                Color.clear
            } else {
                LinearGradient(colors: [ShouxiaPalette.warmPaper, ShouxiaPalette.paper],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    @ViewBuilder private var accessory: some View {
        if !available {
            Label("待更新", systemImage: "shippingbox")
        } else if family == .accessoryCircular {
            VStack(spacing: 1) {
                Image(systemName: "shippingbox")
                Text("\(items.count)").font(.headline)
            }
            .accessibilityLabel("待取 \(items.count) 件")
        } else {
            Label("待取 \(items.count) 件", systemImage: "shippingbox")
        }
    }

    private var visibleItems: [PickupSurfaceSnapshot.Item] { Array(items.prefix(3)) }
    private var sharesVisiblePlace: Bool {
        guard let first = visibleItems.first else { return false }
        return visibleItems.allSatisfy { $0.locationKey == first.locationKey }
    }

    private var desktop: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                ShouxiaMark().frame(width: 25, height: 25)
                Text("待取").font(.caption.weight(.medium))
                    .foregroundStyle(ShouxiaPalette.supportingInk)
                Spacer(minLength: 4)
                Text("\(items.count) 件")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
            }
            if items.isEmpty {
                Spacer(minLength: 0)
                Text(entry.placeKey == nil ? "都收下了" : "此地点暂无待取")
                    .font(.headline)
                Text(entry.placeKey == nil ? "下一件到来时，再见" : "可编辑组件更换地点")
                    .font(.caption).foregroundStyle(ShouxiaPalette.supportingInk)
                Spacer(minLength: 0)
            } else if family == .systemSmall, let item = items.first {
                Spacer(minLength: 0)
                place(item)
                PickupSurfaceCode(code: item.code, hidden: entry.hideCodes, size: 28)
                Spacer(minLength: 0)
                footer(shown: 1)
            } else if sharesVisiblePlace, let item = visibleItems.first {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        place(item)
                        Spacer(minLength: 0)
                        footer(shown: visibleItems.count)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(spacing: 5) {
                        ForEach(visibleItems) { item in
                            Link(destination: PickupSurfaceLink.url(id: item.id)) {
                                codeRow(item)
                            }
                            .tint(ShouxiaPalette.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 5) {
                    ForEach(visibleItems) { item in
                        Link(destination: PickupSurfaceLink.url(id: item.id)) {
                            HStack(spacing: 10) {
                                place(item).frame(maxWidth: .infinity, alignment: .leading)
                                PickupSurfaceCode(code: item.code, hidden: entry.hideCodes, size: 20)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .tint(ShouxiaPalette.ink)
                    }
                }
                Spacer(minLength: 0)
                footer(shown: visibleItems.count)
            }
        }
        .fontDesign(.rounded)
        .foregroundStyle(ShouxiaPalette.ink)
    }

    private func codeRow(_ item: PickupSurfaceSnapshot.Item) -> some View {
        PickupSurfaceCode(code: item.code, hidden: entry.hideCodes, size: 21)
            .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(ShouxiaPalette.paper.opacity(0.9), in: RoundedRectangle(cornerRadius: 9))
    }

    private func place(_ item: PickupSurfaceSnapshot.Item) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.location)
                .font(.caption.weight(.semibold))
                .lineLimit(family == .systemMedium && sharesVisiblePlace ? 2 : 1)
            if item.usesCommonLocation {
                Text("常用地点 · 请确认")
                    .font(.system(size: 10))
                    .foregroundStyle(ShouxiaPalette.supportingInk)
            }
        }
        .privacySensitive()
    }

    private func footer(shown: Int) -> some View {
        HStack(spacing: 4) {
            Text(items.count > shown ? "还有 \(items.count - shown) 件" : "打开取件台")
            Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .semibold))
        }
        .font(.caption2)
        .foregroundStyle(ShouxiaPalette.supportingInk)
    }

}

/// Never truncate or expose a hidden code through an accessibility label.
struct PickupSurfaceCode: View {
    let code: String
    let hidden: Bool
    let size: CGFloat

    var body: some View {
        if hidden {
            Text("打开查看取件码").font(.caption)
        } else {
            ViewThatFits(in: .horizontal) {
                Text(code).font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit().fixedSize()
                Text(code).font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit().fixedSize()
                Text("长码请打开查看").font(.caption)
            }
            .privacySensitive()
        }
    }
}

struct PickupWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PickupWidget", intent: PickupWidgetConfiguration.self,
                               provider: PickupWidgetProvider()) { entry in
            PickupWidgetView(entry: entry)
        }
        .configurationDisplayName("待取包裹")
        .description("随手看待取件数和取件码；锁屏仅显示件数。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryInline, .accessoryRectangular])
    }
}

@main
struct ShouxiaWidgets: WidgetBundle {
    var body: some Widget {
        PickupWidget()
        PickupLiveActivity()
    }
}

#Preview("小号", as: .systemSmall) {
    PickupWidget()
} timeline: {
    PickupWidgetEntry(date: .now, snapshot: .preview, placeKey: nil, hideCodes: false)
}

#Preview("中号隐藏码", as: .systemMedium) {
    PickupWidget()
} timeline: {
    PickupWidgetEntry(date: .now, snapshot: .preview, placeKey: nil, hideCodes: true)
}

#Preview("锁屏件数", as: .accessoryCircular) {
    PickupWidget()
} timeline: {
    PickupWidgetEntry(date: .now, snapshot: .preview, placeKey: nil, hideCodes: false)
}

private extension PickupSurfaceSnapshot {
    static var preview: Self {
        Self(version: schemaVersion, updatedAt: .now, isAvailable: true, items: [
            Item(id: UUID(), code: "3-2-4012", location: "北门驿站", locationKey: "北门驿站", usesCommonLocation: false),
            Item(id: UUID(), code: "569012", location: "北门驿站", locationKey: "北门驿站", usesCommonLocation: true),
            Item(id: UUID(), code: "1234567890-1234567890-1234567890", location: "南门快递柜", locationKey: "南门快递柜", usesCommonLocation: false)
        ])
    }
}
