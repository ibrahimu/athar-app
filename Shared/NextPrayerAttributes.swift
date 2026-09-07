import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// النشاط الحيّ للصلاة القادمة — يظهر في Dynamic Island وشاشة القفل بعدٍّ تنازلي.
struct NextPrayerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// اسم الصلاة المعروض («العصر»).
        var prayerTitle: String
        /// مفتاح الصلاة (rawValue) — للأيقونة.
        var prayerKey: String
        /// موعد الأذان.
        var time: Date
        var place: String
        /// مفتاح لحظة اليوم (AtharStyle.Moment) وقت طلب النشاط — بها يلبس النشاط لوحة
        /// الويدجتات نفسها فلا يخالف لونُ شاشة القفل لونَ الشاشة الرئيسية. اختياري حتى
        /// يُفكّ نشاطٌ قائم من إصدار سابق بلا هذا الحقل فيُنهى بدل أن يبقى يتيمًا.
        var momentKey: String?
    }

    var startedAt: Date
}

extension AtharStyle.Moment {
    /// مفتاح نصّي يُحمل في حالة النشاط (Codable) ويُفكّ في امتداد الويدجت.
    var activityKey: String {
        switch self {
        case .night:     return "night"
        case .dawn:      return "dawn"
        case .morning:   return "morning"
        case .noon:      return "noon"
        case .afternoon: return "afternoon"
        case .sunset:    return "sunset"
        // اسم الطابع جزءٌ من المفتاح: حالة النشاط لا تتبدّل بتبديل الطابع وحده، فيبقى النشاط
        // القائم بلونه القديم حتى الأذان التالي. بالمفتاح المركّب تتبدّل الحالة فيُعاد رسمه.
        case .theme:     return "theme:" + AtharStore.shared.appTheme.rawValue
        }
    }

    init?(activityKey: String) {
        switch activityKey {
        case "night":     self = .night
        case "dawn":      self = .dawn
        case "morning":   self = .morning
        case "noon":      self = .noon
        case "afternoon": self = .afternoon
        case "sunset":    self = .sunset
        // «theme» وحدها من إصدارٍ سابق، و«theme:<الطابع>» من هذا.
        default:          if activityKey.hasPrefix("theme") { self = .theme } else { return nil }
        }
    }
}
#endif
