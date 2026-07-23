import SwiftUI

enum ShouxiaPalette {
    static let canvas = Color(red: 0.965, green: 0.949, blue: 0.918)
    static let paper = Color(red: 1.0, green: 0.997, blue: 0.982)
    static let warmPaper = Color(red: 0.984, green: 0.966, blue: 0.925)
    static let ink = Color(red: 0.13, green: 0.12, blue: 0.17)
    static let mutedInk = Color(red: 0.34, green: 0.32, blue: 0.39)
    static let softInk = Color(red: 0.49, green: 0.46, blue: 0.50)
    static let evergreen = Color(red: 0.18, green: 0.36, blue: 0.32)
    static let deepEvergreen = Color(red: 0.10, green: 0.24, blue: 0.22)
    static let apricot = Color(red: 0.88, green: 0.47, blue: 0.29)
    static let sage = Color(red: 0.36, green: 0.57, blue: 0.46)
    static let ochre = Color(red: 0.70, green: 0.53, blue: 0.29)
    static let line = Color(red: 0.26, green: 0.22, blue: 0.18).opacity(0.08)

    static func accent(for record: PickupRecord) -> Color {
        switch record.platform {
        case "菜鸟":
            apricot
        case "丰巢":
            sage
        case "京东":
            ochre
        default:
            evergreen
        }
    }
}
