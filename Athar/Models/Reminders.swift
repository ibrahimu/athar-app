import Foundation
import CoreLocation
import UserNotifications

/// Local-only reminders. No server, no tokens, nothing leaves the device.
@MainActor
enum Reminders {
    private static var planningDate = Date()
    private static var planned: [UNNotificationRequest] = []
    private static var scheduling = false
    private static var scheduleAgain = false
    static let coverageKey = "athar.notifications.coverage"

    // البادئات ليست خاصّة: مندوب الإشعارات يوجّه النقرة بها نفسها، فلا تُبنى في مكانين.
    static let morningId = "athar.reminder.morning"
    static let eveningId = "athar.reminder.evening"
    static let athanPrefix = "athar.athan."
    static let wirdId = "athar.reminder.wird"
    static let istighfarPrefix = "athar.istighfar."
    static let qiyamPrefix = "athar.qiyam."
    static let jumuahId = "athar.jumuah"
    static let fastingPrefix = "athar.fasting."
    static let whitePrefix = "athar.white."
    static let hadithPrefix = "athar.hadith."
    static let coverageId = "athar.coverage"

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// تقويم المكان المختار لا تقويم الجهاز: المواقيت تُحسب بمنطقة المدينة، فبناء
    /// مكوّنات المشغّل بمنطقة الجهاز يفتح فجوةً بين ما يُعرض وما يُطلق.
    private static func placeCalendar(_ store: AtharStore) -> Calendar {
        var calendar = Calendar.current
        calendar.timeZone = store.placeTimeZone
        return calendar
    }

    /// مكوّنات مشغّل مثبّتة على منطقة المكان. `UNCalendarNotificationTrigger` بلا منطقة
    /// يحلّ «الخامسة والنصف» بمنطقة الجهاز لحظة الإطلاق لا لحظة الجدولة: مسافرٌ
    /// جُدولت تنبيهاته في الرياض ثم هبط في القاهرة كان يسمع الأذان بفارق ساعة،
    /// والتطبيق مغلق فلا يبلغه إشعار تبدّل المنطقة الذي يلتقطه الجذر.
    /// (في وضع «موقعي الحالي» المنطقة هي منطقة الجهاز نفسها، والتثبيت يحفظ الموعد
    /// المحسوب لإحداثيات ذلك المكان حتى تصل قراءة موقع جديدة فتُعاد الجدولة.)
    private static func pinned(_ date: Date, _ calendar: Calendar) -> DateComponents {
        var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        comps.timeZone = calendar.timeZone
        return comps
    }

    private static func scheduleAdhkar(store: AtharStore) {
        guard store.remindersEnabled else { return }

        // بوقت الصلاة: الصباح بعد الفجر بعشرين دقيقة والمساء بعد العصر بعشرين — لأربعة أيام،
        // وتتجدّد مع كل فتح. (تُحتسب من سقف iOS الـ٦٤.)
        if store.adhkarReminderByPrayer {
            // موعدها مشتقّ من الفجر والعصر، فهي تتبع منطقة المكان لا منطقة الجهاز.
            let cal = placeCalendar(store)
            for dayOffset in 0..<4 {
                guard let day = cal.date(byAdding: .day, value: dayOffset, to: planningDate), let t = store.prayerTimes(for: day) else { continue }
                for (prayer, id, title, body) in [(Prayer.fajr, morningId, "أذكار الصباح", "﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾ — بعد الفجر أطيبُ وقتٍ لها."),
                                                   (Prayer.asr, eveningId, "أذكار المساء", "حصّن يومك قبل أن يغيب — أذكار المساء بانتظارك.")] {
                    guard let base = t[prayer] else { continue }
                    let fire = base.addingTimeInterval(20 * 60)
                    guard fire > planningDate else { continue }
                    let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
                    collect(UNNotificationRequest(identifier: "\(id).\(dayOffset)", content: c,
                        trigger: UNCalendarNotificationTrigger(dateMatching: pinned(fire, cal), repeats: false)))
                }
            }
            return
        }

        add(id: morningId,
                  title: "أذكار الصباح",
                  body: "﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾ — دقيقتان تكفيك اليوم كله.",
                  minutes: store.morningReminderMinutes)

        add(id: eveningId,
                  title: "أذكار المساء",
                  body: "حصّن يومك قبل أن يغيب — أذكار المساء بانتظارك.",
                  minutes: store.eveningReminderMinutes)
    }

