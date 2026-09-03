import Foundation

/// أصوات الأذان المضمَّنة — كلٌّ باسم صاحبه، مع نغمة النظام لمن يفضّلها.
/// لكل خيار ملفّان في الحزمة: `athan-<id>.caf` مقطع تنبيه ≤ ٣٠ ث (حدّ iOS
/// لأصوات الإشعارات)، و`athan-<id>-full.m4a` التسجيل كاملًا للاستماع داخل التطبيق.
enum AthanSound: String, CaseIterable, Identifiable, Hashable {
    case system
    case nabawi
    case fakhri
    case hatamzadeh
    case azeez
    case open

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:     return loc("نغمة النظام")
        case .nabawi:     return loc("أذان المسجد النبوي")
        case .fakhri:     return loc("أذان صباح فخري")
        case .hatamzadeh: return loc("أذان سعيد حاتم‌زاده")
        case .azeez:      return loc("أذان عاقب عزيز")
        case .open:       return loc("أذان (تسجيل مفتوح)")
        }
    }

    var shortTitle: String {
        switch self {
        case .system:     return loc("النظام")
        case .nabawi:     return loc("المسجد النبوي")
        case .fakhri:     return loc("صباح فخري")
        case .hatamzadeh: return loc("حاتم‌زاده")
        case .azeez:      return loc("عاقب عزيز")
        case .open:       return loc("تسجيل مفتوح")
        }
    }

    var detail: String {
        switch self {
        case .system:     return loc("صوت التنبيه المعتاد في جهازك")
        case .nabawi:     return loc("تسجيل من المسجد النبوي — CC BY")
        case .fakhri:     return loc("تسجيل قديم بصوته رحمه الله")
        case .hatamzadeh: return loc("أذان بمقام الماهور — CC BY-SA")
        case .azeez:      return loc("أذان مرتّل — CC BY-SA")
        case .open:       return loc("تسجيل متاح للعموم — CC0")
        }
    }

    /// اسم الملف في الحزمة بلا امتداد (لا شيء للنظام).
    var fileName: String? { self == .system ? nil : "athan-\(rawValue)" }
}
