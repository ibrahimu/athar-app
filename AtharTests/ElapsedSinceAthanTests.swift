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
        XCTAssertEqual(at(13), "مضى على الأذان 13 دقيقة")
    }

    func testArabicNumberAgreement() {
        XCTAssertEqual(at(0),  "أُذّن الآن")
        XCTAssertEqual(at(1),  "مضى على الأذان دقيقة")
        XCTAssertEqual(at(2),  "مضى على الأذان دقيقتان")
        XCTAssertEqual(at(7),  "مضى على الأذان 7 دقائق")
        XCTAssertEqual(at(11), "مضى على الأذان 11 دقيقة")
        XCTAssertEqual(at(60), "مضى على الأذان ساعة")
        XCTAssertEqual(at(65), "مضى على الأذان ساعة و5 دقائق")
        XCTAssertEqual(at(120), "مضى على الأذان ساعتان")
        XCTAssertEqual(at(200), "مضى على الأذان 3 ساعات و20 دقيقة")
    }

    /// لا يُعدّ ما لم يقع: قبل الأذان بلحظةٍ لا يخرج رقمٌ سالب.
    func testNeverNegative() {
        XCTAssertEqual(PrayerView.elapsedText(since: t0, now: t0.addingTimeInterval(-30)), "أُذّن الآن")
    }

    /// لا يُلتفت إلى الثواني: 13 دقيقة و59 ثانية هي 13 لا 14.
    func testSecondsAreDropped() {
        XCTAssertEqual(PrayerView.elapsedText(since: t0, now: t0.addingTimeInterval(13 * 60 + 59)),
                       "مضى على الأذان 13 دقيقة")
    }
}
