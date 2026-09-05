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
    private static let jumuahId = "athar.jumuah"
    private static let fastingPrefix = "athar.fasting."
    private static let whitePrefix = "athar.white."
    private static let hadithPrefix = "athar.hadith."

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
        let preMinutes = store.preAthanMinutes
        // سقف iOS 64 إشعارًا معلّقًا للتطبيق كله. الأذان 5 في اليوم (10 مع تنبيه ما قبله)،
        // ومعه حديث اليوم والقيام والاستغفار والسنن والأذكار والورد؛ فالأفق 5 أيام
        // بلا تنبيهٍ قبليّ و3 معه، والجدولة تتجدّد عند كل فتح للتطبيق على كل حال.
        let iqamah = store.iqamahMinutes
        let extras = (preMinutes > 0 ? 1 : 0) + (iqamah > 0 ? 1 : 0)
        let days = extras == 0 ? 5 : (extras == 1 ? 3 : 2)

        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = store.prayerTimes(for: day) else { continue }

            for entry in times.ordered where entry.prayer.isPrayer {
                guard entry.date > now else { continue }

                let content = UNMutableNotificationContent()
                // العنوان اسم الصلاة وحده، والسطر الثاني نداؤها ومكانها ووقتها، والمتن آية
                // أو حديث ثابت يتبدّل مع الأيام — بدل «الرياض — حان وقت الظهر» الجافّة.
                content.title = entry.prayer.title
                content.subtitle = "حيّ على الصلاة · \(store.placeName) · \(clockText(entry.date, store: store))"
                content.body = athanBody(for: entry.prayer, dayOffset: dayOffset)
                content.sound = athanSound(store)
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

                // تنبيه الإقامة: بعد الأذان بدقائق يختارها المستخدم — نغمة النظام، وبادئة الأذان نفسها.
                if iqamah > 0 {
                    let iqDate = entry.date.addingTimeInterval(Double(iqamah) * 60)
                    if iqDate > now {
                        let iq = UNMutableNotificationContent()
                        iq.title = "إقامة \(entry.prayer.title)"
                        iq.subtitle = "\(store.placeName) · \(clockText(iqDate, store: store))"
                        iq.body = "قد قامت الصلاة — دع ما بيدك وقم إليها."
                        iq.sound = .default
                        iq.interruptionLevel = .timeSensitive
                        let iqComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: iqDate)
                        try? await center.add(UNNotificationRequest(
                            identifier: "\(athanPrefix)iq.\(dayOffset).\(entry.prayer.rawValue)",
                            content: iq,
                            trigger: UNCalendarNotificationTrigger(dateMatching: iqComps, repeats: false)))
                    }
                }

                // تنبيه الاستعداد قبل الأذان: بنغمة النظام لا بالأذان، حتى لا يظنّه
                // المستخدم دخولَ الوقت. يحمل بادئة الأذان نفسها فيُمحى معه.
                guard preMinutes > 0 else { continue }
                let preDate = entry.date.addingTimeInterval(-Double(preMinutes) * 60)
                guard preDate > now else { continue }

                let pre = UNMutableNotificationContent()
                pre.title = "\(entry.prayer.title) \(minutesPhrase(preMinutes))"
                pre.subtitle = "\(store.placeName) · \(clockText(entry.date, store: store))"
                pre.body = "توضّأ على مهلٍ واستعدّ — «الصلاة على وقتها» أحبّ الأعمال إلى الله."
                pre.sound = .default
                pre.interruptionLevel = .timeSensitive
                let preComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: preDate)
                let preRequest = UNNotificationRequest(
                    identifier: "\(athanPrefix)pre.\(dayOffset).\(entry.prayer.rawValue)",
                    content: pre,
                    trigger: UNCalendarNotificationTrigger(dateMatching: preComps, repeats: false)
                )
                try? await center.add(preRequest)
            }
        }
    }

    /// «بعد 5 دقائق» / «بعد 15 دقيقة»: تمييز العدد يتبدّل بعد العشرة.
    private static func minutesPhrase(_ n: Int) -> String {
        switch n {
        case 1:       return "بعد دقيقة"
        case 2:       return "بعد دقيقتين"
        case 3...10:  return "بعد \(n.counterText) دقائق"
        default:      return "بعد \(n.counterText) دقيقة"
        }
    }

    /// تذكير حديث اليوم: يُجدوَل كل يوم على حدة (لا تكرارًا) لأن نصّ الحديث
    /// يتغيّر مع اليوم، فيصل مع التنبيه الحديثُ نفسه الذي تعرضه البطاقة.
    static func rescheduleHadith(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(
            withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(hadithPrefix) })
        guard store.hadithReminder else { return }

        let calendar = Calendar.current
        let now = Date()
        let minutes = store.hadithReminderMinutes

        // أربعة أيام تكفي: الجدولة تتجدّد مع كل فتح، والسقف 64 مشترك مع الأذان.
        for dayOffset in 0..<4 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let fire = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                           second: 0, of: day),
                  fire > now,
                  let hadith = HadithLibrary.daily(for: day) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "حديث اليوم"
            content.subtitle = hadith.citation
            content.body = truncated(hadith.text, to: 180)
            content.sound = .default

            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let request = UNNotificationRequest(
                identifier: "\(hadithPrefix)\(dayOffset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            )
            try? await center.add(request)
        }
    }

    /// يقصّ النص عند آخر كلمة كاملة قبل الحدّ ويختمه بعلامة الحذف — لا يغيّر
    /// حرفًا مما بقي، فالحديث يصل بلفظه إلى حيث قُطع.
    private static func truncated(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let head = text.prefix(limit)
        if let cut = head.lastIndex(of: " ") {
            return String(head[..<cut]) + "…"
        }
        return String(head) + "…"
    }

    /// تذكير الورد اليومي من القرآن.
    static func rescheduleWird(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [wirdId])
        guard store.wirdEnabled else { return }
        await add(id: wirdId,
                  title: "وردك من القرآن",
                  // «10 آيات تكفيك» لا «10 آية»: تمييز العدد في Int.ayahCountText.
                  body: "\(store.wirdTarget.ayahCountText) تكفيك اليوم — «أحبُّ الأعمال إلى الله أدومها».",
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
            content.title = loc("ثلث الليل الآخر")
            content.body = "«ينزل ربنا إلى السماء الدنيا حين يبقى ثلث الليل الآخر فيقول: من يدعوني فأستجيب له»"
            content.sound = .default
            let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: q.lastThird)
            let r = UNNotificationRequest(identifier: "\(qiyamPrefix)\(day)", content: content,
                                          trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false))
            try? await UNUserNotificationCenter.current().add(r)
        }
    }

    /// تذكيرات السنن الأسبوعية والشهرية.
    static func rescheduleSunan(store: AtharStore) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers:
            pending.map(\.identifier).filter {
                $0 == jumuahId || $0.hasPrefix(jumuahId + ".") || $0.hasPrefix(fastingPrefix) || $0.hasPrefix(whitePrefix)
            })

        // الجمعة: قبل الظهر بساعة — الغسل والكهف والصلاة على النبي ﷺ. تُجدول للجُمَع الأربع
        // القادمة بوقت ظهر كل جمعة (لا ساعة ثابتة)، وتتجدّد مع كل فتح.
        if store.jumuahAlert {
            let cal = Calendar.current
            var scheduled = 0
            var day = Date()
            while scheduled < 4, let next = cal.date(byAdding: .day, value: 1, to: day) {
                day = next
                guard cal.component(.weekday, from: day) == 6,
                      let dhuhr = store.prayerTimes(for: day)?[.dhuhr] else { continue }
                let fire = dhuhr.addingTimeInterval(-3600)
                guard fire > Date() else { continue }
                let c = UNMutableNotificationContent()
                c.title = "جمعة مباركة"
                c.subtitle = "بعد ساعة تُقام الجمعة"
                c.body = "اغتسل وتطيّب، واقرأ سورة الكهف، وأكثِر من الصلاة على النبي ﷺ."
                c.sound = .default
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                try? await center.add(UNNotificationRequest(identifier: "\(jumuahId).\(scheduled)", content: c,
                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
                scheduled += 1
            }
        }

        // ليلة الاثنين والخميس 9 مساءً (الأحد 1 والأربعاء 4)
        if store.fastingAlert {
            for (wd, day) in [(1, "الاثنين"), (4, "الخميس")] {
                let c = UNMutableNotificationContent()
                c.title = "غدًا \(day)"
                c.body = "«تُعرض الأعمال يوم الاثنين والخميس، فأحب أن يُعرض عملي وأنا صائم» — انوِ الصيام."
                c.sound = .default
                var dc = DateComponents(); dc.weekday = wd; dc.hour = 21
                try? await center.add(UNNotificationRequest(identifier: "\(fastingPrefix)\(wd)",
                    content: c, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
            }
        }

        // الأيام البيض: مساء 12 هجري للأشهر الثلاثة القادمة
        if store.whiteDaysAlert {
            let hijri = Calendar(identifier: .islamicUmmAlQura)
            var cursor = Date()
            for i in 0..<3 {
                guard let eve = hijri.nextDate(after: cursor,
                        matching: DateComponents(day: 12, hour: 20), matchingPolicy: .nextTime)
                else { break }
                cursor = eve.addingTimeInterval(86400 * 3)
                let c = UNMutableNotificationContent()
                c.title = "الأيام البيض"
                c.body = "غدًا 13 من الشهر الهجري — صيام 13 و14 و15 كصيام الدهر."
                c.sound = .default
                let dc = Calendar.current.dateComponents([.year, .month, .day, .hour], from: eve)
                try? await center.add(UNNotificationRequest(identifier: "\(whitePrefix)\(i)",
                    content: c, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
            }
        }
    }

    /// يعيد جدولة كل التذكيرات دفعة واحدة.
    static func rescheduleAll(store: AtharStore) async {
        await reschedule(store: store)
        await rescheduleAthan(store: store)
        await rescheduleWird(store: store)
        await rescheduleIstighfar(store: store)
        await rescheduleQiyam(store: store)
        await rescheduleSunan(store: store)
        await rescheduleHadith(store: store)
    }

    /// وقت الأذان بأرقام لاتينية في منطقة المكان المختار.
    private static func clockText(_ date: Date, store: AtharStore) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = store.placeTimeZone
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    /// متن تنبيه الأذان: آيات وأحاديث ثابتة بلفظها من المصحف المضمَّن والصحيحين
    /// (نُسخت من مصادرها لا من الذاكرة)، تتبدّل مع الأيام كي لا يُملّ التنبيه.
    /// الفجر والعصر لهما نصّاهما الخاصّان.
    private static func athanBody(for prayer: Prayer, dayOffset: Int) -> String {
        let day = (Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0) + dayOffset
        switch prayer {
        case .fajr:
            return day.isMultiple(of: 2)
                ? "«رَكْعَتَا الْفَجْرِ خَيْرٌ مِنَ الدُّنْيَا وَمَا فِيهَا» — رواه مسلم"
                : "«مَنْ صَلَّى الْبَرْدَيْنِ دَخَلَ الْجَنَّةَ» — رواه البخاري"
        case .asr:
            return day.isMultiple(of: 2)
                ? "«مَنْ صَلَّى الْبَرْدَيْنِ دَخَلَ الْجَنَّةَ» — رواه البخاري"
                : "﴿حَٰفِظُوا۟ عَلَى ٱلصَّلَوَٰتِ وَٱلصَّلَوٰةِ ٱلْوُسْطَىٰ﴾ — البقرة: 238"
        default:
            let lines = [
                "﴿وَأَقِمِ ٱلصَّلَوٰةَ لِذِكْرِىٓ﴾ — طه: 14",
                "﴿إِنَّ ٱلصَّلَوٰةَ تَنْهَىٰ عَنِ ٱلْفَحْشَآءِ وَٱلْمُنكَرِ﴾ — العنكبوت: 45",
                "«مَثَلُ الصَّلَوَاتِ الْخَمْسِ كَمَثَلِ نَهَرٍ جَارٍ غَمْرٍ عَلَى بَابِ أَحَدِكُمْ يَغْتَسِلُ مِنْهُ كُلَّ يَوْمٍ خَمْسَ مَرَّاتٍ» — رواه مسلم",
                "﴿حَٰفِظُوا۟ عَلَى ٱلصَّلَوَٰتِ وَٱلصَّلَوٰةِ ٱلْوُسْطَىٰ﴾ — البقرة: 238",
            ]
            return lines[day % lines.count]
        }
    }

    /// صوت تنبيه الأذان الذي اختاره المستخدم — مقطع مضمَّن ≤ 30 ث، أو نغمة النظام.
    private static func athanSound(_ store: AtharStore) -> UNNotificationSound {
        // «نغمة النظام» = النغمة الافتراضية؛ الصوت الحرج يحتاج استحقاقًا من Apple لا نملكه،
        // ومن دونه لا يفعل شيئًا سوى إيهام القارئ بأنه يخترق الصامت.
        guard let name = store.athanSound.fileName else { return .default }
        return UNNotificationSound(named: UNNotificationSoundName(name + ".caf"))
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

// MARK: - خيارات التنبيه قبل الأذان

/// كم دقيقة يسبق تنبيهُ الاستعداد الأذانَ — صفر يعني لا تنبيه. القيمة الخام
/// هي الدقائق نفسها فتُخزَّن في المتجر مباشرةً بلا جدول تحويل.
/// تنبيه الإقامة بعد الأذان — خيارات بالدقائق.
enum IqamahChoice: Int, CaseIterable, Identifiable, SettingsChoice {
    case off = 0, m5 = 5, m10 = 10, m15 = 15, m20 = 20, m25 = 25, m30 = 30
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .off: return "بدون"
        case .m5:  return "بعد 5 دقائق"
        case .m10: return "بعد 10 دقائق"
        case .m15: return "بعد 15 دقيقة"
        case .m20: return "بعد 20 دقيقة"
        case .m25: return "بعد 25 دقيقة"
        case .m30: return "بعد 30 دقيقة"
        }
    }
    var shortTitle: String { title }
    var detail: String { self == .off ? "لا تنبيه للإقامة" : "تنبيه بنغمة النظام بعد الأذان بهذه المدة — اضبطه على عادة مسجدك" }
    static func from(minutes: Int) -> IqamahChoice { allCases.min { abs($0.rawValue - minutes) < abs($1.rawValue - minutes) } ?? .off }
}

enum PreAthanChoice: Int, CaseIterable, SettingsChoice {
    case off = 0
    case m5 = 5
    case m10 = 10
    case m15 = 15
    case m20 = 20
    case m30 = 30

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .off: return loc("بدون")
        case .m5:  return loc("قبل 5 دقائق")
        case .m10: return loc("قبل 10 دقائق")
        case .m15: return loc("قبل 15 دقيقة")
        case .m20: return loc("قبل 20 دقيقة")
        case .m30: return loc("قبل 30 دقيقة")
        }
    }

    var shortTitle: String { title }

    var detail: String {
        self == .off
            ? loc("تنبيه دخول الوقت فقط")
            : loc("تنبيه هادئ بنغمة النظام يسبق الأذان، للوضوء والتهيّؤ")
    }

    /// يطابق الدقائق المخزَّنة بأقرب خيار، فلا تنكسر القائمة لو تغيّرت القيمة من خارجها.
    static func from(minutes: Int) -> PreAthanChoice {
        allCases.first { $0.rawValue == minutes } ?? .off
    }
}
