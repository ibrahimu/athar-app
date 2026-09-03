import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// النشاط الحيّ للصلاة القادمة — يظهر في Dynamic Island وشاشة القفل بعدٍّ تنازلي.
struct NextPrayerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// اسم الصلاة المعروض («العصر»).
        var prayerTitle: String
        /// مفتاح الصلاة (rawValue) — للأيقونة واللون.
        var prayerKey: String
        /// موعد الأذان.
        var time: Date
        var place: String
    }

    var startedAt: Date
}
#endif
