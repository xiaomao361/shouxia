import SwiftUI
import UIKit
import XCTest
@testable import Shouxia

final class ShouxiaThemeTests: XCTestCase {
    func testCorePaletteAdaptsBetweenLightAndDarkMode() {
        let colors = [
            ShouxiaPalette.canvas,
            ShouxiaPalette.paper,
            ShouxiaPalette.warmPaper,
            ShouxiaPalette.ink,
            ShouxiaPalette.mutedInk,
            ShouxiaPalette.breeze,
            ShouxiaPalette.skyWash,
            ShouxiaPalette.mist,
            ShouxiaPalette.apricot,
        ]

        for color in colors {
            XCTAssertNotEqual(
                rgba(color, style: .light),
                rgba(color, style: .dark)
            )
        }
    }

    func testDarkModeTextColorsKeepReadableContrast() {
        let backgrounds = [
            ShouxiaPalette.canvas,
            ShouxiaPalette.paper,
            ShouxiaPalette.warmPaper,
        ]
        let textColors = [
            ShouxiaPalette.ink,
            ShouxiaPalette.mutedInk,
            ShouxiaPalette.supportingInk,
            ShouxiaPalette.softInk,
        ]

        for background in backgrounds {
            for textColor in textColors {
                XCTAssertGreaterThanOrEqual(
                    contrastRatio(textColor, background, style: .dark),
                    4.5
                )
            }
        }
    }

    func testDarkModePrimaryButtonKeepsReadableContrast() {
        XCTAssertGreaterThanOrEqual(
            contrastRatio(ShouxiaPalette.actionInk, ShouxiaPalette.breeze, style: .dark),
            4.5
        )
        XCTAssertGreaterThanOrEqual(
            contrastRatio(ShouxiaPalette.actionInk, ShouxiaPalette.breezePressed, style: .dark),
            4.5
        )
    }

    private func contrastRatio(
        _ foreground: Color,
        _ background: Color,
        style: UIUserInterfaceStyle
    ) -> CGFloat {
        let foregroundLuminance = luminance(rgba(foreground, style: style))
        let backgroundLuminance = luminance(rgba(background, style: style))
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ color: RGBA) -> CGFloat {
        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(color.red)
            + 0.7152 * linearize(color.green)
            + 0.0722 * linearize(color.blue)
    }

    private func rgba(_ color: Color, style: UIUserInterfaceStyle) -> RGBA {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    private struct RGBA: Equatable {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }
}
