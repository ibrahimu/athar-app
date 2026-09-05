import XCTest
@testable import Athar

final class OccasionsTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date { Occasions.date(year: y, month: m, day: d)! }

    func testEidAlFitrIsNotInsideRamadan() {
        // ١ شوال لا يُعرض فيه «شهر رمضان — جارية» مهما كان طول الشهر (٢٩ أو ٣٠).
        for year in 1446...1452 {
            let eid = date(year, 10, 1)
            XCTAssertFalse(Occasions.occasions(on: eid).contains { $0.id == "ramadan" }, "year \(year)")
            XCTAssertTrue(Occasions.occasions(on: eid).contains { $0.id == "fitr" }, "year \(year)")
        }
    }

    func testWhiteDaysSkipDhulHijjah() {
        let tashreeq = date(1447, 12, 13)
        let ids = Occasions.occasions(on: tashreeq).map(\.id)
        XCTAssertTrue(ids.contains("tashreeq"))
        XCTAssertFalse(ids.contains("whiteDays"))
        // وتظهر في شهر عادي
        XCTAssertTrue(Occasions.occasions(on: date(1447, 3, 14)).contains { $0.id == "whiteDays" })
    }

    func testArafahAndAdhaAreConsecutive() {
        XCTAssertTrue(Occasions.occasions(on: date(1447, 12, 9)).contains { $0.id == "arafah" })
        XCTAssertTrue(Occasions.occasions(on: date(1447, 12, 10)).contains { $0.id == "adha" })
        XCTAssertFalse(Occasions.occasions(on: date(1447, 12, 10)).contains { $0.id == "arafah" })
    }

    func testUpcomingIsSortedAndNonEmpty() {
        let up = Occasions.upcoming(from: Date(), limit: 6)
        XCTAssertFalse(up.isEmpty)
        XCTAssertEqual(up.map(\.start), up.map(\.start).sorted())
    }
}
