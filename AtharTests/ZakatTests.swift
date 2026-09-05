import XCTest
@testable import Athar

final class ZakatTests: XCTestCase {
    func testNumberParsing() {
        XCTAssertEqual(ZakatNumber.parse("1,234,567"), 1_234_567)
        XCTAssertEqual(ZakatNumber.parse("12.5"), 12.5)
        XCTAssertEqual(ZakatNumber.parse("1.234,56"), 1234.56)
        XCTAssertEqual(ZakatNumber.parse("1,234"), 1234)
        XCTAssertEqual(ZakatNumber.parse("١٢٣٤٫٥"), 1234.5)
        XCTAssertEqual(ZakatNumber.parse("abc"), 0)
        XCTAssertEqual(ZakatNumber.parse("12,345,678.90"), 12_345_678.9, accuracy: 0.0001)
    }

    func testNisabUsesLowerMetalAndNeverClaimsZeroWithoutPrice() {
        var i = ZakatInput(); i.cash = 10_000
        let unknown = Zakat.compute(i)
        XCTAssertFalse(unknown.nisabKnown)
        XCTAssertEqual(unknown.due, 0)

        i.goldPricePerGram = 300          // نصاب الذهب ٢٥٥٠٠
        i.silverPricePerGram = 4          // نصاب الفضة ٢٣٨٠ ← الأدنى
        let r = Zakat.compute(i)
        XCTAssertTrue(r.nisabKnown)
        XCTAssertEqual(r.nisabMetal, .silver)
        XCTAssertEqual(r.nisab, 595 * 4, accuracy: 0.001)
        XCTAssertTrue(r.reachesNisab)
        XCTAssertEqual(r.due, 10_000 * 0.025, accuracy: 0.001)
    }

    func testDebtsReduceBase() {
        var i = ZakatInput(); i.cash = 50_000; i.debtsDue = 45_000; i.goldPricePerGram = 300
        let r = Zakat.compute(i)
        XCTAssertEqual(r.base, 5_000)
        XCTAssertFalse(r.reachesNisab)
        XCTAssertEqual(r.due, 0)
    }
}
