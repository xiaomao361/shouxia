import SwiftUI
import UIKit

enum ShouxiaPalette {
    static let canvas = adaptive(light: 0xF3F9FB, dark: 0x10181C)
    static let paper = adaptive(light: 0xFFFDFC, dark: 0x192429)
    static let warmPaper = adaptive(light: 0xFFF3ED, dark: 0x2A211E)
    static let ink = adaptive(light: 0x263746, dark: 0xEEF5F6)
    static let actionInk = adaptive(light: 0x263746, dark: 0x08110E)
    static let mutedInk = adaptive(light: 0x657985, dark: 0xB0C0C5)
    static let supportingInk = adaptive(light: 0x607480, dark: 0x9EB0B6)
    static let softInk = adaptive(light: 0x8A9AA3, dark: 0x84979D)
    static let breeze = adaptive(light: 0xB7DDD2, dark: 0x4C9583)
    static let breezePressed = adaptive(light: 0x9FCFC2, dark: 0x478B7B)
    static let skyWash = adaptive(light: 0xDDEFF6, dark: 0x1C3440)
    static let mist = adaptive(light: 0xE8E2EF, dark: 0x332D3D)
    static let apricot = adaptive(light: 0xF1A17D, dark: 0xE48A67)
    static let line = adaptive(
        light: 0x263746,
        dark: 0xFFFFFF,
        lightAlpha: 0.065,
        darkAlpha: 0.12
    )
    static let cardHighlight = adaptive(
        light: 0xFFFFFF,
        dark: 0xFFFFFF,
        lightAlpha: 0.82,
        darkAlpha: 0.12
    )
    static let celebrationGlow = adaptive(
        light: 0xF1A17D,
        dark: 0xE48A67,
        lightAlpha: 0.15,
        darkAlpha: 0.18
    )

    private static func adaptive(
        light: UInt32,
        dark: UInt32,
        lightAlpha: CGFloat = 1,
        darkAlpha: CGFloat = 1
    ) -> Color {
        Color(
            uiColor: UIColor { traits in
                let value = traits.userInterfaceStyle == .dark ? dark : light
                let alpha = traits.userInterfaceStyle == .dark ? darkAlpha : lightAlpha
                return uiColor(hex: value, alpha: alpha)
            }
        )
    }

    private static func uiColor(hex: UInt32, alpha: CGFloat) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

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
            .foregroundStyle(ShouxiaPalette.actionInk)
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
