import SwiftUI

struct PickupCodePage: View {
    let record: PickupRecord
    let onEdit: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var largeCodeSize: CGFloat = 78
    @ScaledMetric(relativeTo: .title) private var compactCodeSize: CGFloat = 44

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content.frame(minHeight: proxy.size.height)
            }
        }
        .background(
            ShouxiaPalette.paper.opacity(0.96),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(ShouxiaPalette.accent(for: record))
                .frame(width: 10, height: 10)
                .padding(24)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
        }
        .shadow(color: ShouxiaPalette.shadow.opacity(0.08), radius: 26, y: 12)
        .padding(.vertical, 24)
        .accessibilityElement(children: .contain)
    }
    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)

            Button(action: onEdit) {
                VStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Text(record.locationDisplayName)
                            .font(.title2.weight(.semibold))
                            .shouxiaRoundedFont()
                            .foregroundStyle(ShouxiaPalette.ink)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Image(systemName: "pencil.circle")
                            .font(.subheadline)
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                    }

                    if let platform = record.platform {
                        ShouxiaBrandBadge(brand: PickupDirectory.displayLabel(for: platform))
                    }

                    if record.locationSource == .commonDefault {
                        Label("来自常用取件点", systemImage: "house")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("取件地点，\(record.locationDisplayName)")
            .accessibilityHint("双击更正取件码或地点")

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Text("取件码")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ShouxiaPalette.mutedInk)

                ViewThatFits(in: .horizontal) {
                    Text(record.code)
                        .font(.system(size: largeCodeSize, weight: .bold, design: .rounded))
                        .fixedSize()
                    Text(record.code)
                        .font(.system(size: compactCodeSize, weight: .bold, design: .rounded))
                        .fixedSize()
                    Text(record.code)
                        .font(.title.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .monospacedDigit()
                .multilineTextAlignment(.center)
                .foregroundStyle(ShouxiaPalette.ink)
                .textSelection(.enabled)
                .accessibilityLabel("取件码 \(record.code)")

            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 24)

            Label("请核对地点后出示", systemImage: "shippingbox")
                .font(.caption.weight(.medium))
                .foregroundStyle(ShouxiaPalette.supportingInk)

            Spacer(minLength: 30)
        }
        .padding(.horizontal, 24)
    }

}
