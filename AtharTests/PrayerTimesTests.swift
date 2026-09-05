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

// MARK: - مطابقة تقويم أم القرى الرسمي

extension PrayerTimesTests {
    /// القيم من الموقع الرسمي لتقويم أم القرى (ummulqura.org.sa) ليوم 5 سبتمبر 2026 — كان الأذان
    /// يسبق التقويم بدقيقة إلى دقيقتين قبل تقريب الدقائق وضبط الفجر.
    func testMatchesOfficialUmmAlQura() {
        let tz = TimeZone(identifier: "Asia/Riyadh")!
        var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
        let day = cal.date(from: DateComponents(year: 2026, month: 9, day: 5))!
        let f = DateFormatter(); f.timeZone = tz; f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "HH:mm"
        let cases: [(String, Double, Double, [Prayer: String])] = [
            ("Riyadh", 24.6877, 46.7219, [.fajr: "04:17", .sunrise: "05:35", .dhuhr: "11:52", .asr: "15:21", .maghrib: "18:08", .isha: "19:38"]),
            ("Makkah", 21.4225, 39.8262, [.fajr: "04:49", .sunrise: "06:05", .dhuhr: "12:20", .asr: "15:45", .maghrib: "18:34", .isha: "20:04"]),
            ("Dammam", 26.4207, 50.0888, [.fajr: "04:01", .sunrise: "05:21", .dhuhr: "11:39", .asr: "15:09", .maghrib: "17:56", .isha: "19:26"]),
        ]
        for (name, lat, lng, expected) in cases {
            let t = PrayerTimes(date: day, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), timeZone: tz, method: .ummAlQura, asr: .standard)
            XCTAssertNotNil(t, name)
            for (prayer, hm) in expected {
                XCTAssertEqual(t![prayer].map(f.string), hm, "\(name) \(prayer.rawValue)")
            }
        }
    }

    /// كل وقت على رأس دقيقة: لا ثوانٍ تُقصّ عند العرض فيسبق التنبيهُ الوقتَ المعروض.
    func testTimesAreWholeMinutes() {
        let t = PrayerTimes(date: Date(), coordinate: CLLocationCoordinate2D(latitude: 24.69, longitude: 46.72), timeZone: TimeZone(identifier: "Asia/Riyadh")!)!
        for (_, d) in t.times { XCTAssertEqual(d.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 60), 0) }
    }
}
