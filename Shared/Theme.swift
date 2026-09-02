import SwiftUI

/// Visual language for أثر — a calm, paper-and-ink palette with a single
/// green accent, tuned so Arabic text stays the loudest thing on screen.
enum Theme {

    /// الطابع الفعّال. يُحدَّث من AtharStore عند التغيير، وتقرأه الألوان أدناه.
    nonisolated(unsafe) static var current: AppTheme = .green

    // MARK: Core palette

    static let ink       = Color("Ink", bundle: nil, fallbackLight: Color(hex: 0x14201B), fallbackDark: Color(hex: 0xEFEAE0))
    static let inkSoft   = Color.adaptive(light: Color(hex: 0x4A5B52), dark: Color(hex: 0xA9B5AC))
    static let inkFaint  = Color.adaptive(light: Color(hex: 0x8A9992), dark: Color(hex: 0x76837B))

    static var canvas: Color    { .adaptive(light: Color(hex: current.canvas.light),  dark: Color(hex: current.canvas.dark)) }
    static var surface: Color   { .adaptive(light: Color(hex: current.surface.light), dark: Color(hex: current.surface.dark)) }
    static let surfaceAlt = Color.adaptive(light: Color(hex: 0xF0EDE2), dark: Color(hex: 0x212B26))

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

    static let corner: CGFloat = 20
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
