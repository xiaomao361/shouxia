import SwiftUI

struct PickupCard: View {
    let record: PickupRecord
    let isCompleting: Bool
    let onOpen: () -> Void
    let onComplete: () -> Void
    @ScaledMetric(relativeTo: .title) private var codeSize: CGFloat = 36

    var body: some View {
        Button(action: onOpen) {
            card
        }
        .buttonStyle(.plain)
        .offset(y: isCompleting ? 10 : 0)
        .scaleEffect(isCompleting ? 0.98 : 1)
        .opacity(isCompleting ? 0 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点放大取件码，右滑标记已取到")
        .accessibilityAction(named: "已取到", onComplete)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                ShouxiaLocationHeader(location: record.locationDisplayName, brand: record.platform.map { PickupDirectory.displayLabel(for: $0) })
                if record.locationSource == .commonDefault {
                    Label("常用取件点", systemImage: "house")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(ShouxiaPalette.mutedInk)
                }
            }

            ViewThatFits(in: .horizontal) {
                Text(record.code)
                    .font(.system(size: codeSize, weight: .bold, design: .rounded))
                    .monospacedDigit().fixedSize()
                Text(record.code)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(ShouxiaPalette.ink)
            .accessibilityLabel("取件码 \(record.code)")

            ViewThatFits(in: .horizontal) {
                HStack { footerContents }.fixedSize()
                VStack(alignment: .leading, spacing: 6) { footerContents }
            }
            .font(.caption)
            .foregroundStyle(ShouxiaPalette.supportingInk)

        }
        .padding(.vertical, 19)
        .padding(.leading, 39)
        .padding(.trailing, 19)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
        .background(
            ShouxiaPalette.paper,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(ShouxiaPalette.accent(for: record))
                .frame(width: 7, height: 7)
                .padding(.leading, 18)
                .padding(.top, 22)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ShouxiaPalette.line, lineWidth: 1)
        }
        .shadow(
            color: ShouxiaPalette.shadow.opacity(isCompleting ? 0.02 : 0.07),
            radius: isCompleting ? 10 : 18,
            y: isCompleting ? 4 : 9
        )
    }
    @ViewBuilder private var footerContents: some View {
        Label { Text(record.createdAt, style: .relative) } icon: { Image(systemName: "clock") }
        Label("大字查看", systemImage: "rectangle.expand.vertical")
    }

}
