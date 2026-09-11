import XCTest
import CoreLocation
@testable import Athar

// MARK: - يومُ تبديل الساعة وشهرُ رمضان

/// علّتان في حساب المواقيت، لا تظهر واحدةٌ منهما في يومٍ عاديّ ولا في مدينةٍ عاديّة:
///
/// الأولى: كانت اللحظاتُ تُبنى بإضافة ساعاتٍ إلى منتصف ليل المدينة بعد أن يُضاف إليها
/// فرقُ منطقتها — والفرقُ يُؤخذ من لحظة النداء لا من منتصف الليل. فإذا بُدِّل التوقيت
/// الصيفيّ ليلًا ثم فُتح التطبيق نهارًا، حُمل الفرقُ الجديد على منتصف ليلٍ قديم فانزاح
/// جدولُ اليوم كلّه ساعةً كاملة: شروقُ لندن في ٢٩ مارس ٢٠٢٦ كان يُقرأ 07:42 وهو 06:42.
/// وأصلُ العلّة الحملُ مرّتين لا لحظةُ الأخذ: بيروت تقفز ساعتُها من الثانية عشرة إلى
/// الواحدة، فليس لذلك اليوم منتصفُ ليلٍ أصلًا يُبنى عليه. فصار البناء على منتصف ليل
/// غرينتش لليوم نفسه، ولا فرقَ منطقةٍ في الحساب البتّة.
///
/// والثانية: عشاءُ أم القرى تسعون دقيقة بعد المغرب طوال العام ومئةٌ وعشرون في رمضان،
/// وكان التسعون ثابتًا لا يعرف الشهر — فتقدّم أذانُ العشاء على التقويم نصفَ ساعة
/// شهرًا كاملًا، على الطريقة المختارة افتراضًا وفي مكة نفسها.
final class PrayerTimesDSTRamadanTests: XCTestCase {

    private let riyadhTZ = TimeZone(identifier: "Asia/Riyadh")!
    private let makkah = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
    private let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    private let londonTZ = TimeZone(identifier: "Europe/London")!
    private let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    private let newYorkTZ = TimeZone(identifier: "America/New_York")!
    /// بيروت من قائمة المدن، وهي التي لا منتصفَ ليل ليوم تبديلها: الساعة تقفز 00:00 ← 01:00.
    private let beirut = CLLocationCoordinate2D(latitude: 33.8938, longitude: 35.5018)
    private let beirutTZ = TimeZone(identifier: "Asia/Beirut")!
    private let utc = TimeZone(identifier: "UTC")!

    private var deviceZoneBeforeTest: TimeZone?

    override func setUp() {
        super.setUp()
        // نُجلس الجهاز في الرياض: تحويل التاريخ الهجري يمرّ بتقويم الجهاز، فلا يُترك
        // لأرضٍ يصادف أن يقف عليها من يشغّل الاختبار.
        deviceZoneBeforeTest = NSTimeZone.default
        NSTimeZone.default = riyadhTZ
    }

    override func tearDown() {
        if let zone = deviceZoneBeforeTest { NSTimeZone.default = zone }
        super.tearDown()
    }

    // MARK: أدوات

