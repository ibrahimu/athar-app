import SwiftUI

/// طوابع لون التطبيق. كل طابع يبدّل اللون المميّز وخلفية الصفحة معًا،
/// ويتبع الوضع الفاتح والداكن من نفسه. البيانات في جدول واحد (Palette)
/// حتى تبقى الأدوار متّسقة ويسهل زيادة الألوان.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case green      // الأصل — أخضر مصحفي
    case sand       // رملي دافئ
    case sea        // أزرق بحري
    case rose       // وردي هادئ
    case violet     // بنفسجي
    case charcoal   // فحمي محايد
    case olive      // زيتوني
    case indigo     // نيلي
    case plum       // برقوقي
    case amber      // عسلي
    case mint       // نعناعي
    case slate      // إردوازي

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green:    return "أخضر"
        case .sand:     return "رملي"
        case .sea:      return "بحري"
        case .rose:     return "وردي"
        case .violet:   return "بنفسجي"
        case .charcoal: return "فحمي"
        case .olive:    return "زيتوني"
        case .indigo:   return "نيلي"
        case .plum:     return "برقوقي"
        case .amber:    return "عسلي"
        case .mint:     return "نعناعي"
        case .slate:    return "إردوازي"
        }
    }
    var shortTitle: String { title }
    var detail: String {
        switch self {
        case .green:    return "الطابع الأصلي — أخضر المصحف"
        case .sand:     return "دافئ يميل إلى الورق القديم"
        case .sea:      return "أزرق هادئ يريح العين"
        case .rose:     return "وردي خافت ناعم"
        case .violet:   return "بنفسجي للمساء"
        case .charcoal: return "رمادي محايد بلا لون طاغٍ"
        case .olive:    return "أخضر زيتوني هادئ"
        case .indigo:   return "نيليّ عميق للمساء"
        case .plum:     return "برقوقيّ دافئ"
        case .amber:    return "عسليّ يميل إلى الذهب"
        case .mint:     return "نعناعيّ منعش"
        case .slate:    return "رماديّ مزرقّ محايد"
        }
    }

    // MARK: - جدول الألوان

    struct Palette {
        let accent, accent2, canvas, surface, surfaceAlt, ink, ornament, hairline: (light: UInt32, dark: UInt32)
    }

    var palette: Palette {
        switch self {
        case .green: return Palette(
            accent: (0x1F6B4F, 0x4FBF8F), accent2: (0x2E8F72, 0x63C9A0),
            canvas: (0xF7F4EC, 0x0E1512), surface: (0xFFFDF8, 0x18241F),
            surfaceAlt: (0xF0EDE2, 0x212E28), ink: (0x14201B, 0xEDF2EF),
            ornament: (0xA9812C, 0xD9B45F), hairline: (0xE2DDD0, 0x2A352F))
        case .sand: return Palette(
            accent: (0x8A5D28, 0xD3A263), accent2: (0xA8702F, 0xE0B472),
            canvas: (0xFAF5EA, 0x161210), surface: (0xFFFCF5, 0x241D16),
            surfaceAlt: (0xF4EDDD, 0x2E251B), ink: (0x241B12, 0xF4EEE4),
            ornament: (0xB07A2A, 0xE3B96A), hairline: (0xEBE0CC, 0x342A21))
        case .sea: return Palette(
            accent: (0x1F6473, 0x5FB7CB), accent2: (0x1E7C8C, 0x74C7DA),
            canvas: (0xF2F6F8, 0x0B1417), surface: (0xFDFEFF, 0x13222A),
            surfaceAlt: (0xEDF3F6, 0x1B2E38), ink: (0x0F1D24, 0xE9F2F6),
            ornament: (0xA08339, 0xD8BC72), hairline: (0xDEE7EB, 0x1F3038))
        case .rose: return Palette(
            accent: (0xA0466A, 0xDD8CAA), accent2: (0xB85C7E, 0xE79CB6),
            canvas: (0xFBF3F5, 0x160F12), surface: (0xFFFAFB, 0x241A21),
            surfaceAlt: (0xF9EDF0, 0x2E222A), ink: (0x241119, 0xF7ECF0),
            ornament: (0xB07C46, 0xE0B584), hairline: (0xF0DFE4, 0x33262D))
        case .violet: return Palette(
            accent: (0x5B5390, 0x9A91D6), accent2: (0x6E5FB0, 0xACA2E4),
            canvas: (0xF6F4FA, 0x110F17), surface: (0xFDFCFF, 0x1E1A2B),
            surfaceAlt: (0xF2EFF9, 0x272136), ink: (0x171233, 0xEFECF8),
            ornament: (0x8E7A3E, 0xD6BE7C), hairline: (0xE6E1F0, 0x2A2536))
        case .charcoal: return Palette(
            accent: (0x44514B, 0x9FB0A7), accent2: (0x566259, 0xB2C0B7),
            canvas: (0xF5F5F4, 0x111312), surface: (0xFFFFFF, 0x1D211F),
            surfaceAlt: (0xF0F0EF, 0x272B29), ink: (0x161917, 0xEFF1F0),
            ornament: (0x8C7B4E, 0xC9B589), hairline: (0xE3E3E1, 0x2B2F2D))
        case .olive: return Palette(
            accent: (0x6E7C33, 0xBFCE72), accent2: (0x818F3D, 0xCBD983),
            canvas: (0xF6F4E9, 0x12140C), surface: (0xFEFDF4, 0x1F2417),
            surfaceAlt: (0xEEEDDD, 0x28301D), ink: (0x1E2110, 0xF0F1E6),
            ornament: (0xA8892F, 0xD9C06A), hairline: (0xE3E1CE, 0x2E3320))
        case .indigo: return Palette(
            accent: (0x3B4E8C, 0x8BA0E0), accent2: (0x4B5EA0, 0x9DB0EA),
            canvas: (0xF3F4FA, 0x0C0E16), surface: (0xFCFDFF, 0x171A2A),
            surfaceAlt: (0xEBEDF7, 0x1F2338), ink: (0x141830, 0xEBEEF8),
            ornament: (0x8E7A3E, 0xD6BE7C), hairline: (0xE1E3F0, 0x262B40))
        case .plum: return Palette(
            accent: (0x7A3B63, 0xC77FAE), accent2: (0x8E4B76, 0xD48FBC),
            canvas: (0xF9F3F7, 0x150E13), surface: (0xFFFAFD, 0x241A21),
            surfaceAlt: (0xF2E9EF, 0x2E2230), ink: (0x24111E, 0xF6ECF2),
            ornament: (0xB07C46, 0xE0B584), hairline: (0xEEDEE8, 0x33262F))
        case .amber: return Palette(
            accent: (0xB5722A, 0xE3AE62), accent2: (0xC5842F, 0xEBBB74),
            canvas: (0xFAF5EA, 0x161009), surface: (0xFFFCF4, 0x241C12),
            surfaceAlt: (0xF4ECDA, 0x2E2517), ink: (0x241A0F, 0xF5EEE1),
            ornament: (0xB07A2A, 0xE3B96A), hairline: (0xEBE1CD, 0x342A1D))
        case .mint: return Palette(
            accent: (0x1F8F7A, 0x5FD4BC), accent2: (0x27A08A, 0x74DCC8),
            canvas: (0xF0F7F5, 0x0B1512), surface: (0xF9FEFC, 0x132420),
            surfaceAlt: (0xE7F2EF, 0x1B302B), ink: (0x0F211C, 0xE7F4F0),
            ornament: (0xA08339, 0xD8BC72), hairline: (0xDCE9E5, 0x1F332E))
        case .slate: return Palette(
            accent: (0x4A5A6B, 0x9DB2C7), accent2: (0x586A7D, 0xB0C2D4),
            canvas: (0xF3F5F7, 0x0D1013), surface: (0xFCFDFE, 0x1A2026),
            surfaceAlt: (0xEBEFF3, 0x232B33), ink: (0x161B21, 0xEDF1F5),
            ornament: (0x8C7B4E, 0xC9B589), hairline: (0xE0E5EA, 0x2A333B))
        }
    }

    var accent: (light: UInt32, dark: UInt32)     { palette.accent }
    var accent2: (light: UInt32, dark: UInt32)    { palette.accent2 }
    var canvas: (light: UInt32, dark: UInt32)     { palette.canvas }
    var surface: (light: UInt32, dark: UInt32)    { palette.surface }
    var surfaceAlt: (light: UInt32, dark: UInt32) { palette.surfaceAlt }
    var ink: (light: UInt32, dark: UInt32)        { palette.ink }
    var ornament: (light: UInt32, dark: UInt32)   { palette.ornament }
    var hairline: (light: UInt32, dark: UInt32)   { palette.hairline }
}

