import XCTest
@testable import Athar

/// قوائم CarPlay: ما يسقط منها يسقط صامتًا في السيارة — يقصّه النظام بلا خبر —
/// فالحساب الذي يقصّه عندنا هو ما يجب أن يُحرَس.
final class CarPlayMenuTests: XCTestCase {

    // MARK: تقسيم السور

    func testGroupsCoverEverySurahOnceInOrder() {
        let ids = CarPlayMenu.surahGroups().flatMap(\.ids)
        XCTAssertEqual(ids, Array(1...114), "المصحف يُقسَّم كاملًا وبترتيبه، بلا تكرار ولا سقوط")
    }

    func testGroupHeadersNameTheirRange() {
        let groups = CarPlayMenu.surahGroups(step: 12)
        XCTAssertEqual(groups.first?.header, "1–12")
        XCTAssertEqual(groups.last?.header, "109–114")
        XCTAssertEqual(groups.last?.ids.count, 6, "المجموعة الأخيرة ناقصة، ولا تُملأ بما ليس منها")
    }

    /// خطوةٌ لا تقسم المئة والأربع عشرة على عددٍ صحيح لا تُسقط الباقي.
    func testUnevenStepKeepsRemainder() {
        let groups = CarPlayMenu.surahGroups(step: 30)
        XCTAssertEqual(groups.count, 4)
        XCTAssertEqual(groups.flatMap(\.ids), Array(1...114))
    }

    func testDegenerateStepIsSafe() {
        XCTAssertTrue(CarPlayMenu.surahGroups(step: 0).isEmpty)
        XCTAssertTrue(CarPlayMenu.surahGroups(step: 20, total: 0).isEmpty)
    }

    // MARK: القصّ على حدّ النظام

    private func groups(_ sizes: [Int]) -> [(header: String, items: [Int])] {
        sizes.enumerated().map { (header: "\($0.offset)", items: Array(repeating: 0, count: $0.element)) }
    }

    func testClampKeepsEverythingWhenItFits() {
        let out = CarPlayMenu.clamp(groups([5, 5]), maxSections: 10, maxItems: 100)
        XCTAssertEqual(out.map(\.items.count), [5, 5])
    }

    func testClampCutsSectionsBeyondTheSectionLimit() {
        let out = CarPlayMenu.clamp(groups([2, 2, 2]), maxSections: 2, maxItems: 100)
        XCTAssertEqual(out.count, 2)
    }

    /// الحدّ على العناصر يسري عبر الأقسام كلّها لا داخل كل قسم على حدة.
    func testClampCountsItemsAcrossSections() {
        let out = CarPlayMenu.clamp(groups([4, 4, 4]), maxSections: 10, maxItems: 6)
        XCTAssertEqual(out.map(\.items.count), [4, 2])
    }

    /// لا يُترك قسمٌ بعنوانٍ وبلا عناصر — عنوانٌ يعد بما تحته وليس تحته شيء.
    func testClampNeverEmitsAnEmptySection() {
        let out = CarPlayMenu.clamp(groups([6, 3]), maxSections: 10, maxItems: 6)
        XCTAssertEqual(out.count, 1)
        XCTAssertFalse(out.contains { $0.items.isEmpty })
    }

    func testClampWithNoRoomYieldsNothing() {
        XCTAssertTrue(CarPlayMenu.clamp(groups([3]), maxSections: 0, maxItems: 10).isEmpty)
        XCTAssertTrue(CarPlayMenu.clamp(groups([3]), maxSections: 10, maxItems: 0).isEmpty)
    }

    // MARK: المختارة

    // MARK: السقف الحقيقي

    /// سقفُ القائمة الواحدة في CarPlay اثنا عشر عنصرًا — قِيس من النظام لا خُمّن
    /// (CPListTemplate.maximumItemCount). وعليه بُني كلّ شيء: مئةٌ وأربع عشرة سورة
    /// كانت تُعرض دفعةً، فيسقط منها مئةٌ وعنصران صامتين.
    func testSurahGroupsFitOneList() {
        let groups = CarPlayMenu.surahGroups()
        XCTAssertLessThanOrEqual(groups.count, CarPlayMenu.pageSize,
                                 "المجموعات نفسها لا بدّ أن تسعها قائمة واحدة")
        for g in groups {
            XCTAssertLessThanOrEqual(g.ids.count, CarPlayMenu.pageSize, "\(g.header) تتجاوز السقف")
        }
        XCTAssertEqual(groups.flatMap(\.ids), Array(1...114), "ولا تسقط سورة")
    }

    // MARK: الصفحات

    func testShortListIsOnePage() {
        XCTAssertEqual(CarPlayMenu.pages([1, 2, 3], size: 12).count, 1)
        XCTAssertEqual(CarPlayMenu.pages(Array(1...12), size: 12).count, 1, "الاثنتا عشرة تسعها صفحة")
    }

    /// ما زاد يُدفع إلى صفحةٍ تالية، ويُترك في كلٍّ مقعدٌ لصفّ «المزيد».
    func testLongListPagesWithRoomForMore() {
        let pages = CarPlayMenu.pages(Array(1...15), size: 12)
        XCTAssertEqual(pages.map(\.count), [11, 4])
        XCTAssertEqual(pages.flatMap { $0 }, Array(1...15), "ولا يسقط عنصر")
    }

    func testPagingIsLossless() {
        for n in [1, 11, 12, 13, 23, 24, 114] {
            let pages = CarPlayMenu.pages(Array(1...n), size: 12)
            XCTAssertEqual(pages.flatMap { $0 }, Array(1...n), "سقط عنصرٌ عند \(n)")
            for p in pages { XCTAssertLessThanOrEqual(p.count, 12, "صفحةٌ تتجاوز السقف عند \(n)") }
        }
        XCTAssertTrue(CarPlayMenu.pages([Int](), size: 12).isEmpty)
    }

    /// سورُ الطريق تُحلّ من المصحف بمعرّفاتها — لا رقمَ فيها لا سورةَ له.
    func testFavouritesAreRealSurahs() {
        for id in CarPlayMenu.favourites {
            XCTAssertNotNil(Quran.surah(id), "لا سورة بالرقم \(id)")
        }
        XCTAssertEqual(Set(CarPlayMenu.favourites).count, CarPlayMenu.favourites.count, "لا تتكرّر")
    }
}
