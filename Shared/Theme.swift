import SwiftUI

/// Visual language for أثر — a calm, paper-and-ink palette with a single
/// green accent, tuned so Arabic text stays the loudest thing on screen.
enum Theme {

    /// الطابع الفعّال. يُحدَّث من AtharStore عند التغيير، وتقرأه الألوان أدناه.
    nonisolated(unsafe) static var current: AppTheme = .green

    // MARK: Core palette

    static var ink: Color { .adaptive(light: Color(hex: current.ink.light), dark: Color(hex: current.ink.dark)) }
    static var inkSoft: Color {
        .adaptive(light: Color(hex: current.ink.light).opacity(0.68), dark: Color(hex: current.ink.dark).opacity(0.72))
    }
    static var inkFaint: Color {
        .adaptive(light: Color(hex: current.ink.light).opacity(0.45), dark: Color(hex: current.ink.dark).opacity(0.45))
    }

    static var canvas: Color    { .adaptive(light: Color(hex: current.canvas.light),  dark: Color(hex: current.canvas.dark)) }
    static var surface: Color   { .adaptive(light: Color(hex: current.surface.light), dark: Color(hex: current.surface.dark)) }
    static var surfaceAlt: Color { .adaptive(light: Color(hex: current.surfaceAlt.light), dark: Color(hex: current.surfaceAlt.dark)) }

    static var accent: Color { .adaptive(light: Color(hex: current.accent.light), dark: Color(hex: current.accent.dark)) }
    static var accentSoft: Color {
        .adaptive(light: Color(hex: current.accent.light).opacity(0.13),
                  dark:  Color(hex: current.accent.dark).opacity(0.18))
    }
    /// اللون الزخرفي — يتبع الطابع المختار.
    static var gold: Color { .adaptive(light: Color(hex: current.ornament.light), dark: Color(hex: current.ornament.dark)) }

    /// تدرّج ذهبي للزخارف والميداليات.
    static var goldGradient: LinearGradient {
        LinearGradient(colors: [gold.opacity(0.95), gold.opacity(0.55), gold.opacity(0.9)],
                       startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    static var hairline: Color { .adaptive(light: Color(hex: current.hairline.light), dark: Color(hex: current.hairline.dark)) }

    // MARK: Category accents

    static func accent(for key: String) -> Color {
        switch key {
        case "dawn":  return Color.adaptive(light: Color(hex: 0xC77B36), dark: Color(hex: 0xE0A063))
        case "dusk":  return Color.adaptive(light: Color(hex: 0x5B5390), dark: Color(hex: 0x9A91D6))
        case "night": return Color.adaptive(light: Color(hex: 0x2F4A73), dark: Color(hex: 0x7FA3D8))
        case "green": return accent
        case "gold":  return gold
        case "sea":   return Color.adaptive(light: Color(hex: 0x1F6473), dark: Color(hex: 0x5FB7CB))
        case "calm":  return Color.adaptive(light: Color(hex: 0xA0466A), dark: Color(hex: 0xDD8CAA))
        default:      return accent
        }
    }

    // MARK: Typography

    /// Arabic body text — SF Arabic renders tashkeel cleanly at these sizes.
    static func dhikrFont(size: CGFloat, scale: Double = 1) -> Font {
        .system(size: size * scale, weight: .regular)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    static let corner: CGFloat = 24

    /// ظل ناعم يرفع البطاقة عن الخلفية بلا حدّ صلب — أخفّ على العين من الإطار.
    static var cardShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        (Color(hex: current.ink.light).opacity(0.055), 14, 5)
    }
}

// MARK: - Color helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Resolves per colour-scheme without needing an asset catalog entry.
    static func adaptive(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return light
        #endif
    }

    init(_ name: String, bundle: Bundle?, fallbackLight: Color, fallbackDark: Color) {
        self = .adaptive(light: fallbackLight, dark: fallbackDark)
    }
}

// MARK: - Numerals

extension Int {
    /// Grouped Western digits. Arabic-Indic ٠ renders as a solid dot at display
    /// sizes, which reads as a bullet rather than a number.
    var counterText: String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
