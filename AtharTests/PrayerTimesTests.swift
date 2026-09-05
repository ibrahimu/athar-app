import XCTest
import CoreLocation
@testable import Athar

final class PrayerTimesTests: XCTestCase {
    private let makkah = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)
    private let riyadhTZ = TimeZone(identifier: "Asia/Riyadh")!

    private func times(_ y: Int, _ m: Int, _ d: Int) -> PrayerTimes {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = riyadhTZ
        let date = cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
        return PrayerTimes(date: date, coordinate: makkah, timeZone: riyadhTZ, method: .ummAlQura, asr: .standard)!
    }

    func testOrderOfPrayers() {
        let t = times(2026, 9, 5)
        let order: [Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha]
        let dates = order.compactMap { t.times[$0] }
        XCTAssertEqual(dates.count, 6)
        XCTAssertEqual(dates, dates.sorted())
    }

    func testDhuhrIsAroundSolarNoonInMakkah() {
        let t = times(2026, 9, 5)
        var cal = Calendar(identifier: .gregorian); cal.timeZone = riyadhTZ
        let hour = cal.component(.hour, from: t.times[.dhuhr]!)
        XCTAssertTrue((11...13).contains(hour), "dhuhr hour \(hour)")
    }

    func testManualOffsetsShiftOnlyPrayers() {
        let t = times(2026, 9, 5)
        let shifted = t.shifted(by: [.fajr: 3, .isha: -5, .sunrise: 10])
        XCTAssertEqual(shifted.times[.fajr]!.timeIntervalSince(t.times[.fajr]!), 180)
        XCTAssertEqual(shifted.times[.isha]!.timeIntervalSince(t.times[.isha]!), -300)
        XCTAssertEqual(shifted.times[.sunrise], t.times[.sunrise])   // الشروق لا يُزاح
        XCTAssertEqual(shifted.times[.dhuhr], t.times[.dhuhr])
    }
}
