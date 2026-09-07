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
        case .theme:     return "theme"
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
        case "theme":     self = .theme
        default:          return nil
        }
    }
}
#endif
