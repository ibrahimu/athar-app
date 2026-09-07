import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// النشاط الحيّ للصلاة القادمة (Dynamic Island وشاشة القفل).
/// يُزامَن عند كل عودة إلى التطبيق: يُنهي ما انقضى موعده أو تبدّلت حالته، ويطلب
/// نشاطًا واحدًا للصلاة القادمة إن كان أذانها قريبًا. لا يرمي خطأً أبدًا — تعطيل
/// المستخدم للأنشطة أو رفض النظام (حدّ الأنشطة، أو إيقافها في الإعدادات) يُسكَتان بصمت.
/// هدف النشر iOS 17، فلا حاجة لحراسة #available(iOS 16.2) على واجهات ActivityKit.
@MainActor
enum LiveActivityManager {

    /// لا يُطلب النشاط إلا إذا كان الأذان القادم خلال هذه المهلة أو أقل: طلبه لصلاةٍ بعد
    /// خمس ساعات يُبقي عدًّا على شاشة القفل والجزيرة طوال اليوم، فيبدو للمستخدم أن
    /// التطبيق لا يهدأ. خارج النافذة تُنهى الأنشطة القائمة ويُنتظر تنشيطٌ لاحق.
    /// نصف ساعة لا أكثر: النشاط لا يُنهى آليًّا بعد الأذان (انظر staleDate أدناه)، فكلّما
    /// ضاقت النافذة قلّت المدة التي قد يبقى فيها يتيمًا على شاشة القفل.
    static let requestWindow: TimeInterval = 30 * 60

    /// تاريخ القِدَم (staleDate) هو الأذان نفسه. لا يُنهي النظامُ النشاطَ عنده ولا يطويه:
    /// يعلّمه قديمًا (activityState = .stale، وisStale في الامتداد) فيعرض الامتداد
    /// «حان وقت …» بدل عدٍّ صفري وشريطٍ ممتلئ. ولا مؤقّتات خلفية عندنا، فلا يُنهى إلا عند
    /// التنشيط التالي للتطبيق (refresh يُنهي ما ليس .active) أو ببلوغ حدّ النظام.

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
        let now = Date()
        guard store.liveActivityEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              let up = store.upcomingPrayer(after: now),
              up.date.timeIntervalSince(now) <= requestWindow
        else {
            await end(running)
            return
        }

        // لحظة اليوم الآن — الاشتقاق نفسه الذي تلوّن به ويدجتات الشاشة الرئيسية خلفياتها،
        // فتتطابق شاشة القفل معها. تُحمل في الحالة لأن الامتداد لا يُعيد الرسم من تلقاء نفسه.
        let moment = AtharStyle.Moment.resolved(at: now, times: store.prayerTimes(for: now))
        let state = NextPrayerAttributes.ContentState(prayerTitle: up.prayer.title,
                                                       prayerKey: up.prayer.rawValue,
                                                       time: up.date,
                                                       place: store.placeName,
                                                       momentKey: moment.activityKey)

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

        let content = ActivityContent(state: state, staleDate: up.date)
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
