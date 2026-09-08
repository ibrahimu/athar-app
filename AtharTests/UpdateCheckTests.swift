import XCTest
@testable import Athar

/// مقارنة الإصدارين: هي كلّ ما يُبنى عليه إظهار بطاقة «فيه تحديث»، وخطؤها
/// إمّا أن يُلحّ على من هو على الأحدث، وإمّا أن يسكت عمّن فاته تحديث.
final class UpdateCheckTests: XCTestCase {

    func testNewerByMinor() {
        XCTAssertTrue(UpdateCheck.isNewer("1.4", than: "1.3"))
        XCTAssertFalse(UpdateCheck.isNewer("1.3", than: "1.4"))
    }

    func testEqualIsNotNewer() {
        XCTAssertFalse(UpdateCheck.isNewer("1.4", than: "1.4"))
        XCTAssertFalse(UpdateCheck.isNewer("1.4.0", than: "1.4"))
        XCTAssertFalse(UpdateCheck.isNewer("1.4", than: "1.4.0"))
    }

    /// المقارنة النصّية تقول إنّ «1.9» أحدث من «1.10» — وهي العلّة التي تُتجنَّب.
    func testTenBeatsNine() {
        XCTAssertTrue(UpdateCheck.isNewer("1.10", than: "1.9"))
        XCTAssertFalse(UpdateCheck.isNewer("1.9", than: "1.10"))
    }

    func testPatchAndMajor() {
        XCTAssertTrue(UpdateCheck.isNewer("1.4.1", than: "1.4"))
        XCTAssertTrue(UpdateCheck.isNewer("2.0", than: "1.9.9"))
        XCTAssertFalse(UpdateCheck.isNewer("1.9.9", than: "2.0"))
    }

    /// ردٌّ غريب من المتجر لا يقلب الحكم: ما لا يُقرأ عددًا يُقرأ صفرًا.
    func testMalformedIsSafe() {
        XCTAssertFalse(UpdateCheck.isNewer("", than: "1.4"))
        XCTAssertFalse(UpdateCheck.isNewer("abc", than: "1.4"))
        XCTAssertTrue(UpdateCheck.isNewer("1.4", than: "abc"))
    }

    /// «ما الجديد» تُختم بنسخة الإصدار المنشور، فلو تخلّفت عنه نزل التحديث صامتًا
    /// ولم يرَ أحدٌ ما فيه.
    func testWhatsNewMatchesMarketingVersion() {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        XCTAssertEqual(WhatsNewView.version, marketing,
                       "«ما الجديد» عند \(WhatsNewView.version) والإصدار \(marketing ?? "?")")
    }
}
