import XCTest
@testable import Athar

final class HadithLibraryTests: XCTestCase {
    func testLibraryLoads() {
        XCTAssertEqual(HadithLibrary.books.count, 2)
        XCTAssertEqual(HadithLibrary.book(id: "riyad")?.count, 1896)
        XCTAssertEqual(HadithLibrary.book(id: "nawawi40")?.count, 42)
    }

    /// شارة «في الصحيحين» لا تُعلَّق على ما قيل فيه «على شرطهما» ولا على ما رواه غيرهما.
    func testSahihaynBadgeOnlyForRealTakhrij() {
        for h in HadithLibrary.all where h.isSahihayn {
            XCTAssertFalse(h.source.contains("شرط"), h.id)
            XCTAssertTrue(h.source.hasPrefix("متفق") || h.source.contains("رواه البخاري") || h.source.contains("رواه مسلم")
                          || h.source.hasPrefix("حديث صحيح رواه مسلم") || h.source.hasPrefix("حديث صحيح رواه البخاري"), "\(h.id): \(h.source)")
        }
    }

    func testDailyHadithIsStableWithinADayAndSahihayn() {
        let a = HadithLibrary.daily(for: Date())
        let b = HadithLibrary.daily(for: Date().addingTimeInterval(60))
        XCTAssertNotNil(a)
        XCTAssertEqual(a?.id, b?.id)
        XCTAssertTrue(a?.isSahihayn ?? false)
    }

    func testSearchNormalisesArabic() {
        XCTAssertFalse(HadithLibrary.search("انما الاعمال").isEmpty)
        XCTAssertFalse(HadithLibrary.search("إنما الأعمال").isEmpty)
    }
}
