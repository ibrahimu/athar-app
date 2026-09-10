import XCTest
import UIKit
@testable import Athar

/// الجزيرة المضغوطة شقٌّ ضيّق حول الكاميرا، وما زاد عليه يُضغط ويلتصق بالحافّتين.
/// كان «حان الوقت» موضوعًا في إطار 54 نقطة وهو يحتاج 57.6 — فبان مكسورًا على الجهاز.
/// فتُقاس النصوص هنا بالخطّ نفسه الذي يرسمها، ولا تُخمَّن.
final class DynamicIslandFitTests: XCTestCase {

    /// خطّ الجزيرة: `.system(size:weight:design: .rounded)` كما في NextPrayerActivity.
    private func islandFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return UIFont(descriptor: rounded, size: size)
    }

    private func width(_ text: String, size: CGFloat, weight: UIFont.Weight = .semibold) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: islandFont(size, weight)]).width
    }

    /// الشقّ المضغوط: إطاره 40 نقطة عند 13pt.
    private let compactWidth: CGFloat = 40
    private let compactSize: CGFloat = 13

    /// المنطقة الموسّعة: إطارها 82 نقطة عند 17pt.
    private let expandedWidth: CGFloat = 82
    private let expandedSize: CGFloat = 17

    func testNowFitsTheCompactIsland() {
        let w = width(loc("الآن"), size: compactSize)
        XCTAssertLessThanOrEqual(w, compactWidth,
                                 "«الآن» تحتاج \(w) نقطة والشقّ \(compactWidth) — ستلتصق بالحافّة")
    }

    /// أطولُ عدٍّ ممكن هو نافذة النشاط كلّها: نصف ساعة قبل الأذان.
    func testLongestCountdownFitsTheCompactIsland() {
        let w = width("29:59", size: compactSize)
        XCTAssertLessThanOrEqual(w, compactWidth,
                                 "أطول عدّ يحتاج \(w) نقطة والشقّ \(compactWidth)")
    }

    /// العلّة التي وقعت فعلًا: العبارة الطويلة في الشقّ الضيّق. تبقى محروسة حتى لا تعود.
    func testTheLongPhraseIsNotWhatGoesInTheCompactSlot() {
        XCTAssertGreaterThan(width(loc("حان الوقت"), size: compactSize), compactWidth,
                             "لو صارت تسع الشقّ فالإطار تغيّر — راجع الفرق قبل إرجاع العبارة")
    }

    func testThePhraseFitsTheExpandedRegion() {
        let w = width(loc("حان الوقت"), size: expandedSize)
        XCTAssertLessThanOrEqual(w, expandedWidth,
                                 "«حان الوقت» تحتاج \(w) نقطة والمنطقة \(expandedWidth)")
    }

    func testLongestCountdownFitsTheExpandedRegion() {
        XCTAssertLessThanOrEqual(width("29:59", size: expandedSize), expandedWidth)
    }
}
