import XCTest
@testable import Athar

/// الشاشةُ العريضة — اللوحُ، والهاتفُ المطويّ حين يُفتح. قاعدةُ آبل للمطويّ:
/// لا مقاساتٍ مكتوبةً بالعدد، ولا قرارَ تخطيطٍ مبنيًّا على اتجاه الشاشة؛ الصنفُ
/// والقياسُ وحدهما. وهذه الاختبارات تحرس القاعدة وقسمةَ «اليوم» عمودين.
final class WideCanvasTests: XCTestCase {

    private var viewsDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Athar/Views")
    }

    private func swiftFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .flatMap { url -> [URL] in
                var isDir: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
                if isDir.boolValue { return (try? swiftFiles(in: url)) ?? [] }
                return url.pathExtension == "swift" ? [url] : []
            }
    }

    /// `UIScreen.main.bounds` تقيس الجهازَ لا النافذة — وعلى المطويّ تكذب مرّتين:
    /// حين يُطبق، وحين يقاسم التطبيقُ الشاشةَ تطبيقًا آخر.
    func testNoViewMeasuresTheDeviceInsteadOfItsOwnWindow() throws {
        for file in try swiftFiles(in: viewsDirectory) {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.contains("UIScreen.main"), file.lastPathComponent)
        }
    }

    /// اتجاهُ الشاشة لا يُبنى عليه تخطيط: المطويُّ المفتوح قريبٌ من المربّع،
    /// فـ«طوليّ» و«عرضيّ» عليه لا تعنيان شيئًا. (بوصلةُ القبلة تقرأ الاتجاه
    /// لتصحيح الشمال لا لترتيب العناصر، وهي خارج مجلّد الشاشات.)
    func testNoViewBranchesOnInterfaceOrientation() throws {
        for file in try swiftFiles(in: viewsDirectory) {
            let text = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(text.contains("UIDevice.current.orientation"), file.lastPathComponent)
        }
    }

    /// قسمةُ «اليوم» عمودين: لا بطاقةَ تضيع، ولا بطاقةَ تتكرّر، وترتيبُ صاحبها
    /// محفوظٌ في القراءة — الأولى فوق اليمين، والثانية فوق اليسار.
    func testTwoColumnsKeepEveryCardOnceAndInOrder() {
        let cards = HomeCard.defaultOrder
        let split = HomeView.twoColumns(cards)
        let rejoined = (split.first + split.second).sorted { $0.0 < $1.0 }.map(\.1)
        XCTAssertEqual(rejoined, cards)
        XCTAssertEqual(split.first.map(\.1).first, cards.first)
        XCTAssertEqual(split.second.map(\.1).first, cards.dropFirst().first)
        XCTAssertEqual(split.first.count + split.second.count, cards.count)
        XCTAssertLessThanOrEqual(abs(split.first.count - split.second.count), 1)
    }

    /// بطاقةٌ واحدة: عمودٌ فيه واحدة وعمودٌ فارغ — ولا يتعطّل شيء.
    func testSingleCardDoesNotBreakTheSplit() {
        let split = HomeView.twoColumns([.prayer])
        XCTAssertEqual(split.first.map(\.1), [.prayer])
        XCTAssertTrue(split.second.isEmpty)
    }
}
