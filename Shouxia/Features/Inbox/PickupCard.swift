import SwiftUI

struct PickupCard: View {
    let record: PickupRecord
    let isCompleting: Bool
    let onOpen: () -> Void
    let onComplete: () -> Void

    var body: some View {
        Button(action: onOpen) {
            card
        }
        .buttonStyle(.plain)
        .offset(y: isCompleting ? 10 : 0)
        .scaleEffect(isCompleting ? 0.98 : 1)
        .opacity(isCompleting ? 0 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityHint("轻点用大字查看取件码，向右滑动可以收下")
        .accessibilityAction(named: "收下", onComplete)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.locationDisplayName)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(ShouxiaPalette.ink)
                        .lineLimit(1)

                    if record.locationSource == .commonDefault {
                        Label("常用取件点", systemImage: "house")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(ShouxiaPalette.mutedInk)
                    }
                }

                Spacer(minLength: 8)

                if let platform = record.platform {
                    Text(platform)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(ShouxiaPalette.mutedInk)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ShouxiaPalette.skyWash, in: Capsule())
                }
            }

            Text(record.code)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.62)
                .lineLimit(1)
                .foregroundStyle(ShouxiaPalette.ink)
                .tracking(0.8)
                .accessibilityLabel("取件码 \(record.code)")

            HStack {
                Label {
                    Text(record.createdAt, style: .relative)
                } icon: {
                    Image(systemName: "clock")
                }
                Spacer()
                Label("大字查看", systemImage: "rectangle.expand.vertical")
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
            color: ShouxiaPalette.ink.opacity(isCompleting ? 0.02 : 0.07),
            radius: isCompleting ? 10 : 18,
            y: isCompleting ? 4 : 9
        )
    }
}
