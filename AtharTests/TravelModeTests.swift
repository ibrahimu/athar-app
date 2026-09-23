import XCTest
import UserNotifications
@testable import Athar

/// وضع السفر: عرضٌ وجدولة لا فتوى. وخطؤه صنفان — أن يُنادى لصلاةٍ قد صُلّيت
/// مع أختها، أو أن تسقط صلاةٌ من النداء وصاحبُها لم يطلب جمعًا.
final class TravelModeTests: XCTestCase {

    private func makeStore() -> AtharStore {
        AtharStore(defaults: UserDefaults(suiteName: "athar.tests.travel.\(UUID().uuidString)")!)
    }

    // MARK: الركعات

    /// الفجرُ ركعتان والمغربُ ثلاث في الحضر والسفر — القصرُ في الرباعيّة وحدها.
    func testOnlyTheFourRakaatPrayersAreShortened() {
        for travelling in [true, false] {
            XCTAssertEqual(Travel.rakaat(.fajr, travelling: travelling), 2)
            XCTAssertEqual(Travel.rakaat(.maghrib, travelling: travelling), 3)
            XCTAssertNil(Travel.rakaat(.sunrise, travelling: travelling))
        }
        for prayer in [Prayer.dhuhr, .asr, .isha] {
            XCTAssertEqual(Travel.rakaat(prayer, travelling: false), 4, prayer.rawValue)
            XCTAssertEqual(Travel.rakaat(prayer, travelling: true), 2, prayer.rawValue)
        }
    }

    // MARK: الجمع

    /// «بلا جمع» لا تطوي صلاةً: القصرُ عرضٌ، والنداءُ يبقى خمسًا.
    func testNoJoinMergesNothing() {
        for prayer in Prayer.allCases {
            XCTAssertFalse(TravelJoin.none.merged(into: prayer), prayer.rawValue)
            XCTAssertNil(TravelJoin.none.pair(at: prayer), prayer.rawValue)
        }
    }

    /// التقديمُ يضمّ الثانيةَ إلى الأولى، والتأخيرُ الأولى إلى الثانية — ولا
    /// يمسّان الفجر بحال.
    func testAdvanceAndDelayMergeTheRightSideOfEachPair() {
        XCTAssertTrue(TravelJoin.advance.merged(into: .asr))
        XCTAssertTrue(TravelJoin.advance.merged(into: .isha))
        XCTAssertFalse(TravelJoin.advance.merged(into: .dhuhr))
        XCTAssertFalse(TravelJoin.advance.merged(into: .maghrib))

        XCTAssertTrue(TravelJoin.delay.merged(into: .dhuhr))
        XCTAssertTrue(TravelJoin.delay.merged(into: .maghrib))
        XCTAssertFalse(TravelJoin.delay.merged(into: .asr))
        XCTAssertFalse(TravelJoin.delay.merged(into: .isha))

        for join in TravelJoin.allCases {
            XCTAssertFalse(join.merged(into: .fajr), join.rawValue)
            XCTAssertNil(join.pair(at: .fajr), join.rawValue)
        }
    }

    /// النداءُ الجامع يقع عند الصلاة التي لم تُطوَ — لا عند المطويّة.
    func testTheJoinedCallLandsOnThePrayerThatSurvives() {
        XCTAssertEqual(TravelJoin.advance.pair(at: .dhuhr)?.second, .asr)
        XCTAssertEqual(TravelJoin.advance.pair(at: .maghrib)?.second, .isha)
        XCTAssertEqual(TravelJoin.delay.pair(at: .asr)?.first, .dhuhr)
        XCTAssertEqual(TravelJoin.delay.pair(at: .isha)?.first, .maghrib)
        // والمطويّةُ لا تحمل نداءً جامعًا، وإلّا نُودي مرّتين.
        XCTAssertNil(TravelJoin.advance.pair(at: .asr))
        XCTAssertNil(TravelJoin.delay.pair(at: .dhuhr))
    }

