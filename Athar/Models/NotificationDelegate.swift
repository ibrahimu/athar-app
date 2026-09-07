import Foundation
import UserNotifications

/// مندوب الإشعارات: يُظهر التنبيه ولو كان التطبيق مفتوحًا، ويوجّه النقر إلى قسمه،
/// ويستقبل زرّي بطاقة الأذان. يُنصَّب في `AppDelegate` قبل أن يعود بـ`true`، لأن
/// الإقلاع البارد من نقرة إشعار يسلّمها النظام للمندوب في اللحظة نفسها — ومن نصّبه
/// بعد ذلك فقد النقرة التي أيقظت التطبيق.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    /// فئة بطاقة الأذان ومفاتيح ما تحمله. غير معزولة عن الفاعل الرئيس عمدًا:
    /// `Reminders` يكتبها في المحتوى، والمندوب يقرؤها من خارج الخيط الرئيس.
    static let athanCategory = "athar.athan"
    static let prayedAction = "athar.action.prayed"
    static let snoozeAction = "athar.action.snooze"
    static let prayerKey = "athar.prayer"
    static let dateKey = "athar.at"
    /// بادئة «athar.» تُدخل التأجيل في نطاق التطبيق فيُدار مع بقيّة تنبيهاته.
    static let snoozePrefix = "athar.snooze."

    /// دقائق التأجيل حين يقول المستخدم «ذكّرني بعد 10 دقائق».
    private static let snoozeMinutes = 10

    /// زرّان تحت بطاقة الأذان: تسجيلٌ في السجل بلا فتح التطبيق، وتأجيلٌ قصير.
    /// كلاهما بلا `.foreground` — يُنفَّذان والتطبيق في الخلفية، فلا يُقطع على
    /// المستخدم ما هو فيه لتسجيل ركعةٍ صلّاها.
    static func makeCategories() -> Set<UNNotificationCategory> {
        let prayed = UNNotificationAction(identifier: prayedAction,
                                          title: loc("صلّيتها في وقتها"), options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction,
                                          title: loc("ذكّرني بعد 10 دقائق"), options: [])
        return [UNNotificationCategory(identifier: athanCategory,
                                       actions: [prayed, snooze],
                                       intentIdentifiers: [],
                                       options: [])]
    }

    // MARK: - العرض والتطبيق مفتوح

    /// بلا هذا يبتلع النظام الإشعار حين يكون التطبيق في المقدّمة: كان الأذان يمرّ
    /// صامتًا على من فتح المصحف لحظة دخول الوقت. البانر والصوت والقائمة معًا —
    /// يُرى ويُسمع ويبقى في مركز الإشعارات.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    // MARK: - النقر والأزرار

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        let action = response.actionIdentifier
        let prayer = Self.prayer(in: response.notification.request.content.userInfo)
        let moment = Self.moment(in: response.notification.request.content.userInfo)

        Task { @MainActor in
            switch action {
            case Self.prayedAction:
                Self.recordOnTime(prayer: prayer, at: moment)
            case Self.snoozeAction:
                await Self.snooze(prayer: prayer)
            case UNNotificationDefaultActionIdentifier:
                // النقر على البطاقة نفسها: وجهةٌ معلّقة يستهلكها الجذر متى رُسم.
                if let tab = Self.tab(for: identifier) {
                    AtharStore.shared.pendingRoute = .tab(tab)
                }
            default:
                // المسح من مركز الإشعارات ليس طلبَ فتح — لا يُنقل المستخدم من مكانه.
                break
            }
            completionHandler()
        }
    }

    // MARK: - قراءة ما يحمله التنبيه

    private static func prayer(in userInfo: [AnyHashable: Any]) -> Prayer? {
        guard let raw = userInfo[prayerKey] as? String else { return nil }
        return Prayer(rawValue: raw)
    }

    /// لحظة الأذان كما جُدولت. المعرّف يحمل إزاحة يومٍ نسبيةً لا تاريخًا، فلا يُستدلّ
    /// به على اليوم بعد أن يتقدّم الزمن.
    private static func moment(in userInfo: [AnyHashable: Any]) -> Date {
        guard let stamp = userInfo[dateKey] as? Double else { return Date() }
        return Date(timeIntervalSinceReferenceDate: stamp)
    }

    // MARK: - «صلّيتها في وقتها»

    @MainActor
    private static func recordOnTime(prayer: Prayer?, at moment: Date) {
        guard let prayer else { return }
        AtharStore.shared.setPrayerStatus(.onTime, for: prayer, on: moment)
    }

    // MARK: - «ذكّرني بعد 10 دقائق»

    /// تنبيه واحد بعد عشر دقائق، بمعرّفٍ يحمل اسم الصلاة: تأجيلٌ ثانٍ لنفس الصلاة
    /// يحلّ محلّ الأول فلا يتراكم على المستخدم نداءان.
    @MainActor
    private static func snooze(prayer: Prayer?) async {
        guard let prayer else { return }
        let content = UNMutableNotificationContent()
        content.title = loc("تذكير %1$@", prayer.title)
        content.body = loc("مرّت 10 دقائق — قم إليها قبل أن يخرج وقتها.")
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = athanCategory
        content.userInfo = [prayerKey: prayer.rawValue,
                            dateKey: Date().timeIntervalSinceReferenceDate]

        let request = UNNotificationRequest(
            identifier: "\(snoozePrefix)\(prayer.rawValue)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(snoozeMinutes) * 60, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - الوجهة من المعرّف

    /// البادئات هي بادئات `Reminders` نفسها — لا جدول موازٍ يفترق عنها مع أول تعديل.
    @MainActor
    private static func tab(for identifier: String) -> AppTab? {
        if identifier.hasPrefix(Reminders.athanPrefix)     // الأذان والإقامة والاستعداد
            || identifier.hasPrefix(snoozePrefix)
            || identifier.hasPrefix(Reminders.qiyamPrefix)
            || identifier.hasPrefix(Reminders.coverageId) { return .prayer }
        if identifier.hasPrefix(Reminders.morningId) || identifier.hasPrefix(Reminders.eveningId) { return .adhkar }
        if identifier.hasPrefix(Reminders.wirdId) { return .wird }
        if identifier.hasPrefix(Reminders.khatmahPrefix) { return .khatmah }
        if identifier.hasPrefix(Reminders.hadithPrefix) { return .hadith }
        if identifier.hasPrefix(Reminders.istighfarPrefix) { return .tasbih }
        if identifier.hasPrefix(Reminders.jumuahId)
            || identifier.hasPrefix(Reminders.fastingPrefix)
            || identifier.hasPrefix(Reminders.whitePrefix) { return .sunan }
        return nil
    }
}
