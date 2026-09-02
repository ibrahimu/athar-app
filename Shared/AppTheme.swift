import SwiftUI

/// طوابع لون التطبيق. كل طابع يبدّل اللون المميّز وخلفية الصفحة معًا،
/// ويتبع الوضع الفاتح والداكن من نفسه.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case green      // الأصل — أخضر مصحفي
    case sand       // رملي دافئ
    case sea        // أزرق بحري
    case rose       // وردي هادئ
    case violet     // بنفسجي
    case charcoal   // فحمي محايد

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green:    return "أخضر"
        case .sand:     return "رملي"
        case .sea:      return "بحري"
        case .rose:     return "وردي"
        case .violet:   return "بنفسجي"
        case .charcoal: return "فحمي"
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
        }
    }

    /// اللون المميّز في الوضعين.
    var accent: (light: UInt32, dark: UInt32) {
        switch self {
        case .green:    return (0x1F6B4F, 0x4FBF8F)
        case .sand:     return (0x9A6B33, 0xD3A263)
        case .sea:      return (0x1F6473, 0x5FB7CB)
        case .rose:     return (0xA0466A, 0xDD8CAA)
        case .violet:   return (0x5B5390, 0x9A91D6)
        case .charcoal: return (0x44514B, 0x9FB0A7)
        }
    }

    /// خلفية الصفحة.
    var canvas: (light: UInt32, dark: UInt32) {
        switch self {
        case .green:    return (0xF7F4EC, 0x0E1512)
        case .sand:     return (0xFAF5EA, 0x161210)
        case .sea:      return (0xF2F6F8, 0x0B1417)
        case .rose:     return (0xFBF3F5, 0x160F12)
        case .violet:   return (0xF6F4FA, 0x110F17)
        case .charcoal: return (0xF5F5F4, 0x111312)
        }
    }

    var surface: (light: UInt32, dark: UInt32) {
        switch self {
        case .green:    return (0xFFFDF8, 0x18211D)
        case .sand:     return (0xFFFCF5, 0x211B16)
        case .sea:      return (0xFFFFFF, 0x141F23)
        case .rose:     return (0xFFFAFB, 0x201820)
        case .violet:   return (0xFFFDFF, 0x1A1722)
        case .charcoal: return (0xFFFFFF, 0x1B1E1C)
        }
    }

    /// اللون الزخرفي — للميداليات وفواصل الآي والنجوم.
    var ornament: (light: UInt32, dark: UInt32) {
        switch self {
        case .green:    return (0xA9812C, 0xD9B45F)
        case .sand:     return (0xB07A2A, 0xE3B96A)
        case .sea:      return (0xA08339, 0xD8BC72)
        case .rose:     return (0xB07C46, 0xE0B584)
        case .violet:   return (0x8E7A3E, 0xD6BE7C)
        case .charcoal: return (0x8C7B4E, 0xC9B589)
        }
    }

    var hairline: (light: UInt32, dark: UInt32) {
        switch self {
        case .green:    return (0xE2DDD0, 0x2A352F)
        case .sand:     return (0xEBE0CC, 0x342A21)
        case .sea:      return (0xDEE7EB, 0x1F3038)
        case .rose:     return (0xF0DFE4, 0x33262D)
        case .violet:   return (0xE6E1F0, 0x2A2536)
        case .charcoal: return (0xE3E3E1, 0x2B2F2D)
        }
    }
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
