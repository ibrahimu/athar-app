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
    /// لون النص فوق الأزرار الملوّنة — أبيض في الفاتح، خلفية داكنة في الداكن،
    /// لتجاوز فشل التباين (أبيض على لون فاتح ~٢:١).
    static var onAccent: Color {
        .adaptive(light: .white, dark: Color(hex: current.canvas.dark))
    }

    /// توحيد ألوان الأيقونات على اللون المميّز بدل ألوان الأقسام المتعدّدة.
    /// يُحدَّث من AtharStore حسب اختيار المستخدم في «المظهر».
    nonisolated(unsafe) static var unifyIcons: Bool = false

    /// النغمة الثانية للتدرّج — من عائلة اللون المميّز نفسه.
    static var accent2: Color { .adaptive(light: Color(hex: current.accent2.light), dark: Color(hex: current.accent2.dark)) }

    /// لون «إنجاز/إتمام» — مميّز عن الأخضر البراندي حتى لا تُقرأ الحالة المكتملة كأنها «العلامة التجارية».
    /// يُستعمل فقط بشفافية ٠٫٠٨–٠٫١٦.
    static var success: Color { .adaptive(light: Color(hex: 0x3FA37A), dark: Color(hex: 0x5FBF97)) }

    static var gold: Color { .adaptive(light: Color(hex: current.ornament.light), dark: Color(hex: current.ornament.dark)) }

    /// تدرّج ذهبي للزخارف والميداليات.
    static var goldGradient: LinearGradient {
        LinearGradient(colors: [gold.opacity(0.95), gold.opacity(0.55), gold.opacity(0.9)],
                       startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    static var hairline: Color { .adaptive(light: Color(hex: current.hairline.light), dark: Color(hex: current.hairline.dark)) }

    // MARK: Gradients — نظام «مدرَّج» ناعم، مصدر واحد للحقيقة

    /// تعبئة البطاقة الافتراضية الجديدة: ورق مصنفر خفيف (سطح ← سطح ثانوي).
    static var surfaceGradient: LinearGradient {
        LinearGradient(colors: [surface, surfaceAlt], startPoint: .top, endPoint: .bottom)
    }
    /// تدرّج اللون المميّز للأزرار والرقائق المختارة وأقواس الحلقات.
    /// (topTrailing = أعلى اليمين بصريًا = البداية، صحيح للاتجاه العربي.)
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topTrailing, endPoint: .bottomLeading)
    }
    /// غسالة علوية خفيفة للرؤوس والخلفيات.
    static var accentSheen: LinearGradient {
        LinearGradient(colors: [accent.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
    }
    /// سطح مصبوغ بلون قسم — لبطاقات «اللحظة» (الصلاة القادمة، الذكر النشط، التتابع).
    static func surfaceTint(_ c: Color) -> LinearGradient {
        LinearGradient(colors: [c.opacity(0.10), surface], startPoint: .top, endPoint: .bottom)
    }
    /// تدرّج ذو نغمتين لكل قسم — لرؤوس الأقسام وأشرطة التقدّم.
    static func gradient(for key: String) -> LinearGradient {
        if unifyIcons && key != "gold" { return accentGradient }   // وضع الأيقونات الموحّد
        let stops: [Color]
        switch key {
        case "dawn", "fajr":  stops = [Color(hex: 0xE0A063), Color(hex: 0xE08A6A)]
        case "night", "isha": stops = [Color(hex: 0x3A4F86), Color(hex: 0x7FA3D8)]
        case "sea", "hifz":   stops = [Color(hex: 0x2E9AAE), Color(hex: 0x5FB7CB)]
        case "calm":          stops = [Color(hex: 0xC06A88), Color(hex: 0x8E6BA8)]
        case "gold":          stops = [gold, gold.opacity(0.7)]
        case "green":         stops = [accent, accent2]
        default:              let c = accent(for: key); stops = [c, c.opacity(0.72)]
        }
        return LinearGradient(colors: stops, startPoint: .topTrailing, endPoint: .bottomLeading)
    }

    // MARK: Category accents — لوحة الأقسام القانونية الوحيدة

    static func accent(for key: String) -> Color {
        // الوضع الموحّد: كل الأيقونات بلون الطابع (عدا الذهب الزخرفي).
        if unifyIcons && key != "gold" { return accent }
        switch key {
        case "dawn", "fajr":  return Color.adaptive(light: Color(hex: 0xC77B36), dark: Color(hex: 0xE0A063))
        case "noon", "dhuhr": return Color.adaptive(light: Color(hex: 0xC79A2E), dark: Color(hex: 0xE6C468))
        case "asr":           return Color.adaptive(light: Color(hex: 0xB77A33), dark: Color(hex: 0xDDA766))
        case "maghrib":       return Color.adaptive(light: Color(hex: 0xB5556A), dark: Color(hex: 0xE08CA0))
        case "dusk":          return Color.adaptive(light: Color(hex: 0x5B5390), dark: Color(hex: 0x9A91D6))
        case "night", "isha": return Color.adaptive(light: Color(hex: 0x2F4A73), dark: Color(hex: 0x7FA3D8))
        case "green":         return accent
        case "gold":          return gold
        case "sea", "hifz":   return Color.adaptive(light: Color(hex: 0x1F6473), dark: Color(hex: 0x5FB7CB))
        case "calm":          return Color.adaptive(light: Color(hex: 0xA0466A), dark: Color(hex: 0xDD8CAA))
        case "success":       return success
        default:              return accent
        }
    }

    // MARK: Typography

    /// خط النص الشرعي: نسخ تقليدي (Noto Naskh Arabic, OFL) — أليق بالقرآن
    /// والأذكار من خط الواجهة، ويغطي كل محارف الرسم العثماني.
    /// يسقط إلى خط النظام إن تعذّر تحميله.
    static func dhikrFont(size: CGFloat, scale: Double = 1) -> Font {
        .custom("NotoNaskhArabic-Regular", size: size * scale, relativeTo: .body)
    }

    /// نسخ بوزن أثقل — لعناوين السور وما يحتاج تمييزًا.
    static func naskhFont(size: CGFloat, scale: Double = 1, bold: Bool = false) -> Font {
        .custom(bold ? "NotoNaskhArabic-Bold" : "NotoNaskhArabic-Medium",
                size: size * scale, relativeTo: .body)
    }

    static func display(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: Radius — نصف أقطار متراكزة (سمة iOS الفاخرة)

    enum Radius {
        static let sm: CGFloat = 12   // الرقائق والحبوب
        static let md: CGFloat = 18   // الصفوف والبطاقات الصغيرة
        static let lg: CGFloat = 24   // البطاقات (الافتراضي)
        static let xl: CGFloat = 30   // الأوراق والبطاقات البطلة
    }
    static let corner: CGFloat = Radius.lg   // اسم بديل متوافق مع ما سبق

    // MARK: Space — إيقاع مسافات واحد بدل الأرقام السحرية

    enum Space {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 18
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    static let gutter: CGFloat = 18

    // MARK: Elevation — عمق ناعم بظلّين متراكبين (تلامس + محيط)

    struct ShadowSpec { let color: Color; let radius: CGFloat; let x: CGFloat; let y: CGFloat }

    enum Elevation { case e0, e1, e2, e3 }

    /// لون ظلّ ثابت من حبر الطابع (داكن) بشفافية منخفضة — كالأصل.
    private static var shadowInk: Color { Color(hex: current.ink.light) }

    static func elevation(_ level: Elevation) -> [ShadowSpec] {
        switch level {
        case .e0: return []
        case .e1: return [ShadowSpec(color: shadowInk.opacity(0.04), radius: 10, x: 0, y: 3),
                          ShadowSpec(color: shadowInk.opacity(0.05), radius: 2,  x: 0, y: 1)]
        case .e2: return [ShadowSpec(color: shadowInk.opacity(0.05), radius: 22, x: 0, y: 10),
                          ShadowSpec(color: accent.opacity(0.045),   radius: 8,  x: 0, y: 4)]
        case .e3: return [ShadowSpec(color: shadowInk.opacity(0.10), radius: 28, x: 0, y: 16)]
        }
    }

    /// ظل ناعم يرفع البطاقة عن الخلفية بلا حدّ صلب — أخفّ على العين من الإطار.
    /// (مُبقى للتوافق؛ الجديد يستعمل atharElevation.)
    static var cardShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        (Color(hex: current.ink.light).opacity(0.055), 14, 5)
    }
}

// MARK: - Elevation modifier

private struct ElevationModifier: ViewModifier {
    let specs: [Theme.ShadowSpec]
    func body(content: Content) -> some View {
        content
            .shadow(color: specs.count > 0 ? specs[0].color : .clear,
                    radius: specs.count > 0 ? specs[0].radius : 0,
                    x: specs.count > 0 ? specs[0].x : 0, y: specs.count > 0 ? specs[0].y : 0)
            .shadow(color: specs.count > 1 ? specs[1].color : .clear,
                    radius: specs.count > 1 ? specs[1].radius : 0,
                    x: specs.count > 1 ? specs[1].x : 0, y: specs.count > 1 ? specs[1].y : 0)
    }
}

extension View {
    /// يرفع العنصر بظلّين متراكبين حسب مستوى العمق.
    func atharElevation(_ level: Theme.Elevation = .e1) -> some View {
        modifier(ElevationModifier(specs: Theme.elevation(level)))
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
