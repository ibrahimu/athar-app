import SwiftUI

/// خطّ الواجهة الذي يختاره المستخدم: عناوين الشاشات والأزرار والأوصاف.
/// لا يمسّ النص الشرعي أبدًا — القرآن والحديث والأذكار والتفسير تبقى بخط النسخ
/// (Theme.dhikrFont / naskhFont) مهما اختار المستخدم هنا.
enum AppFont: String, CaseIterable, Identifiable, Codable {
    case system     // خط النظام (SF Arabic)
    case naskh      // Noto Naskh Arabic نفسه الذي يكتب به النص الشرعي
    case thmanyah   // ثمانية — خط مرخَّص مضمَّن في التطبيق

    var id: String { rawValue }

    /// الخطّ الفعّال. يضبطه AtharStore عند التغيير وعند الإقلاع، وتقرأه Theme.display.
    /// افتراضه خط النظام حتى تبقى الودجات والساعة (التي لا تسجّل «ثمانية») سليمة.
    nonisolated(unsafe) static var current: AppFont = .system

    var title: String {
        switch self {
        case .system:   return "النظام"
        case .naskh:    return "نسخ"
        case .thmanyah: return "ثمانية"
        }
    }

    var detail: String {
        switch self {
        case .system:   return "خط iOS الأصلي، الأخفّ والأوضح في الأحجام الصغيرة."
        case .naskh:    return "الواجهة كلها بالنسخ نفسه الذي يُكتب به القرآن والأذكار."
        case .thmanyah: return "خط عربي معاصر من ثمانية، هادئ في العناوين والأزرار."
        }
    }

    /// اسم الوجه (PostScript) المناسب للوزن: ثلاثة أوزان فقط لكل خط، فتُقرَّب أوزان
    /// SwiftUI التسعة إليها. تُستدعى بحجم مضبوط مسبقًا (Theme.scaled) فلا نكرّر Dynamic Type.
    func font(size: CGFloat, weight: Font.Weight) -> Font {
        switch self {
        case .system:
            return .system(size: size, weight: weight)
        case .naskh:
            return .custom("NotoNaskhArabic-\(Self.faceSuffix(for: weight))", fixedSize: size)
        case .thmanyah:
            return .custom("thmanyahsans-\(Self.faceSuffix(for: weight))", fixedSize: size)
        }
    }

    private static func faceSuffix(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:  return "Bold"
        case .medium, .semibold:     return "Medium"
        default:                     return "Regular"
        }
    }
}
