import XCTest
import CoreLocation
import UserNotifications
@testable import Athar

// MARK: - جهازٌ في الرياض ومكانٌ في سان فرانسيسكو

/// جاء بلاغُ مصلٍّ: شاشة قفله تقول «الفجر — سان فرانسيسكو — 3:14 م»، وتنبيهه يقول
/// «الظهر … 11:08 م». والفارق بين ما رآه وما كان ينبغي عشرُ ساعاتٍ بحذافيرها — وهي
/// بعينها المسافة بين الرياض وسان فرانسيسكو. فاللحظة كانت صوابًا، والساعةُ التي
/// قرأتها كانت ساعةَ الجهاز لا ساعة المدينة.
///
/// فهذه الاختبارات تحرس حدًّا واحدًا: يُحسب الوقت بمنطقة المكان، ويُقرأ بمنطقته
/// أيضًا، مهما كانت الأرض التي يقف عليها صاحب الجهاز.
final class TimeZoneTests: XCTestCase {

    private let sanFrancisco = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    private let placeZone = TimeZone(identifier: "America/Los_Angeles")!
    private let deviceZone = TimeZone(identifier: "Asia/Riyadh")!
    /// ما يلبسه التطبيق كله: عربيةٌ بأرقام غربية — فالمقارنة هنا على ما يراه المستخدم لا على أرقامٍ مجرّدة.
    private let arabicLatin = Locale(identifier: "ar_SA@numbers=latn")
    private let suiteName = "athar.tests.timezone"

    private var deviceZoneBeforeTest: TimeZone?

