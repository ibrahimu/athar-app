import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// النشاط الحيّ للصلاة القادمة (Dynamic Island وشاشة القفل).
/// يُزامَن عند كل عودة إلى التطبيق: يُنهي ما انقضى موعده أو تبدّلت حالته، ويطلب
/// نشاطًا واحدًا للصلاة القادمة. لا يرمي خطأً أبدًا — تعطيل المستخدم للأنشطة أو
/// رفض النظام (حدّ الأنشطة، أو إيقافها في الإعدادات) يُسكَتان بصمت.
/// هدف النشر iOS 17، فلا حاجة لحراسة #available(iOS 16.2) على واجهات ActivityKit.
@MainActor
enum LiveActivityManager {

    /// مهلة بعد الأذان يعدّ النظام بعدها النشاطَ قديمًا فيخفته ويطويه — تكفي لصلاة الجماعة.
    private static let staleGrace: TimeInterval = 15 * 60

    /// يُستدعى عند تنشيط المشهد ما دام المستخدم مفعّلًا للميزة.
    static func sync(store: AtharStore) {
        #if canImport(ActivityKit)
        Task { await refresh(store: store) }
        #endif
    }

    /// يُنهي كل الأنشطة القائمة — عند تعطيل الميزة من الإعدادات.
    static func endAll() {
        #if canImport(ActivityKit)
        Task { await end(Activity<NextPrayerAttributes>.activities) }
        #endif
    }

    #if canImport(ActivityKit)
    private static func refresh(store: AtharStore) async {
        let running = Activity<NextPrayerAttributes>.activities
        guard store.liveActivityEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              let up = store.upcomingPrayer(after: Date())
        else {
            await end(running)
            return
        }

        let state = NextPrayerAttributes.ContentState(prayerTitle: up.prayer.title,
                                                       prayerKey: up.prayer.rawValue,
                                                       time: up.date,
                                                       place: store.placeName)

        // نشاطٌ قائم بالحالة نفسها يبقى كما هو (لا نعيد طلبه فيومض)، وما سواه —
        // انقضى موعده، أو تبدّل المكان أو طريقة الحساب — يُنهى فورًا.
        var kept = false
        var stale: [Activity<NextPrayerAttributes>] = []
        for activity in running {
            if !kept, activity.activityState == .active, activity.content.state == state {
                kept = true
            } else {
                stale.append(activity)
            }
        }
        await end(stale)
        guard !kept else { return }

        let content = ActivityContent(state: state,
                                      staleDate: up.date.addingTimeInterval(staleGrace))
        do {
            _ = try Activity.request(attributes: NextPrayerAttributes(startedAt: Date()),
                                     content: content,
                                     pushType: nil)
        } catch {
            // الرفض ليس خطأً يُزعَج به المستخدم: يكفي أن يبقى التطبيق يعمل بلا نشاط.
        }
    }

    private static func end(_ activities: [Activity<NextPrayerAttributes>]) async {
        for activity in activities {
            await activity.end(ActivityContent(state: activity.content.state, staleDate: nil),
                               dismissalPolicy: .immediate)
        }
    }
    #endif
}