/// نقش خلفية التطبيق — يختاره المستخدم. النقوش كلها باهتة جدًا («تُحسّ لا تُقرأ»).
enum BackgroundPattern: String, CaseIterable, Identifiable, Codable {
    case stars      // نجمات ثمانية محفورة (الأصل)
    case plain      // سادة — بلا نقش، غسالات لونية فقط
    case waves      // أثر القطرة — حلقات متمددة، هوية «أثر»
    case lattice    // تعريشة هندسية متشابكة
    case dots       // نقاط ناعمة
    case scales     // حراشف — أقواس متراكبة (زخرفة إسلامية)

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stars:   return "نجوم"
        case .plain:   return "سادة"
        case .waves:   return "موج"
        case .lattice: return "تعريشة"
        case .dots:    return "نقاط"
        case .scales:  return "حراشف"
        }
    }
    var shortTitle: String { title }
    var detail: String {
        switch self {
        case .stars:   return "نجمات ثمانية محفورة على الورق"
        case .plain:   return "ورق صافٍ بلا نقش"
        case .waves:   return "حلقات أثر القطرة الهادئة"
        case .lattice: return "تعريشة هندسية متشابكة"
        case .dots:    return "نقاط ناعمة منتظمة"
        case .scales:  return "حراشف مقوّسة — زخرفة إسلامية"
        }
    }

    /// النقش الفعّال — يُحدَّث من AtharStore، ويقرأه AtharBackground.
    nonisolated(unsafe) static var current: BackgroundPattern = .stars
}

/// الوضع الفاتح/الداكن الذي يختاره المستخدم.
enum AppearanceMode: String, CaseIterable, Identifiable, Codable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "حسب الجهاز"
        case .light:  return "فاتح"
        case .dark:   return "داكن"
        }
    }
    var shortTitle: String { title }
    var detail: String {
        switch self {
        case .system: return "يتبع إعدادات النظام"
        case .light:  return "فاتح دائمًا"
        case .dark:   return "داكن دائمًا"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