    override func setUp() {
        super.setUp()
        // نُجلس الجهاز في الرياض قصدًا: أيّ عرضٍ يتسلّل إلى `TimeZone.current` يفتضح هنا لا في يد مستخدم.
        deviceZoneBeforeTest = NSTimeZone.default
        NSTimeZone.default = deviceZone
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        if let zone = deviceZoneBeforeTest { NSTimeZone.default = zone }
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: أدوات

    /// الخامس من سبتمبر ٢٠٢٦ في سان فرانسيسكو بعد منتصف ليلها بنصف ساعة. لحظةٌ مسمّرة:
    /// اختبارٌ يتّكئ على «الآن» يمرّ اليوم ويسقط غدًا، ويومٌ كامل أمامها فتقع صلواته
    /// الخمس كلها في المستقبل حين نبني خطة التنبيهات.
    private var anchor: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = placeZone
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 5, hour: 0, minute: 30))!
    }

    /// مخزنٌ معزول يحمل سان فرانسيسكو بمنطقتها. نكتب المفاتيح المشتركة نفسها التي
    /// تكتبها `setCity` ويقرؤها المخزن والودجة والساعة، لأن المدينة ليست في `City.all`
    /// — والبلاغ جاء من مكانٍ خارجها.
    private func storeInSanFrancisco() -> AtharStore {
        let defaults = UserDefaults(suiteName: suiteName)!
        let store = AtharStore(defaults: defaults)
        defaults.set(sanFrancisco.latitude, forKey: "athar.latitude")
        defaults.set(sanFrancisco.longitude, forKey: "athar.longitude")
        defaults.set("سان فرانسيسكو", forKey: "athar.placeName")
        defaults.set(placeZone.identifier, forKey: "athar.placeTimeZone")
        defaults.set(false, forKey: "athar.usesDeviceLocation")
        defaults.removeObject(forKey: "athar.cityId")
        return store
    }

    /// وصفة العرض التي يتشارك فيها كل سطحٍ يذكر وقت أذان: الشاشات والودجات والنشاط الحيّ والتنبيهات.
    private func clock(_ date: Date, in zone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = arabicLatin
        f.dateFormat = "h:mm a"
        f.timeZone = zone
        return f.string(from: date)
    }

    /// ختمٌ ثابت لا تعبث به لغة الجهاز ولا تقويمه — للحكم على اليوم والساعة بلا لَبْس.
    private func stamp(_ date: Date, in zone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = zone
        return f.string(from: date)
    }

    /// علامتا الصباح والمساء كما ينطق بهما التطبيق («ص» و«م») — تُؤخذ من المنسّق نفسه
    /// لا تُكتب بأيدينا، فرموز اللغات تتبدّل مع نسخ النظام والاختبار لا ينبغي أن يتبدّل معها.
    private var dayMarks: (morning: String, evening: String) {
        let f = DateFormatter()
        f.locale = arabicLatin
        return (f.amSymbol ?? "AM", f.pmSymbol ?? "PM")
    }

    private func hour(_ date: Date, in zone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.component(.hour, from: date)
    }

    private func day(_ date: Date, in zone: TimeZone) -> String {
        String(stamp(date, in: zone).prefix(10))
    }

    // MARK: الحساب

    /// أول ما يُطمأنّ إليه: الحساب نفسه سليم. فجرُ سان فرانسيسكو فجرٌ بساعتها، وظهرها ظهرٌ بساعتها.
    func testFajrIsMorningAndDhuhrIsMiddayInTheCityZone() throws {
        let store = storeInSanFrancisco()
        let times = try XCTUnwrap(store.prayerTimes(for: anchor), "مواقيت سان فرانسيسكو")
        let fajr = try XCTUnwrap(times[.fajr])
        let dhuhr = try XCTUnwrap(times[.dhuhr])

        XCTAssertTrue((3...7).contains(hour(fajr, in: placeZone)),
                      "الفجر بساعة المدينة: \(stamp(fajr, in: placeZone))")
        XCTAssertTrue((11...14).contains(hour(dhuhr, in: placeZone)),
                      "الظهر بساعة المدينة: \(stamp(dhuhr, in: placeZone))")
        XCTAssertTrue(clock(fajr, in: placeZone).hasSuffix(dayMarks.morning),
                      "الفجر صباحٌ لا مساء: \(clock(fajr, in: placeZone))")
        XCTAssertTrue(clock(dhuhr, in: placeZone).hasSuffix(dayMarks.evening),
                      "الظهر بعد الزوال: \(clock(dhuhr, in: placeZone))")
        XCTAssertLessThan(fajr, dhuhr)
    }

    /// يوم المدينة يبقى يومًا واحدًا بساعتها، ويتمزّق بساعة الجهاز — فالعصر والمغرب
    /// والعشاء تنزلق إلى الغد في الرياض. جدولٌ يُعرض بمنطقة الجهاز لا يخطئ الساعة وحدها بل التاريخ.
    func testTheCityDayStaysWholeInItsOwnZone() throws {
        let store = storeInSanFrancisco()
        let times = try XCTUnwrap(store.prayerTimes(for: anchor))

        for (prayer, date) in times.ordered {
            XCTAssertEqual(day(date, in: placeZone), "2026-09-05",
                           "\(prayer.rawValue) خرج من يوم المدينة: \(stamp(date, in: placeZone))")
        }
        XCTAssertTrue(times.ordered.contains { day($0.date, in: deviceZone) != "2026-09-05" },
                      "بساعة الجهاز ينبغي أن ينزلق بعضُ اليوم إلى الغد — وإلا فالمنطقتان واحدة والاختبار لا يقيس شيئًا")
    }

    // MARK: شاهد العطب

    /// إعادة بناء ما رآه المُبلِّغ: اللحظة نفسها مقروءةً بساعة الرياض تصير «3:1x م» للفجر
    /// و«11:0x م» للظهر. تبقى هذه هنا شاهدًا: إن سقط هذا الفرق يومًا فقد تبدّل الحساب لا العرض.
    func testDeviceZoneReadingReproducesTheReportedAfternoonFajr() throws {
        let store = storeInSanFrancisco()
        let times = try XCTUnwrap(store.prayerTimes(for: anchor))
        let fajr = try XCTUnwrap(times[.fajr])
        let dhuhr = try XCTUnwrap(times[.dhuhr])

        XCTAssertEqual(deviceZone.secondsFromGMT(for: fajr) - placeZone.secondsFromGMT(for: fajr),
                       10 * 3600, "بين الرياض وسان فرانسيسكو عشر ساعات في هذا اليوم")
        XCTAssertGreaterThanOrEqual(hour(fajr, in: deviceZone), 12,
                                    "الفجر بساعة الجهاز يقع بعد الظهيرة — وهذا ما اشتكى منه: \(clock(fajr, in: deviceZone))")
        XCTAssertTrue(clock(fajr, in: deviceZone).hasSuffix(dayMarks.evening),
                      "شاهدُ العطب: الفجر يُقرأ مساءً بساعة الجهاز — \(clock(fajr, in: deviceZone))")
        XCTAssertGreaterThanOrEqual(hour(dhuhr, in: deviceZone), 22,
                                    "الظهر بساعة الجهاز يقارب منتصف الليل: \(clock(dhuhr, in: deviceZone))")
        XCTAssertNotEqual(clock(fajr, in: deviceZone), clock(fajr, in: placeZone),
                          "لو تساوت القراءتان لما أمسك هذا الملف عطبًا")
    }

    // MARK: المخزن

    /// المنطقة المخزَّنة للمكان لا تتبع الجهاز: هي التي يُحسب بها ويُعرض بها في كل سطح.
    func testStoreKeepsTheCityZoneWhileTheDeviceSitsInRiyadh() {
        let store = storeInSanFrancisco()
        XCTAssertEqual(store.placeTimeZone.identifier, placeZone.identifier)
        XCTAssertEqual(TimeZone.current.identifier, deviceZone.identifier,
                       "هذا الاختبار يفترض جهازًا في الرياض")
        XCTAssertNotEqual(store.placeTimeZone.identifier, TimeZone.current.identifier)
    }

    /// مدينةٌ من القائمة تحمل منطقتها معها — لا منطقة من اختارها.
    func testSetCityCarriesItsOwnZone() throws {
        let store = AtharStore(defaults: UserDefaults(suiteName: suiteName)!)
        let newYork = try XCTUnwrap(City.named("newyork"))
        store.setCity(newYork)

        XCTAssertEqual(store.placeTimeZone.identifier, "America/New_York")
        let times = try XCTUnwrap(store.prayerTimes(for: anchor))
        let dhuhr = try XCTUnwrap(times[.dhuhr])
        XCTAssertTrue((11...14).contains(hour(dhuhr, in: newYork.timeZone)),
                      "ظهر نيويورك بساعتها: \(stamp(dhuhr, in: newYork.timeZone))")
        XCTAssertFalse((11...14).contains(hour(dhuhr, in: deviceZone)),
                       "وبساعة الجهاز ليس ظهرًا: \(stamp(dhuhr, in: deviceZone))")
    }

    /// ما يُحمل إلى الساعة يحمل معه منطقة المكان، وإلا حسبت الساعةُ بأرضٍ وعرضت بأخرى.
    func testWatchContextCarriesTheCityZone() throws {
        let store = storeInSanFrancisco()
        let context = store.watchContext
        XCTAssertEqual(context["tz"] as? String, placeZone.identifier)
        XCTAssertEqual(context["lat"] as? Double, sanFrancisco.latitude)
        XCTAssertEqual(context["lng"] as? Double, sanFrancisco.longitude)
    }

    // MARK: سطح العرض في التطبيق

    /// `PrayerView.time` هو ما تكتب به شاشتا «اليوم» و«الصلاة» كل وقت. لو أهمل منطقته
    /// يومًا وأخذ منطقة الجهاز، سقط هنا: القراءتان لا تتفقان أبدًا في هذه المسافة.
    func testDisplayHelperShowsTheCityWallClockNotTheDevices() throws {
        let store = storeInSanFrancisco()
        let times = try XCTUnwrap(store.prayerTimes(for: anchor))

        for prayer in Prayer.allCases {
            let date = try XCTUnwrap(times[prayer])
            XCTAssertEqual(PrayerView.time(date, in: store.placeTimeZone), clock(date, in: placeZone),
                           "\(prayer.rawValue) ينبغي أن يُقرأ بساعة المدينة")
            XCTAssertNotEqual(PrayerView.time(date, in: store.placeTimeZone), clock(date, in: deviceZone),
                              "\(prayer.rawValue) قُرئ بساعة الجهاز")
        }
    }

    // MARK: سطح التنبيهات

    /// صلاةٌ واحدة تُترك عاملة والبقية تُطفأ. الخطة تُقصّ عند سقف النظام بترتيبٍ مبنيّ
    /// على `nextTriggerDate()`، وهو يخلو من المعنى لتاريخٍ مسمّر في الماضي — فنُبقي
    /// الخطة أصغر من السقف كي لا يقصّ القصُّ ما نبحث عنه.
    private func silenceEveryPrayer(except kept: Prayer, in store: AtharStore) {
        for prayer in Prayer.allCases where prayer.isPrayer && prayer != kept {
            store.setPrayerPrefs(AtharStore.PrayerAlertPrefs(enabled: false), for: prayer)
        }
    }

    /// متن تنبيه الأذان ومشغّله معًا. البلاغ الثاني كان من هنا: «الظهر … 11:08 م».
    /// نتحقق من السطر الذي يقرؤه المستخدم، ومن مكوّنات المشغّل التي يُطلق بها النظام —
    /// فلا يكفي أن يصدق النصّ ويكذب الموعد.
    @MainActor
    func testAthanNotificationSubtitleAndTriggerFollowTheCityZone() throws {
        let store = storeInSanFrancisco()
        store.athanAlerts = true
        silenceEveryPrayer(except: .dhuhr, in: store)
        let times = try XCTUnwrap(store.prayerTimes(for: anchor))
        let dhuhr = try XCTUnwrap(times[.dhuhr])

        let plan = Reminders.makePlan(store: store, now: anchor)
        let request = try XCTUnwrap(plan.first { $0.identifier == Reminders.athanPrefix + "0.dhuhr" },
                                    "خطةٌ بلا أذان ظهر: \(plan.map(\.identifier))")

        let subtitle = request.content.subtitle
        XCTAssertTrue(subtitle.contains(clock(dhuhr, in: placeZone)),
                      "سطر التنبيه لا يحمل ساعة المدينة: \(subtitle)")
        XCTAssertFalse(subtitle.contains(clock(dhuhr, in: deviceZone)),
                       "سطر التنبيه يحمل ساعة الجهاز: \(subtitle)")
        XCTAssertTrue(subtitle.contains("سان فرانسيسكو"), subtitle)

        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        let components = trigger.dateComponents
        XCTAssertEqual(components.timeZone?.identifier, placeZone.identifier,
                       "مشغّلٌ بلا منطقة يُحلّ بمنطقة الجهاز لحظة الإطلاق")
        XCTAssertEqual(components.hour, hour(dhuhr, in: placeZone))
        // التقويم يُحمل مع المكوّنات، فنُعيد البناء به هو — جهاز إقليمه هجريّ يستخرج غير ما نستخرج.
        let calendar = try XCTUnwrap(components.calendar)
        XCTAssertEqual(calendar.date(from: components), dhuhr,
                       "المشغّل لا يقع على لحظة الأذان نفسها")
    }

    /// التنبيه القبليّ والإقامة يتفرّعان عن الأذان نفسه، فيلزمهما ما يلزمه.
    @MainActor
    func testPreAthanAndIqamahAlsoCarryTheCityWallClock() throws {
        let store = storeInSanFrancisco()
        store.athanAlerts = true
        store.preAthanMinutes = 15
        store.iqamahMinutes = 20
        silenceEveryPrayer(except: .fajr, in: store)
        let times = try XCTUnwrap(store.prayerTimes(for: anchor))
        let fajr = try XCTUnwrap(times[.fajr])
        let iqamah = fajr.addingTimeInterval(20 * 60)

        let plan = Reminders.makePlan(store: store, now: anchor)
        for (identifier, moment) in [(Reminders.athanPrefix + "pre.0.fajr", fajr),
                                     (Reminders.athanPrefix + "iq.0.fajr", iqamah)] {
            let request = try XCTUnwrap(plan.first { $0.identifier == identifier },
                                        "\(identifier) غائب عن الخطة: \(plan.map(\.identifier))")
            let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
            XCTAssertEqual(trigger.dateComponents.timeZone?.identifier, placeZone.identifier, identifier)
            XCTAssertTrue(request.content.subtitle.contains(clock(moment, in: placeZone)),
                          "\(identifier) لا يحمل ساعة المدينة: \(request.content.subtitle)")
            XCTAssertFalse(request.content.subtitle.contains(clock(moment, in: deviceZone)),
                           "\(identifier) يحمل ساعة الجهاز: \(request.content.subtitle)")
        }
    }
}