    private func greg(_ y: Int, _ m: Int, _ d: Int, hour: Int, in zone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    private func stamp(_ date: Date, in zone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = zone
        return f.string(from: date)
    }

    private func minutes(_ from: Date, _ to: Date) -> Double {
        to.timeIntervalSince(from) / 60
    }

    // MARK: يوم تبديل التوقيت الصيفي

    /// الميزان هنا لا يحتاج جدولًا خارجيًّا: لحظةُ الفجر لحظةٌ في الكون، لا تتبدّل
    /// بتبدّل الساعة التي نقرؤها بها. فنحسب اليومَ نفسه مرّتين — بمنطقة المدينة وبتوقيت
    /// غرينتش — فإن اختلفت اللحظتان فالخلل في الحساب لا في العرض. وكان الفرق ساعةً
    /// تامّة يوم التبديل إذا فُتح التطبيق بعده.
    func testTimesOnTheDayTheClockChangesDoNotDriftByAnHour() throws {
        let cases: [(String, CLLocationCoordinate2D, TimeZone, Int, Int, Int)] = [
            ("لندن — بدء التوقيت الصيفي", london, londonTZ, 2026, 3, 29),
            ("لندن — نهايته", london, londonTZ, 2026, 10, 25),
            ("نيويورك — بدؤه", newYork, newYorkTZ, 2026, 3, 8),
            ("بيروت — يومٌ بلا منتصف ليل", beirut, beirutTZ, 2026, 3, 29),
            ("بيروت — نهايته", beirut, beirutTZ, 2026, 10, 25),
        ]
        for (name, coordinate, zone, y, m, d) in cases {
            for method in [CalculationMethod.mwl, .ummAlQura] {
                let control = try XCTUnwrap(PrayerTimes(date: greg(y, m, d, hour: 12, in: utc),
                                                        coordinate: coordinate, timeZone: utc, method: method))
                // نداءان: قبل التبديل وبعده. الجدول واحدٌ لا يتبدّل بساعة فتح التطبيق.
                for hour in [0, 10] {
                    let times = try XCTUnwrap(PrayerTimes(date: greg(y, m, d, hour: hour, in: zone),
                                                          coordinate: coordinate, timeZone: zone, method: method))
                    for prayer in Prayer.allCases {
                        let mine = try XCTUnwrap(times[prayer])
                        let oracle = try XCTUnwrap(control[prayer])
                        XCTAssertEqual(minutes(oracle, mine), 0, accuracy: 1,
                                       "\(name) · \(method.rawValue) · \(prayer.rawValue) عند النداء الساعة \(hour): "
                                       + "\(stamp(mine, in: zone)) بدل \(stamp(oracle, in: zone))")
                    }
                }
            }
        }
    }

    /// شاهدٌ ثانٍ لا يتّكئ على حسابٍ آخر: الشروق يتقدّم أو يتأخّر دقائق كل يوم، فالمسافة
    /// بين شروقٍ وشروق أربعٌ وعشرون ساعة إلا دقائق — يومَ التبديل وغيرَه، لأن اللحظة
    /// لا تعرف الساعة الصيفية. كانت المسافة يوم التبديل خمسًا وعشرين ساعة إلا دقائق.
    func testSunriseAdvancesByMinutesNotByAnHourAcrossTheChange() throws {
        for (name, coordinate, zone) in [("لندن", london, londonTZ), ("بيروت", beirut, beirutTZ)] {
            var previous: Date?
            for day in 27...31 {
                let times = try XCTUnwrap(PrayerTimes(date: greg(2026, 3, day, hour: 10, in: zone),
                                                      coordinate: coordinate, timeZone: zone, method: .mwl))
                let sunrise = try XCTUnwrap(times[.sunrise])
                if let previous {
                    XCTAssertEqual(minutes(previous, sunrise), 24 * 60, accuracy: 10,
                                   "\(name): قفزةٌ في شروق \(stamp(sunrise, in: zone)) عن سابقه \(stamp(previous, in: zone))")
                }
                previous = sunrise
            }
        }
    }

    // MARK: عشاء رمضان

    /// اليوم يُبنى من التاريخ الهجري نفسه (`Hijri.date`) لا من تاريخٍ ميلاديّ مكتوبٍ
    /// بيدنا: من ضبط «اختلاف المطالع» على جهازه أزاح رزنامته، والاختبار ينبغي أن يشهد
    /// على القاعدة لا على تقويم مَن يشغّله.
    private func makkahIshaGap(hijriYear: Int, month: Int, day: Int,
                               file: StaticString = #filePath, line: UInt = #line) throws -> Double {
        let midnight = try XCTUnwrap(Hijri.date(year: hijriYear, month: month, day: day),
                                     "تاريخ هجري لا يقع على رزنامة", file: file, line: line)
        let noon = midnight.addingTimeInterval(12 * 3600)
        XCTAssertEqual(PrayerTimes.hijriMonth(of: noon, in: riyadhTZ), month,
                       "اليوم المبنيّ خرج من شهره", file: file, line: line)
        let times = try XCTUnwrap(PrayerTimes(date: noon, coordinate: makkah,
                                              timeZone: riyadhTZ, method: .ummAlQura),
                                  "مواقيت مكة", file: file, line: line)
        let maghrib = try XCTUnwrap(times[.maghrib], file: file, line: line)
        let isha = try XCTUnwrap(times[.isha], file: file, line: line)
        return minutes(maghrib, isha)
    }

    /// القاعدة كما في تقويم أم القرى: تسعون دقيقة، ومئةٌ وعشرون في رمضان وحده. ويُتحقَّق
    /// من طرفَي الشهر — أوّله وآخره — لأن العطب لو عاد فسيعود من حدّ الشهر لا من وسطه.
    func testUmmAlQuraIshaIsTwoHoursAfterMaghribThroughoutRamadan() throws {
        for day in [1, 15, 29] {
            XCTAssertEqual(try makkahIshaGap(hijriYear: 1447, month: 9, day: day), 120, accuracy: 0.5,
                           "\(day) رمضان ١٤٤٧")
        }
        for day in [1, 20] {
            XCTAssertEqual(try makkahIshaGap(hijriYear: 1448, month: 9, day: day), 120, accuracy: 0.5,
                           "\(day) رمضان ١٤٤٨")
        }
    }

    /// وما قبل رمضان وما بعده على التسعين: العلّة أن يعمّ الشهرُ سائرَ العام كما عمّ
    /// التسعونُ رمضانَ قبل هذا الإصلاح.
    func testUmmAlQuraIshaReturnsToNinetyMinutesOutsideRamadan() throws {
        for (month, day, label) in [(8, 29, "٢٩ شعبان"), (10, 1, "١ شوال"), (10, 5, "٥ شوال"),
                                    (1, 10, "١٠ محرم"), (12, 9, "٩ ذي الحجة")] {
            XCTAssertEqual(try makkahIshaGap(hijriYear: 1447, month: month, day: day), 90, accuracy: 0.5, label)
        }
    }

    /// والفارق بين الحالين نصفُ ساعة بالضبط — هي التي كان يتقدّمها الأذانُ على التقويم.
    func testTheRamadanDifferenceIsExactlyHalfAnHour() throws {
        let ramadan = try makkahIshaGap(hijriYear: 1447, month: 9, day: 15)
        let shaban = try makkahIshaGap(hijriYear: 1447, month: 8, day: 15)
        XCTAssertEqual(ramadan - shaban, 30, accuracy: 0.5)
    }

    /// الجدول نفسه: الفاصل لأم القرى وحدها، والطرقُ الأخرى تحسب العشاء بزاوية الشمس
    /// فلا فاصل لها — لا في رمضان ولا في غيره.
    func testIshaIntervalTableIsRamadanAwareForUmmAlQuraAlone() {
        XCTAssertEqual(CalculationMethod.ummAlQura.ishaInterval(hijriMonth: 9), 120)
        for month in [1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12] {
            XCTAssertEqual(CalculationMethod.ummAlQura.ishaInterval(hijriMonth: month), 90, "شهر \(month)")
        }
        for method in CalculationMethod.allCases where method != .ummAlQura {
            XCTAssertNotNil(method.ishaAngle, method.rawValue)
            for month in 1...12 {
                XCTAssertEqual(method.ishaInterval(hijriMonth: month), 0, "\(method.rawValue) شهر \(month)")
            }
        }
    }

    /// وشهرُ اليوم يُقاس بمنطقة المكان لا بمنطقة الجهاز. بين هونولولو والرياض ثلاث عشرة
    /// ساعة: يومُ آخرِ شعبان في هونولولو يقع نهارُه كلّه في أوّل رمضان بساعة الرياض. فمن
    /// قاس الشهر بأرض الجهاز أذّن لأهل هونولولو عشاءَ رمضان قبل رمضان بيوم.
    func testHijriMonthFollowsThePlaceZoneNotTheDevices() throws {
        let honoluluTZ = TimeZone(identifier: "Pacific/Honolulu")!
        var riyadhCal = Calendar(identifier: .gregorian); riyadhCal.timeZone = riyadhTZ
        var honoluluCal = Calendar(identifier: .gregorian); honoluluCal.timeZone = honoluluTZ

        // آخرُ يومٍ من شعبان: يُؤخذ بالتراجع عن أوّل رمضان لا بعدد أيام الشهر — الشهر
        // تسعةٌ وعشرون أو ثلاثون، وجداول أم القرى في النظام تُراجَع بين نسخةٍ وأخرى.
        let firstOfRamadan = try XCTUnwrap(Hijri.date(year: 1447, month: 9, day: 1))
        let eve = try XCTUnwrap(riyadhCal.date(byAdding: .day, value: -1, to: firstOfRamadan.addingTimeInterval(12 * 3600)))
        let parts = riyadhCal.dateComponents([.year, .month, .day], from: eve)
        let honoluluMidnight = try XCTUnwrap(honoluluCal.date(from: parts))

        XCTAssertEqual(PrayerTimes.hijriMonth(of: honoluluMidnight, in: honoluluTZ), 8,
                       "يومُ هونولولو لا يزال في شعبان: \(stamp(honoluluMidnight, in: honoluluTZ))")

        // شاهدُ العطب: مساءُ ذلك اليوم في هونولولو قد صار رمضان بساعة الرياض. اللحظة
        // واحدة والشهران اثنان، فمن أخذ شهره من أرض الجهاز أخذ شهرًا ليس شهرَ المكان.
        let evening = honoluluMidnight.addingTimeInterval(20 * 3600)
        XCTAssertEqual(PrayerTimes.hijriMonth(of: evening, in: honoluluTZ), 8,
                       "مساءُ هونولولو من يومه: \(stamp(evening, in: honoluluTZ))")
        XCTAssertEqual(PrayerTimes.hijriMonth(of: evening, in: riyadhTZ), 9,
                       "لو تساوى القياسان لما أمسك هذا الاختبار شيئًا: \(stamp(evening, in: riyadhTZ))")

        // والأثرُ في الميقات نفسه: عشاءُ ذلك اليوم في هونولولو تسعون دقيقة لا مئةٌ وعشرون.
        let honolulu = CLLocationCoordinate2D(latitude: 21.3069, longitude: -157.8583)
        let times = try XCTUnwrap(PrayerTimes(date: honoluluMidnight, coordinate: honolulu,
                                              timeZone: honoluluTZ, method: .ummAlQura))
        let maghrib = try XCTUnwrap(times[.maghrib])
        let isha = try XCTUnwrap(times[.isha])
        XCTAssertEqual(minutes(maghrib, isha), 90, accuracy: 0.5,
                       "آخرُ شعبان في هونولولو: \(stamp(maghrib, in: honoluluTZ)) ← \(stamp(isha, in: honoluluTZ))")
    }
}
