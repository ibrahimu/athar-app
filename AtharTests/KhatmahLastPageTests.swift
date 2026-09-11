import XCTest
@testable import Athar

/// عدّاد الختمة عند آخر المصحف. كانت الصفحة ٦٠٤ لا تُحتسب في قراءةٍ متّصلة قط،
/// لأن احتساب الصفحة كان ببلوغ ما بعدها ولا شيء بعد آخرها: يقف العدّاد عند ٦٠٣،
/// وتُقرَّب النسبة إلى ١٠٠٪، فيُقال لمن ختم القرآن كلّه إنه لم يختم.
final class KhatmahLastPageTests: XCTestCase {

    private var suite = ""

    private func newStore(days: Int = 30) -> AtharStore {
        suite = "athar.tests.khatmah.\(UUID().uuidString)"
        let store = AtharStore(defaults: UserDefaults(suiteName: suite)!)
        store.startKhatmah(days: days, mode: .open)
        return store
    }

    override func tearDown() {
        if !suite.isEmpty { UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite) }
        super.tearDown()
    }

    /// من قرأ المصحف صفحةً صفحة من أوله إلى آخره فقد ختم: العدّاد يبلغ ٦٠٤ لا ٦٠٣.
    @MainActor
    func testReadingEveryPageInOrderCompletesTheKhatmah() {
        let store = newStore()
        for page in 1...Quran.pageCount { store.noteReaderPage(page) }
        XCTAssertEqual(store.khatmahPagesDone, Quran.pageCount,
                       "من بلغ آخر صفحةٍ في المصحف فقد أتمّها — لا صفحة بعدها تُحتسب بها")
    }

    /// الصفحة الأخيرة تُحتسب هي وما قبلها ببلوغها، ولا تُحتسب مرّتين: البلوغ
    /// المتكرّر — ورقةٌ تُقلب ذهابًا وإيابًا — لا يزيد العدّاد على المصحف.
    @MainActor
    func testTheLastPageIsCountedOnceAndTheCounterNeverPassesTheMushaf() {
        let store = newStore()
        for page in 1...Quran.pageCount { store.noteReaderPage(page) }
        for _ in 0..<5 { store.noteReaderPage(Quran.pageCount) }
        store.noteReaderPage(Quran.pageCount - 1)
        store.noteReaderPage(Quran.pageCount)
        XCTAssertEqual(store.khatmahPagesDone, Quran.pageCount)
    }

    /// ومن فتح آخر المصحف من أوّله لم تُكتب له ختمة: الاحتساب على ما قُرئ
    /// بالترتيب لا على الصفحة المفتوحة، وإلا كانت الختمة نقرةً في شريط التمرير.
    @MainActor
    func testOpeningTheLastPageWithoutReadingCountsNothing() {
        let store = newStore()
        store.noteReaderPage(1)
        store.noteReaderPage(2)
        for _ in 0..<3 { store.noteReaderPage(Quran.pageCount) }
        XCTAssertEqual(store.khatmahPagesDone, 1, "صفحةٌ واحدة أُتمَّت، والقفزة لا تُحتسب")
    }

    /// وبلا ختمةٍ قائمة لا يُكتب شيء أصلًا.
    @MainActor
    func testNothingIsCountedWithoutAnActiveKhatmah() {
        let store = newStore()
        store.cancelKhatmah()
        for page in 1...Quran.pageCount { store.noteReaderPage(page) }
        XCTAssertEqual(store.khatmahPagesDone, 0)
    }
}
