import XCTest
@testable import Athar

/// «مضى على الأذان …»: النقرُ على صلاةٍ بعد أذانها يُبدّل وقتَها بما مضى عليه.
/// والعربيةُ تُفرد وتُثنّي وتجمع، فيُحرَس اللفظُ لا الرقمُ وحده.
final class ElapsedSinceAthanTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func at(_ minutes: Int) -> String {
        PrayerView.elapsedText(since: t0, now: t0.addingTimeInterval(Double(minutes) * 60))
    }

    func testTheOwnersExample() {
        // «إذا انتهى وقت العشاء الساعة 7:57 وضغطت الساعة 8:10 يظهر لي 13 دقيقة»
        XCTAssertEqual(at(13), "مضى 13 دقيقة")
    }

    func testArabicNumberAgreement() {
        XCTAssertEqual(at(0),  "الآن")
        XCTAssertEqual(at(1),  "مضى دقيقة")
        XCTAssertEqual(at(2),  "مضى دقيقتان")
        XCTAssertEqual(at(7),  "مضى 7 دقائق")
        XCTAssertEqual(at(11), "مضى 11 دقيقة")
        XCTAssertEqual(at(60), "مضى ساعة")
        XCTAssertEqual(at(65), "مضى ساعة و5 دقائق")
        XCTAssertEqual(at(120), "مضى ساعتان")
        XCTAssertEqual(at(200), "مضى 3 ساعات و20 دقيقة")
    }

    /// لا يُعدّ ما لم يقع: قبل الأذان بلحظةٍ لا يخرج رقمٌ سالب.
    func testNeverNegative() {
        XCTAssertEqual(PrayerView.elapsedText(since: t0, now: t0.addingTimeInterval(-30)), "الآن")
    }

    /// لا يُلتفت إلى الثواني: 13 دقيقة و59 ثانية هي 13 لا 14.
    func testSecondsAreDropped() {
        XCTAssertEqual(PrayerView.elapsedText(since: t0, now: t0.addingTimeInterval(13 * 60 + 59)),
                       "مضى 13 دقيقة")
    }
}