    /// Schedules the next few days of prayer alerts. iOS caps pending local
    /// notifications at 64, so we schedule 7 days x 5 prayers and refresh on launch.
    private static func scheduleAthan(store: AtharStore) {
        guard store.athanAlerts else { return }

        let calendar = placeCalendar(store)
        let now = planningDate
        let preMinutes = store.preAthanMinutes
        let iqamah = store.iqamahMinutes
        let days = 7

        for dayOffset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let times = store.prayerTimes(for: day) else { continue }

            for entry in times.ordered where entry.prayer.isPrayer {
                guard entry.date > now else { continue }
                // تخصيص كل صلاة: قد تُعطَّل، أو تُنبَّه بنغمة النظام، أو صامتة، أو بتنبيه قبلي خاص.
                let prefs = store.prayerPrefs(entry.prayer)
                guard prefs.enabled else { continue }

                let content = UNMutableNotificationContent()
                // العنوان اسم الصلاة وحده، والسطر الثاني نداؤها ومكانها ووقتها، والمتن آية
                // أو حديث ثابت يتبدّل مع الأيام — بدل «الرياض — حان وقت الظهر» الجافّة.
                content.title = entry.prayer.title
                content.subtitle = "حيّ على الصلاة · \(store.placeName) · \(clockText(entry.date, store: store))"
                content.body = athanBody(for: entry.prayer, dayOffset: dayOffset)
                switch prefs.soundMode {
                case .athan:  content.sound = athanSound(store)
                case .system: content.sound = .default
                case .silent: content.sound = nil
                }
                // حسّاس للوقت: يخترق «عدم الإزعاج» وأوضاع التركيز. تنبيهات الوقت وحدها
                // تستحقّ هذا الاختراق — الأذان والإقامة والاستعداد يفوت وقتها فلا تُغني
                // بعده. أما الأذكار والحديث والاستغفار والورد والختمة فتبقى على المستوى
                // العادي: نداءٌ لا يفوت، ومن جعله يخترق تركيز صاحبه أفسد عليه المعنى
                // وعرّض الاستحقاق نفسه للسحب.
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0
                // بطاقة الأذان تحمل زرّيها، ومعها الصلاة ولحظتها: «صلّيتها في وقتها»
                // يسجّل في سجل الصلاة، والمعرّف وحده يحمل إزاحة يوم نسبية لا تاريخًا.
                content.categoryIdentifier = NotificationDelegate.athanCategory
                content.userInfo = [
                    NotificationDelegate.prayerKey: entry.prayer.rawValue,
                    NotificationDelegate.dateKey: entry.date.timeIntervalSinceReferenceDate,
                ]

                let request = UNNotificationRequest(
                    identifier: "\(athanPrefix)\(dayOffset).\(entry.prayer.rawValue)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: pinned(entry.date, calendar), repeats: false)
                )
                collect(request)

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
                        collect(UNNotificationRequest(
                            identifier: "\(athanPrefix)iq.\(dayOffset).\(entry.prayer.rawValue)",
                            content: iq,
                            trigger: UNCalendarNotificationTrigger(dateMatching: pinned(iqDate, calendar), repeats: false)))
                    }
                }

                // تنبيه الاستعداد قبل الأذان: بنغمة النظام لا بالأذان، حتى لا يظنّه
                // المستخدم دخولَ الوقت. يحمل بادئة الأذان نفسها فيُمحى معه.
                let effectivePre = prefs.preMinutes ?? preMinutes
                guard effectivePre > 0 else { continue }
                let preDate = entry.date.addingTimeInterval(-Double(effectivePre) * 60)
                guard preDate > now else { continue }