    // MARK: الخطة

    @MainActor
    private func athanPrayers(_ store: AtharStore) -> Set<String> {
        let plan = Reminders.makePlan(store: store, now: Date())
        var found: Set<String> = []
        for request in plan where request.identifier.hasPrefix("athar.athan.")
            && !request.identifier.contains(".iq.") && !request.identifier.contains(".pre.") {
            if let prayer = request.content.userInfo[NotificationDelegate.prayerKey] as? String {
                found.insert(prayer)
            }
        }
        return found
    }

    /// بلا وضع سفر: الفرائضُ الخمس كلُّها في الخطّة.
    @MainActor
    func testAllFivePrayersAreCalledWhenNotTravelling() {
        let store = makeStore()
        store.athanAlerts = true
        XCTAssertEqual(athanPrayers(store), ["fajr", "dhuhr", "asr", "maghrib", "isha"])
    }

    /// وضعُ السفر بلا جمع لا يُسقط نداءً — والقصرُ عرضٌ لا جدولة.
    @MainActor
    func testTravellingWithoutJoinStillCallsEveryPrayer() {
        let store = makeStore()
        store.athanAlerts = true
        store.travelMode = true
        store.travelJoin = .none
        XCTAssertEqual(athanPrayers(store), ["fajr", "dhuhr", "asr", "maghrib", "isha"])
    }

    /// جمعُ التقديم: لا نداءَ للعصر ولا للعشاء وحدهما — يُنادى لهما مع أختيهما.
    @MainActor
    func testAdvanceJoinDropsTheSecondCallOfEachPair() {
        let store = makeStore()
        store.athanAlerts = true
        store.travelMode = true
        store.travelJoin = .advance
        XCTAssertEqual(athanPrayers(store), ["fajr", "dhuhr", "maghrib"])
    }

    @MainActor
    func testDelayJoinDropsTheFirstCallOfEachPair() {
        let store = makeStore()
        store.athanAlerts = true
        store.travelMode = true
        store.travelJoin = .delay
        XCTAssertEqual(athanPrayers(store), ["fajr", "asr", "isha"])
    }

    /// إطفاءُ الوضع يردّ النداءَ خمسًا في لحظته، ولو بقي اختيارُ الجمع محفوظًا.
    @MainActor
    func testTurningTravelOffRestoresEveryCallEvenIfAJoinIsRemembered() {
        let store = makeStore()
        store.athanAlerts = true
        store.travelMode = true
        store.travelJoin = .advance
        store.travelMode = false
        XCTAssertEqual(store.travelJoin, .advance)
        XCTAssertEqual(athanPrayers(store), ["fajr", "dhuhr", "asr", "maghrib", "isha"])
    }

    // MARK: الدليل

    /// آيةُ القصر تُحلّ من المصحف بمرجعها — لا تُكتب في الشيفرة.
    func testTheQasrProofResolvesFromTheMushafByReference() throws {
        let text = try XCTUnwrap(Quran.text(Travel.proof))
        XCTAssertTrue(text.contains("تَقْصُرُوا۟"), text)
        XCTAssertEqual(Quran.surah(Travel.proof.surah)?.name, "النساء")
        XCTAssertEqual(Travel.proof.ayah, 101)
    }

    /// التطبيق يعرض ولا يُفتي — كحاسبة الزكاة، يُقال ذلك صراحةً.
    func testTravelCarriesTheSameDisclaimerSpiritAsTheZakatCalculator() {
        XCTAssertTrue(Travel.disclaimer.contains("ليست فتوى") || Travel.disclaimer.contains("وليس فتوى"))
        XCTAssertTrue(Travel.disclaimer.contains("أهل العلم"))
    }

    /// لا يُشغَّل من نفسه أبدًا: المخزنُ الجديد يبدأ مطفأً.
    func testTravelModeIsOffUntilTheUserTurnsItOn() {
        XCTAssertFalse(makeStore().travelMode)
    }
}
