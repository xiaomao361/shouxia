import SwiftUI

enum ShouxiaPalette {
    static let canvas = Color(red: 0.953, green: 0.976, blue: 0.984)
    static let paper = Color(red: 1.0, green: 0.992, blue: 0.988)
    static let warmPaper = Color(red: 1.0, green: 0.953, blue: 0.929)
    static let ink = Color(red: 0.149, green: 0.216, blue: 0.275)
    static let mutedInk = Color(red: 0.396, green: 0.475, blue: 0.522)
    static let supportingInk = Color(red: 0.376, green: 0.455, blue: 0.502)
    static let softInk = Color(red: 0.541, green: 0.604, blue: 0.639)
    static let breeze = Color(red: 0.718, green: 0.867, blue: 0.824)
    static let breezePressed = Color(red: 0.624, green: 0.812, blue: 0.761)
    static let skyWash = Color(red: 0.867, green: 0.937, blue: 0.965)
    static let mist = Color(red: 0.910, green: 0.886, blue: 0.937)
    static let apricot = Color(red: 0.945, green: 0.631, blue: 0.490)
    static let line = ink.opacity(0.065)
    static let cardHighlight = Color.white.opacity(0.82)
    static let celebrationGlow = apricot.opacity(0.15)

    static func accent(for record: PickupRecord) -> Color {
        switch record.platform {
        case "菜鸟":
            apricot
        case "丰巢":
            breeze
        case "京东":
            mist
        default:
            skyWash
        }
    }
}

enum ShouxiaMotion {
    static let press = Animation.easeOut(duration: 0.14)
    static let threshold = Animation.spring(duration: 0.28, bounce: 0.16)
    static let completion = Animation.spring(duration: 0.46, bounce: 0.12)
    static let settle = Animation.spring(duration: 0.34, bounce: 0.14)
}

struct ShouxiaBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ShouxiaPalette.canvas

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ShouxiaPalette.skyWash.opacity(0.78),
                                ShouxiaPalette.skyWash.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 190
                        )
                    )
                    .frame(width: 380, height: 380)
                    .position(x: proxy.size.width + 28, y: 116)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ShouxiaPalette.mist.opacity(0.52),
                                ShouxiaPalette.mist.opacity(0)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .position(
                        x: -36,
                        y: proxy.size.height * 0.82
                    )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ShouxiaPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            configuration.label
            Spacer(minLength: 0)
        }
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(ShouxiaPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                configuration.isPressed
                    ? ShouxiaPalette.breezePressed
                    : ShouxiaPalette.breeze,
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .offset(y: configuration.isPressed ? 1 : 0)
            .shadow(
                color: ShouxiaPalette.ink.opacity(
                    configuration.isPressed ? 0.04 : 0.075
                ),
                radius: configuration.isPressed ? 5 : 14,
                y: configuration.isPressed ? 2 : 7
            )
            .animation(ShouxiaMotion.press, value: configuration.isPressed)
    }
}

struct ShouxiaSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            configuration.label
            Spacer(minLength: 0)
        }
        .font(.headline)
        .fontDesign(.rounded)
        .foregroundStyle(ShouxiaPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(
            configuration.isPressed
                ? ShouxiaPalette.skyWash.opacity(0.88)
                : ShouxiaPalette.paper.opacity(0.94),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
        }
        .scaleEffect(configuration.isPressed ? 0.99 : 1)
        .offset(y: configuration.isPressed ? 1 : 0)
        .shadow(
            color: ShouxiaPalette.ink.opacity(configuration.isPressed ? 0.025 : 0.055),
            radius: configuration.isPressed ? 4 : 11,
            y: configuration.isPressed ? 1 : 5
        )
        .animation(ShouxiaMotion.press, value: configuration.isPressed)
    }
}

struct ShouxiaImportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            configuration.label
            Spacer(minLength: 0)
        }
        .font(.headline)
        .fontDesign(.rounded)
        .foregroundStyle(ShouxiaPalette.ink)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(
            configuration.isPressed
                ? ShouxiaPalette.skyWash.opacity(0.88)
                : ShouxiaPalette.paper.opacity(0.94),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ShouxiaPalette.cardHighlight, lineWidth: 1)
        }
        .scaleEffect(configuration.isPressed ? 0.99 : 1)
        .offset(y: configuration.isPressed ? 1 : 0)
        .shadow(
            color: ShouxiaPalette.ink.opacity(configuration.isPressed ? 0.025 : 0.055),
            radius: configuration.isPressed ? 4 : 11,
            y: configuration.isPressed ? 1 : 5
        )
        .animation(ShouxiaMotion.press, value: configuration.isPressed)
    }
}

struct ShouxiaMark: View {
    var showsBackground = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size.width

            ZStack {
                if showsBackground {
                    RoundedRectangle(
                        cornerRadius: size * 0.28,
                        style: .continuous
                    )
                    .fill(ShouxiaPalette.skyWash)
                }

                ZStack {
                    RoundedRectangle(
                        cornerRadius: size * 0.11,
                        style: .continuous
                    )
                    .fill(ShouxiaPalette.apricot)

                    Capsule()
                        .fill(ShouxiaPalette.paper.opacity(0.92))
                        .frame(width: size * 0.052)

                    Capsule()
                        .fill(ShouxiaPalette.breezePressed)
                        .frame(height: size * 0.055)
                }
                .frame(
                    width: size * 0.62,
                    height: size * 0.57
                )
                .offset(
                    x: -size * 0.07,
                    y: size * 0.055
                )

                ZStack {
                    RoundedRectangle(
                        cornerRadius: size * 0.075,
                        style: .continuous
                    )
                    .fill(ShouxiaPalette.paper)

                    HStack(spacing: size * 0.025) {
                        ForEach(0..<3, id: \.self) { index in
                            RoundedRectangle(
                                cornerRadius: size * 0.018,
                                style: .continuous
                            )
                            .fill(
                                index == 1
                                    ? ShouxiaPalette.skyWash
                                    : ShouxiaPalette.breezePressed
                            )
                            .frame(
                                width: size * 0.065,
                                height: size * 0.065
                            )
                        }
                    }
                    .offset(y: -size * 0.045)

                    Capsule()
                        .fill(ShouxiaPalette.skyWash)
                        .frame(
                            width: size * 0.22,
                            height: size * 0.028
                        )
                        .offset(y: size * 0.075)
                }
                .frame(
                    width: size * 0.37,
                    height: size * 0.34
                )
                .offset(
                    x: size * 0.19,
                    y: size * 0.12
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