                let pre = UNMutableNotificationContent()
                pre.title = "\(entry.prayer.title) \(minutesPhrase(effectivePre))"
                pre.subtitle = "\(store.placeName) · \(clockText(entry.date, store: store))"
                pre.body = "توضّأ على مهلٍ واستعدّ — «الصلاة على وقتها» أحبّ الأعمال إلى الله."
                pre.sound = .default
                pre.interruptionLevel = .timeSensitive
                let preRequest = UNNotificationRequest(
                    identifier: "\(athanPrefix)pre.\(dayOffset).\(entry.prayer.rawValue)",
                    content: pre,
                    trigger: UNCalendarNotificationTrigger(dateMatching: pinned(preDate, calendar), repeats: false)
                )
                collect(preRequest)
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
    private static func scheduleHadith(store: AtharStore) {
        guard store.hadithReminder else { return }

        let calendar = Calendar.current
        let now = planningDate
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
            collect(request)
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
    private static func scheduleWird(store: AtharStore) {
        guard store.wirdEnabled else { return }
        add(id: wirdId,
                  title: "وردك من القرآن",
                  // «10 آيات تكفيك» لا «10 آية»: تمييز العدد في Int.ayahCountText.
                  body: "\(store.wirdTarget.ayahCountText) تكفيك اليوم — «أحبُّ الأعمال إلى الله أدومها».",
                  minutes: store.wirdReminderMinutes)
    }

    /// تذكير الاستغفار على مدار اليوم — من الفجر إلى العشاء، بلا إزعاج ليلي.
    private static func scheduleIstighfar(store: AtharStore) {
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
            add(id: "\(istighfarPrefix)\(hour)", title: title, body: body, minutes: hour * 60)
            hour += step; i += 1
        }
    }

    /// تنبيه قيام الليل عند دخول الثلث الأخير.
    private static func scheduleQiyam(store: AtharStore) {
        guard store.qiyamAlert else { return }

        // الثلث الأخير محسوب من مغرب المكان وفجره، فيتبع منطقته لا منطقة الجهاز.
        let cal = placeCalendar(store)
        for day in 0..<7 {
            guard let d = cal.date(byAdding: .day, value: day, to: planningDate),
                  let t = store.prayerTimes(for: d),
                  let next = cal.date(byAdding: .day, value: 1, to: d),
                  let tm = store.prayerTimes(for: next), let fajr = tm[.fajr],
                  let q = t.qiyam(tomorrowFajr: fajr), q.lastThird > planningDate
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = loc("ثلث الليل الآخر")
            content.body = "«ينزل ربنا إلى السماء الدنيا حين يبقى ثلث الليل الآخر فيقول: من يدعوني فأستجيب له»"
            content.sound = .default
            let r = UNNotificationRequest(identifier: "\(qiyamPrefix)\(day)", content: content,
                                          trigger: UNCalendarNotificationTrigger(dateMatching: pinned(q.lastThird, cal), repeats: false))
            collect(r)
        }
    }

