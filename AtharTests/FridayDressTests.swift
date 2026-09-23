import XCTest
@testable import Athar

/// لباس الجمعة: طابعٌ يُلبَس يومًا واحدًا ثمّ يُخلع. وخطؤه صنفان — أن يلبس من
/// لم يطلب، أو أن يبتلع الطابعَ الأصل فلا يعود إليه صاحبُه يومَ السبت.
final class FridayDressTests: XCTestCase {

    private func makeStore() -> (AtharStore, UserDefaults) {
        let suite = "athar.tests.dress.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (AtharStore(defaults: defaults), defaults)
    }

    /// يومٌ من كل أسبوع: التقويم الميلادي عند آبل يعدّ الأحد ١، فالجمعة ٦ — وهو
    /// القياس نفسه الذي تُعرض به بطاقة الجمعة وسننُها وتنبيه الكهف.
    private func day(_ iso: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "Asia/Riyadh")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: iso)!
    }

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Riyadh")!
        return c
    }

    func testFridayIsTheSixthWeekdayAndNothingElseIs() {
        XCTAssertTrue(AtharStore.isFriday(day("2026-09-25 09:00"), calendar: calendar))
        for other in ["2026-09-24 09:00", "2026-09-26 09:00", "2026-09-27 09:00",
                      "2026-09-28 09:00", "2026-09-29 09:00", "2026-09-30 09:00",
                      "2026-10-01 09:00"] {
            XCTAssertFalse(AtharStore.isFriday(day(other), calendar: calendar), other)
        }
    }

    /// المفتاح مُطفأ حتى يُطلب: من لم يسمع بلباس الجمعة أصلًا لا يتبدّل طابعه
    /// عليه صباح الجمعة ويظنّ التطبيق قد فسد.
    func testDressIsOffUntilAskedFor() {
        let (store, _) = makeStore()
        XCTAssertFalse(store.fridayDress)
        store.appTheme = .sea
        XCTAssertEqual(store.dressedTheme(on: day("2026-09-25 09:00"), calendar: calendar), .sea)
    }

    func testDressWornOnFridayOnlyAndBaseThemeSurvivesUnderneath() {
        let (store, _) = makeStore()
        store.appTheme = .sea
        store.fridayTheme = .amber
        store.fridayDress = true

        XCTAssertEqual(store.dressedTheme(on: day("2026-09-25 09:00"), calendar: calendar), .amber)
        XCTAssertEqual(store.dressedTheme(on: day("2026-09-25 23:59"), calendar: calendar), .amber)
        // الخميس قبلها والسبت بعدها — وطابعه الأصل لم يُمسّ.
        XCTAssertEqual(store.dressedTheme(on: day("2026-09-24 23:59"), calendar: calendar), .sea)
        XCTAssertEqual(store.dressedTheme(on: day("2026-09-26 00:01"), calendar: calendar), .sea)
        XCTAssertEqual(store.appTheme, .sea)
    }

    /// من بدّل طابعه الأصل يوم الجمعة: يُحفَظ له ولا يُخلع عنه اللباس قبل أوانه.
    func testChangingBaseThemeOnFridayKeepsTheDressOn() {
        let (store, defaults) = makeStore()
        store.fridayTheme = .amber
        store.fridayDress = true
        store.appTheme = .violet
        XCTAssertEqual(defaults.string(forKey: "athar.theme"), "violet")
        XCTAssertEqual(store.dressedTheme(on: day("2026-09-25 12:00"), calendar: calendar), .amber)
        XCTAssertEqual(store.dressedTheme(on: day("2026-09-27 12:00"), calendar: calendar), .violet)
    }

    /// إطفاء المفتاح يردّ كل شيء في لحظته — لا في اليوم التالي.
    func testTurningDressOffRestoresTheBaseThemeAtOnce() {
        let (store, _) = makeStore()
        store.appTheme = .olive
        store.fridayTheme = .plum
        store.fridayDress = true
        store.fridayDress = false
        XCTAssertEqual(store.dressedTheme(on: day("2026-09-25 12:00"), calendar: calendar), .olive)
    }

    /// الودجات والساعة والنشاط الحيّ تقرأ `effectiveTheme` لا `appTheme`، وإلّا
    /// لبس التطبيقُ يوم الجمعة وبقيت ودجتُه على لونٍ آخر جنبه على الشاشة نفسها.
    func testEffectiveThemeIsWhatTheExtensionsRead() throws {
        let sources = ["Shared/WidgetStyle.swift", "Shared/NextPrayerAttributes.swift",
                       "Shared/AtharStore+Watch.swift"]
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for file in sources {
            let text = try String(contentsOf: root.appendingPathComponent(file), encoding: .utf8)
            XCTAssertFalse(text.contains("AtharStore.shared.appTheme"), file)
            XCTAssertFalse(text.contains(": appTheme.rawValue"), file)
        }
    }

    /// التخزين السحابي والتصدير: ما يُضبط على جهازٍ يُوجد على الآخر، ومن نسخ
    /// إعداداته وجد لباسه فيها — وإلّا كان الإعداد يضيع في كل انتقال.
    func testDressKeysTravelWithTheRestOfTheLook() throws {
        XCTAssertTrue(CloudKV.keys.contains("athar.fridayDress"))
        XCTAssertTrue(CloudKV.keys.contains("athar.fridayTheme"))
    }
}
