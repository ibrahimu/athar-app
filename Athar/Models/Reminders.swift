import Foundation
import UserNotifications

/// Local-only reminders. No server, no tokens, nothing leaves the device.
enum Reminders {
    private static let morningId = "athar.reminder.morning"
    private static let eveningId = "athar.reminder.evening"
    private static let athanPrefix = "athar.athan."
    private static let wirdId = "athar.reminder.wird"
    private static let istighfarPrefix = "athar.istighfar."
    private static let qiyamPrefix = "athar.qiyam."

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func reschedule(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [morningId, eveningId])
        await rescheduleAthan(store: store)
        guard store.remindersEnabled else { return }

        await add(id: morningId,
                  title: "أذكار الصباح",
                  body: "﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾ — دقيقتان تكفيك اليوم كله.",
                  minutes: store.morningReminderMinutes)

        await add(id: eveningId,
                  title: "أذكار المساء",
                  body: "حصّن يومك قبل أن يغيب — أذكار المساء بانتظارك.",
                  minutes: store.eveningReminderMinutes)
    }

    /// Schedules the next few days of prayer alerts. iOS caps pending local
    /// notifications at 64, so we schedule 7 days x 5 prayers and refresh on launch.
    static func rescheduleAthan(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(athanPrefix) }
        )
        guard store.athanAlerts else { return }

        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = store.prayerTimes(for: day) else { continue }

            for entry in times.ordered where entry.prayer.isPrayer {
                guard entry.date > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "حان وقت \(entry.prayer.title)"
                content.body = "\(store.placeName) — أقم الصلاة، ولا تنسَ أذكار ما بعدها."
                content.sound = .defaultCritical
                // حسّاس للوقت: يخترق «عدم الإزعاج» وأوضاع التركيز، لأن
                // تنبيهًا يصل بعد فوات الوقت لا فائدة منه.
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0

                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.date)
                let request = UNNotificationRequest(
                    identifier: "\(athanPrefix)\(dayOffset).\(entry.prayer.rawValue)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    /// تذكير الورد اليومي من القرآن.
    static func rescheduleWird(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [wirdId])
        guard store.wirdEnabled else { return }
        await add(id: wirdId,
                  title: "وردك من القرآن",
                  body: "\(store.wirdTarget) آية تكفيك اليوم — «أحبُّ الأعمال إلى الله أدومها».",
                  minutes: store.wirdReminderMinutes)
    }

    /// تذكير الاستغفار على مدار اليوم — من الفجر إلى العشاء، بلا إزعاج ليلي.
    static func rescheduleIstighfar(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(istighfarPrefix) })
        guard store.istighfarAlerts else { return }

        let phrases = [
            ("أستغفر الله", "«وَٱسْتَغْفِرُوا۟ رَبَّكُمْ ثُمَّ تُوبُوٓا۟ إِلَيْهِ»"),
            ("سبحان الله وبحمده", "من قالها مئة مرة حُطَّت خطاياه وإن كانت مثل زبد البحر."),
            ("لا حول ولا قوة إلا بالله", "كنز من كنوز الجنة."),
            ("اللهم صلِّ على محمد", "من صلى عليَّ صلاة صلى الله عليه بها عشرًا."),
        ]
        let step = store.istighfarEveryHours
        var hour = 8
        var i = 0
        while hour <= 21 {
            let (title, body) = phrases[i % phrases.count]
            await add(id: "\(istighfarPrefix)\(hour)", title: title, body: body, minutes: hour * 60)
            hour += step; i += 1
        }
    }

    /// تنبيه قيام الليل عند دخول الثلث الأخير.
    static func rescheduleQiyam(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(qiyamPrefix) })
        guard store.qiyamAlert else { return }

        let cal = Calendar.current
        for day in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: day, to: Date()),
                  let t = store.prayerTimes(for: d),
                  let next = cal.date(byAdding: .day, value: 1, to: d),
                  let tm = store.prayerTimes(for: next), let fajr = tm[.fajr],
                  let q = t.qiyam(tomorrowFajr: fajr), q.lastThird > Date()
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "ثلث الليل الآخر"
            content.body = "«ينزل ربنا إلى السماء الدنيا حين يبقى ثلث الليل الآخر فيقول: من يدعوني فأستجيب له»"
            content.sound = .default
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: q.lastThird)
            let r = UNNotificationRequest(identifier: "\(qiyamPrefix)\(day)", content: content,
                                          trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false))
            try? await UNUserNotificationCenter.current().add(r)
        }
    }

    /// يعيد جدولة كل التذكيرات دفعة واحدة.
    static func rescheduleAll(store: AtharStore) async {
        await reschedule(store: store)
        await rescheduleAthan(store: store)
        await rescheduleWird(store: store)
        await rescheduleIstighfar(store: store)
        await rescheduleQiyam(store: store)
    }

    /// تنبيه تجريبي بعد ٥ ثوانٍ — ليتأكد المستخدم أن الإشعارات تعمل
    /// دون أن ينتظر دخول وقت صلاة.
    static func sendTestAlert() async -> Bool {
        guard await requestAuthorization() else { return false }
        let content = UNMutableNotificationContent()
        content.title = "تنبيه تجريبي"
        content.body = "هكذا سيصلك تنبيه دخول وقت الصلاة."
        content.sound = .defaultCritical
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(
            identifier: "athar.test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
        return true
    }

    /// عدد تنبيهات الأذان المجدولة فعليًا — للتشخيص في الإعدادات.
    static func scheduledAthanCount() async -> Int {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(athanPrefix) }.count
    }

    private static func add(id: String, title: String, body: String, minutes: Int) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