    /// تذكيرات السنن الأسبوعية والشهرية.
    private static func scheduleSunan(store: AtharStore) {
        // الجمعة: قبل الظهر بساعة — الغسل والكهف والصلاة على النبي ﷺ. تُجدول للجُمَع الأربع
        // القادمة بوقت ظهر كل جمعة (لا ساعة ثابتة)، وتتجدّد مع كل فتح.
        if store.jumuahAlert {
            // موعدها ظهر الجمعة ناقصَ ساعة، ويومُها يوم المكان — فالتقويم تقويمه.
            let cal = placeCalendar(store)
            var scheduled = 0
            for offset in 0..<35 {
                guard scheduled < 4, let day = cal.date(byAdding: .day, value: offset, to: planningDate) else { break }
                guard cal.component(.weekday, from: day) == 6,
                      let dhuhr = store.prayerTimes(for: day)?[.dhuhr] else { continue }
                let fire = dhuhr.addingTimeInterval(-3600)
                guard fire > planningDate else { continue }
                let c = UNMutableNotificationContent()
                c.title = "جمعة مباركة"
                c.subtitle = "بعد ساعة تُقام الجمعة"
                c.body = "اغتسل وتطيّب، واقرأ سورة الكهف، وأكثِر من الصلاة على النبي ﷺ."
                c.sound = .default
                collect(UNNotificationRequest(identifier: "\(jumuahId).\(scheduled)", content: c,
                    trigger: UNCalendarNotificationTrigger(dateMatching: pinned(fire, cal), repeats: false)))
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
                collect(UNNotificationRequest(identifier: "\(fastingPrefix)\(wd)",
                    content: c, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
            }
        }

        // الأيام البيض: مساء 12 هجري للأشهر الثلاثة القادمة
        if store.whiteDaysAlert {
            let hijri = Calendar(identifier: .islamicUmmAlQura)
            var cursor = planningDate
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
                collect(UNNotificationRequest(identifier: "\(whitePrefix)\(i)",
                    content: c, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
            }
        }
    }

    /// جميع نقاط التغيير تمر بخطة واحدة حتى لا تتنافس مجموعات التنبيهات على سقف النظام.
    static func rescheduleAll(store: AtharStore) async {
        if scheduling { scheduleAgain = true; return }
        scheduling = true
        defer { scheduling = false }
        repeat {
            scheduleAgain = false
            let requests = makePlan(store: store)
            let center = UNUserNotificationCenter.current()
            let previous = await center.pendingNotificationRequests()
            // تأجيل المستخدم يُستثنى من الكنس: عمره عشر دقائق ويسقط بنفسه، ومحوُه
            // لمجرّد أن التطبيق فُتح يُضيع ما طلبه بيده قبل أن يبلغه.
            center.removePendingNotificationRequests(withIdentifiers: previous.map(\.identifier)
                .filter { $0.hasPrefix("athar.") && !$0.hasPrefix(NotificationDelegate.snoozePrefix) })
            for request in requests {
                do { try await center.add(request) }
                catch { store.defaults.removeObject(forKey: coverageKey) }
            }
            let saved = await center.pendingNotificationRequests()
            let lastPrayer = saved.filter { isPrayerAlert($0) }.compactMap { fireDate($0) }.max()
            if let lastPrayer { store.defaults.set(lastPrayer, forKey: coverageKey) }
            else { store.defaults.removeObject(forKey: coverageKey) }
            store.objectWillChange.send()
        } while scheduleAgain
    }

    static func makePlan(store: AtharStore, now: Date = Date()) -> [UNNotificationRequest] {
        planningDate = now
        planned = []
        scheduleAdhkar(store: store)
        scheduleAthan(store: store)
        scheduleWird(store: store)
        scheduleIstighfar(store: store)
        scheduleQiyam(store: store)
        scheduleSunan(store: store)
        scheduleHadith(store: store)
        let chronological = planned.sorted {
            (fireDate($0) ?? .distantFuture) < (fireDate($1) ?? .distantFuture)
        }
        // نضمن أقرب 25 أذانًا أولًا؛ ثم نملأ البقية بالتذكيرات الأقرب موعدًا.
        let prayers = Array(chronological.filter(isPrayerAlert).prefix(25))
        let ids = Set(prayers.map(\.identifier))
        let others = chronological.filter { !ids.contains($0.identifier) }
        var result = prayers + others.prefix(63 - prayers.count)
        // تذكير واضح قبل نهاية التغطية: التجديد الخلفي يسدّ الثغرة غالبًا، لكن النظام
        // لا يعد به — فيبقى النداء اليدويّ آخر ضمانة قبل أن ينقطع الأذان.
        if let last = prayers.last.flatMap(fireDate) {
            let fire = max(planningDate.addingTimeInterval(60), last.addingTimeInterval(-6 * 3600))
            let content = UNMutableNotificationContent()
            content.title = "جدّد تنبيهات الصلاة"
            content.body = "افتح أثر لتحديث مواقيت الأيام القادمة واستمرار التنبيهات."
            content.sound = .default
            result.append(UNNotificationRequest(identifier: coverageId, content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: pinned(fire, placeCalendar(store)), repeats: false)))
        }
        planned = []
        return result
    }

    private static func fireDate(_ request: UNNotificationRequest) -> Date? {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
    }

    private static func isPrayerAlert(_ request: UNNotificationRequest) -> Bool {
        request.identifier.hasPrefix(athanPrefix) && !request.identifier.hasPrefix(athanPrefix + "pre.") && !request.identifier.hasPrefix(athanPrefix + "iq.")
    }

    private static func collect(_ request: UNNotificationRequest) { planned.append(request) }

    // MARK: - مراقبة تبدّل المكان

    /// بصمة المكان: ما تتغيّر به المواقيت وحده — لا اسم المدينة ولا شيء من الزينة.
    private struct Place: Equatable {
        let lat: Double, lon: Double
        let zone: String
        let device: Bool
    }

    private static var placeWatcher: NSObjectProtocol?
    private static var placeWatchTask: Task<Void, Never>?
    private static var lastPlace: Place?

    private static func placeFingerprint(_ store: AtharStore) -> Place {
        let c = store.coordinate
        return Place(lat: c.latitude, lon: c.longitude,
                     zone: store.placeTimeZone.identifier, device: store.usesDeviceLocation)
    }

    /// نقطة اختناق واحدة لتبدّل المكان. `setCity` و`setDeviceLocation` وشريط المسافر
    /// وقائمة المدن كلّها تكتب في التفضيلات المشتركة ولا يُعيد أكثرها الجدولة، فكان
    /// الأذان يظلّ ينادي بتوقيت المدينة السابقة حتى يفتح المستخدم شاشةً تُجدول من نفسها.
    /// و`AtharStore` في Shared تُبنى للودجة والساعة أيضًا فلا تعرف المُجدوِل ولا تستدعيه —
    /// فنُنصت هنا لكتابتها بدل نثر النداءات في كل شاشة تلمس الموقع.
    static func startWatchingPlace(store: AtharStore) {
        guard placeWatcher == nil else { return }
        lastPlace = placeFingerprint(store)
        placeWatcher = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: store.defaults, queue: .main
        ) { _ in
            Task { @MainActor in placeDidChange(store: store) }
        }
    }

    private static func placeDidChange(store: AtharStore) {
        let now = placeFingerprint(store)
        // الإشعار يصل مع كل كتابة (وعدّاد المسبحة يكتب مع كل ضغطة)، فالمقارنة أوّلًا.
        guard now != lastPlace else { return }
        lastPlace = now
        placeWatchTask?.cancel()
        placeWatchTask = Task { @MainActor in
            // `setCity` تكتب ستّ قيم متتابعة؛ ننتظر لحظةً كي تستقرّ فتُبنى خطة واحدة.
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await rescheduleAll(store: store)
        }
    }

    static func reschedule(store: AtharStore) async { await rescheduleAll(store: store) }
    static func rescheduleAthan(store: AtharStore) async { await rescheduleAll(store: store) }
    static func rescheduleHadith(store: AtharStore) async { await rescheduleAll(store: store) }
    static func rescheduleWird(store: AtharStore) async { await rescheduleAll(store: store) }
    static func rescheduleIstighfar(store: AtharStore) async { await rescheduleAll(store: store) }
    static func rescheduleQiyam(store: AtharStore) async { await rescheduleAll(store: store) }
    static func rescheduleSunan(store: AtharStore) async { await rescheduleAll(store: store) }


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
        let day = (Calendar.current.ordinality(of: .day, in: .era, for: planningDate) ?? 0) + dayOffset
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

    /// تذكير بساعةٍ يختارها المستخدم (الأذكار والورد والاستغفار). لا يُثبَّت على منطقة
    /// المكان قصدًا: من ضبط ورده على السابعة أرادها سابعةَ يومه أينما حلّ، لا سابعةَ
    /// المدينة التي يحسب بها المواقيت. وكذلك حديث اليوم وصيام الاثنين والخميس والأيام
    /// البيض — مواعيد يوميّة لا تعلّق لها بشمس المكان.
    private static func add(id: String, title: String, body: String, minutes: Int) {
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
        collect(request)
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
