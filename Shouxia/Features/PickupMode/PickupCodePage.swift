import SwiftUI

struct PickupCodePage: View {
    let record: PickupRecord
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)

            Button(action: onEdit) {
                VStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Text(record.locationDisplayName)
                            .font(.title2.weight(.semibold))
                            .fontDesign(.rounded)
                            .foregroundStyle(ShouxiaPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)

                        Image(systemName: "pencil.circle")
                            .font(.subheadline)
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                    }

                    if let platform = record.platform {
                        Text(platform)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(ShouxiaPalette.skyWash, in: Capsule())
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

                Text(record.code)
                    .font(.system(size: 78, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .tracking(1.2)
                    .foregroundStyle(ShouxiaPalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.34)
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
        .shadow(color: ShouxiaPalette.ink.opacity(0.08), radius: 26, y: 12)
        .padding(.vertical, 24)
        .accessibilityElement(children: .contain)
    }
}
