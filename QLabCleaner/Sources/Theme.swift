import SwiftUI
import AppKit

enum Theme {
    static let bg = Color(red: 0.043, green: 0.046, blue: 0.058)
    static let bgElevated = Color(red: 0.078, green: 0.083, blue: 0.104)
    static let surface = Color(red: 0.125, green: 0.133, blue: 0.162)
    static let surfaceHover = Color(red: 0.165, green: 0.175, blue: 0.215)
    static let stroke = Color.white.opacity(0.07)
    static let strokeStrong = Color.white.opacity(0.13)

    static let text = Color(red: 0.965, green: 0.972, blue: 0.985)
    static let textMuted = Color(red: 0.640, green: 0.670, blue: 0.735)
    static let textFaint = Color(red: 0.430, green: 0.458, blue: 0.520)

    static let accent = Color(red: 1.0, green: 0.455, blue: 0.220)
    static let accentSoft = Color(red: 1.0, green: 0.455, blue: 0.220).opacity(0.16)

    static let used = Color(red: 0.310, green: 0.870, blue: 0.640)
    static let usedSoft = Color(red: 0.310, green: 0.870, blue: 0.640).opacity(0.14)

    static let unused = Color(red: 1.0, green: 0.730, blue: 0.250)
    static let unusedSoft = Color(red: 1.0, green: 0.730, blue: 0.250).opacity(0.14)

    static let danger = Color(red: 1.0, green: 0.400, blue: 0.460)
    static let dangerSoft = Color(red: 1.0, green: 0.400, blue: 0.460).opacity(0.14)

    static let radius: CGFloat = 18
    static let radiusSmall: CGFloat = 12

    static var windowNSColor: NSColor {
        NSColor(calibratedRed: 0.043, green: 0.046, blue: 0.058, alpha: 1)
    }
}

extension View {
    func themePanel() -> some View {
        background(Theme.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .cornerRadius(Theme.radius)
    }

    func themeControl(radius: CGFloat = Theme.radiusSmall) -> some View {
        background(Theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Theme.stroke, lineWidth: 1)
            )
            .cornerRadius(radius)
    }
}
