import XCTest
@testable import Athar

final class RamadanReadingTests: XCTestCase {
    func testQiyamContainsEveryOriginalPageAndEveryAyahExactlyOnce() {
        let pages = (1...200).flatMap { Array(QiyamLayout.originalPages(for: $0)) }
        XCTAssertEqual(pages, Array(1...Quran.pageCount))
        let verses = pages.flatMap { Quran.ayahs(inPage: $0) }
        XCTAssertEqual(verses.count, Quran.totalAyahs)
        XCTAssertEqual(Set(verses).count, Quran.totalAyahs)
        XCTAssertEqual(verses.first, AyahRef(surah: 1, ayah: 1))
        XCTAssertEqual(verses.last, AyahRef(surah: 114, ayah: 6))
        for page in 1...Quran.pageCount {
            XCTAssertTrue(QiyamLayout.originalPages(for: QiyamLayout.page(containing: page)).contains(page))
        }
    }

    func testReadingPathsSurviveUnrelatedBrowsingAndOnlySelectedPathAdvances() {
        let name = "athar.tests.paths.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AtharStore(defaults: defaults)
        let saved = Quran.firstAyah(ofPage: 200)
        store.lastRead = saved
        store.prepareReadingPaths()
        XCTAssertEqual(store.readingPaths.count, 1)
        let first = store.readingPaths[0].id
        store.lastRead = Quran.firstAyah(ofPage: 400)
        store.prepareReadingPaths()
        XCTAssertEqual(store.readingPaths[0].position, saved)
        let other = store.addReadingPath(title: "مراجعة", at: Quran.firstAyah(ofPage: 500))
        store.updateReadingPath(other, at: Quran.firstAyah(ofPage: 501))
        XCTAssertEqual(store.readingPaths.first { $0.id == first }?.position, saved)
        XCTAssertEqual(AtharStore(defaults: defaults).readingPaths.first { $0.id == other }?.position, Quran.firstAyah(ofPage: 501))
    }

    func testRamadanDatesRespectPlaceAndCalendarAdjustment() throws {
        for zone in ["Asia/Riyadh", "America/New_York", "Pacific/Auckland"] {
            let tz = try XCTUnwrap(TimeZone(identifier: zone))
            var calendar = Calendar(identifier: .islamicUmmAlQura); calendar.timeZone = tz
            for offset in -2...2 {
                let start = RamadanCalendar.start(now: Date(timeIntervalSince1970: 1_789_000_000), zone: tz, offset: offset)
                let corrected = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: start))
                XCTAssertEqual(calendar.component(.month, from: corrected), 9)
                XCTAssertEqual(calendar.component(.day, from: corrected), 1)
                XCTAssertTrue([29, 30].contains(RamadanCalendar.length(start: start, zone: tz, offset: offset)))
                let dates = RamadanCalendar.dates(start: start, count: 30, zone: tz)
                XCTAssertEqual(dates.count, 30)
                XCTAssertEqual(Set(dates).count, 30)
                for i in 1..<dates.count {
                    XCTAssertEqual(calendar.dateComponents([.day], from: dates[i - 1], to: dates[i]).day, 1)
                }
            }
        }
    }

    func testRamadanCustomizationAndQadaPersist() {
        let name = "athar.tests.ramadan.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = AtharStore(defaults: defaults)
        var preferences = RamadanPreferences()
        preferences.color = .olive; preferences.pattern = .lattice
        preferences.sections.reverse(); preferences.hidden = [.adhkar]
        preferences.length = 29
        store.ramadanPreferences = preferences
        store.fastingDaysOwed = 4
        let restored = AtharStore(defaults: defaults)
        XCTAssertEqual(restored.ramadanPreferences.sections, preferences.sections)
        XCTAssertEqual(restored.ramadanPreferences.color, .olive)
        XCTAssertTrue(restored.ramadanPreferences.hidden.contains(.adhkar))
        XCTAssertEqual(restored.fastingDaysOwed, 4)
        restored.fastingDaysOwed = -1
        XCTAssertEqual(restored.fastingDaysOwed, 0)
    }
}
