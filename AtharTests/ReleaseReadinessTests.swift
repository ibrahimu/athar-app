import XCTest
import PassKit
import UserNotifications
@testable import Athar

final class ReleaseReadinessTests: XCTestCase {
    func testEveryPhraseResolvesItsSourceAndHasUniqueIdentity() {
        XCTAssertFalse(PhraseLibrary.all.isEmpty)
        XCTAssertEqual(Set(PhraseLibrary.all.map(\.id)).count, PhraseLibrary.all.count)
        for phrase in PhraseLibrary.all {
            XCTAssertFalse(phrase.text.isEmpty, phrase.id)
            if phrase.isSacred { XCTAssertFalse(phrase.attribution.isEmpty, phrase.id) }
        }
    }

    func testEveryWalletPassLoadsAndMatchesItsCatalogue() throws {
        XCTAssertEqual(WalletCardLibrary.cards.count, 66)
        for card in WalletCardLibrary.cards {
            let url = try XCTUnwrap(WalletCardLibrary.passURL(for: card), card.id)
            let pass = try PKPass(data: Data(contentsOf: url))
            XCTAssertEqual(pass.serialNumber, card.serial)
            XCTAssertEqual(pass.passTypeIdentifier, WalletCardLibrary.passTypeIdentifier)
            XCTAssertFalse(card.text.isEmpty, card.id)
            XCTAssertNotNil(Bundle.main.url(forResource: card.id + "-preview", withExtension: "png"), card.id)
        }
    }

    @MainActor
    func testNotificationPlanFitsBudgetAndRetainsPrayerCoverageWithAllExtras() async {
        let defaults = UserDefaults(suiteName: "athar.tests.notifications.\(UUID().uuidString)")!
        let store = AtharStore(defaults: defaults)
        store.athanAlerts = true
        store.preAthanMinutes = 10
        store.iqamahMinutes = 15
        store.remindersEnabled = true
        store.adhkarReminderByPrayer = true
        store.hadithReminder = true
        store.qiyamAlert = true
        store.istighfarAlerts = true
        store.jumuahAlert = true
        store.fastingAlert = true
        store.whiteDaysAlert = true
        store.wirdEnabled = true
        let plan = Reminders.makePlan(store: store)
        XCTAssertLessThanOrEqual(plan.count, 64)
        XCTAssertEqual(Set(plan.map(\.identifier)).count, plan.count)
        let prayers = plan.filter {
            $0.identifier.hasPrefix("athar.athan.") && !$0.identifier.contains(".pre.") && !$0.identifier.contains(".iq.")
        }
        XCTAssertGreaterThanOrEqual(prayers.count, 25)
        XCTAssertTrue(plan.contains { $0.identifier == "athar.coverage" })
        store.athanAlerts = false
        let disabled = Reminders.makePlan(store: store)
        XCTAssertFalse(disabled.contains { $0.identifier.hasPrefix("athar.athan.") || $0.identifier == "athar.coverage" })
    }

    @MainActor
    func testLongestStoryRendersAtExportSize() async throws {
        let phrase = try XCTUnwrap(PhraseLibrary.all.max { $0.text.count < $1.text.count })
        let image = try XCTUnwrap(StoryCard.render(phrase: phrase))
        XCTAssertEqual(image.size.width, 1080)
        XCTAssertEqual(image.size.height, 1920)
        XCTAssertGreaterThanOrEqual(StoryCard.fittingFontSize(for: phrase), 18)
        try image.pngData()?.write(to: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("athar-longest-story.png"))
    }
}

extension ReleaseReadinessTests {
    @MainActor
    func testCloudSyncStartsOnceAndStopsReceivingChanges() async {
        let cloud = TestCloudStorage()
        let center = NotificationCenter()
        let sync = CloudKV(kv: cloud, notifications: center)
        let defaults = UserDefaults(suiteName: "athar.tests.cloud.\(UUID().uuidString)")!
        var calls = 0
        for _ in 0..<3 { sync.start(defaults: defaults) { calls += 1 } }
        XCTAssertEqual(calls, 1)
        cloud.values["athar.theme"] = "green"
        let info = [NSUbiquitousKeyValueStoreChangedKeysKey: ["athar.theme"]]
        center.post(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, userInfo: info)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(defaults.string(forKey: "athar.theme"), "green")
        sync.stop()
        cloud.values["athar.theme"] = "gold"
        center.post(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: cloud, userInfo: info)
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(defaults.string(forKey: "athar.theme"), "green")
    }

    @MainActor
    func testFridayMorningRetainsTodaysReminder() async throws {
        let defaults = UserDefaults(suiteName: "athar.tests.friday.\(UUID().uuidString)")!
        let store = AtharStore(defaults: defaults)
        store.jumuahAlert = true
        let calendar = Calendar.current
        let friday = try XCTUnwrap(calendar.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 1, weekday: 6), matchingPolicy: .nextTime))
        let plan = Reminders.makePlan(store: store, now: friday)
        let reminders = plan.filter { $0.identifier.hasPrefix("athar.jumuah.") }
        XCTAssertEqual(reminders.count, 4)
        let trigger = try XCTUnwrap(reminders.first?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.day, calendar.component(.day, from: friday))
    }
}

private final class TestCloudStorage: NSObject, CloudKeyValueStorage {
    var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values.removeValue(forKey: key) }
    func synchronize() -> Bool { true }
}
