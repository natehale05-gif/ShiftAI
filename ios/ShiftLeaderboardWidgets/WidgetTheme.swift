import SwiftUI

/// ShiftColors.retro — the theme the app opens on by default. Widgets are
/// native views with no Flutter runtime behind them, so they cannot
/// follow an in-app theme switch; this is a fixed look, same reasoning
/// (and the same values) as android/.../values/colors.xml's widget_*.
enum WidgetTheme {
    static let background = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0F / 255)
    static let text = Color(red: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255)
    static let textMuted = Color(red: 0xBF / 255, green: 0xBF / 255, blue: 0xBF / 255)
    static let accent = Color(red: 0xFF / 255, green: 0x1A / 255, blue: 0x8C / 255)
    static let success = Color(red: 0x34 / 255, green: 0xD3 / 255, blue: 0x99 / 255)
    static let danger = Color(red: 0xF8 / 255, green: 0x71 / 255, blue: 0x71 / 255)
}

func movementLabel(_ movement: Int) -> String {
    if movement > 0 { return "▲ \(movement) UP" }
    if movement < 0 { return "▼ \(-movement) DOWN" }
    return ""
}

extension View {
    /// iOS 17 requires containerBackground(_:for:) on every widget (a bare
    /// .background is deprecated there and warns); anything before it does
    /// not have that API at all. Runner's own deployment target is 13, but
    /// this extension's can — and, per docs/WIDGETS.md, should — be set
    /// higher than that when it is added in Xcode.
    @ViewBuilder
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(color, for: .widget)
        } else {
            background(color)
        }
    }
}
