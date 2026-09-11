import XCTest
@testable import Athar

/// لقطةُ المحمَّل في CarPlay: كانت كلُّ إعادةِ بناءٍ للقوائم تسأل نظامَ الملفّات عن كلّ
/// سورةٍ لكلّ قارئ — ألفان وأربعمئةٍ وسبعةٌ وخمسون نداءً على الممثّل الرئيس، بنبضةٍ كلَّ
/// ثانيتين — والسائقُ أولى الناس بألّا تتلعثم شاشته. صارت اللقطةُ تُقرأ بمسحٍ واحدٍ
/// للمجلّدات (ثمانيةَ عشرَ نداءً) خارج الممثّل الرئيس، وتُبنى القوائمُ منها.
/// فالذي يُحرَس هنا: أن تقول اللقطةُ ما يقوله القرصُ تمامًا — لا تزيد سورةً ولا تُسقطها.
final class CarPlayDownloadsTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("athar-carplay-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
        root = nil
    }

    /// يكتب سورًا لقارئ بالاسم الذي يكتبه المنزّل نفسه: ثلاثُ خاناتٍ ثمّ mp3.
    private func write(_ reciter: String, surahs: [Int]) throws {
        let dir = root.appendingPathComponent(reciter, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for s in surahs {
            let name = String(format: "%03d", s) + ".mp3"
            FileManager.default.createFile(atPath: dir.appendingPathComponent(name).path,
                                           contents: Data(count: 8))
        }
    }

    // MARK: قراءة القرص

    /// الحارسُ الأهمّ: اللقطةُ الرخيصة يجب أن تطابق السؤالَ الغالي عن كلّ ملفٍّ على حدة،
    /// وإلا عرضَت السيارةُ «محمَّلة» لسورةٍ ليست عندها، أو خبّأت واحدةً تعمل بلا شبكة.
    func testSnapshotAgreesWithThePerFileCheckForEverySurah() throws {
        let owned = [1, 2, 18, 36, 55, 56, 67, 113, 114]
        try write("afs", surahs: owned)
        let snap = CarPlayDownloads.read(root: root)
        let dir = root.appendingPathComponent("afs", isDirectory: true)
        for s in 1...114 {
            let path = dir.appendingPathComponent(String(format: "%03d", s) + ".mp3").path
            XCTAssertEqual(snap.surahs("afs").contains(s),
                           FileManager.default.fileExists(atPath: path),
                           "اللقطة تخالف القرصَ في السورة \(s)")
        }
    }

    func testCountsAreKeptPerReciterNotMixed() throws {
        try write("afs", surahs: [1, 2, 3])
        try write("husr", surahs: [36])
        let snap = CarPlayDownloads.read(root: root)
        XCTAssertEqual(snap.count("afs"), 3)
        XCTAssertEqual(snap.count("husr"), 1)
        XCTAssertEqual(snap.surahs("afs").contains(36), false,
                       "سورةُ قارئٍ لا تُحسب لغيره — وتبديلُ القارئ يقرأ اللقطة نفسها")
    }

    /// قارئٌ لم يُنزَّل له شيء لا مجلّدَ له أصلًا: يُسأل عنه فيُجاب بصفرٍ لا بانهيار.
    func testUnknownReciterIsEmptyNotAbsent() {
        let snap = CarPlayDownloads.read(root: root)
        XCTAssertEqual(snap.count("لا-أحد"), 0)
        XCTAssertTrue(snap.surahs("لا-أحد").isEmpty)
    }

    /// جذرٌ غير موجود — أوّلُ تشغيلٍ قبل أيّ تنزيل: لقطةٌ فارغة، لا رمية.
    func testMissingRootYieldsEmptySnapshot() {
        let gone = root.appendingPathComponent("ليس-هنا", isDirectory: true)
        XCTAssertEqual(CarPlayDownloads.read(root: gone), CarPlayDownloads())
    }

    // MARK: قراءة الأسماء

    /// ما ليس سورةً لا يُعدّ سورة: ملفٌّ غريب، أو رقمٌ خارج المصحف، أو امتدادٌ آخر.
    /// (والعدُّ هو ما يُعرض للسائق «١٢ محمَّلة»، فزيادةُ واحدٍ كذبٌ يراه.)
    func testStrayFilesAreNotCountedAsSurahs() {
        let snap = CarPlayDownloads.make([
            "afs": ["001.mp3", "114.mp3", "000.mp3", "115.mp3",
                    "ملاحظة.txt", "002.mp3.tmp", ".DS_Store", "abc.mp3"]
        ])
        XCTAssertEqual(snap.surahs("afs"), [1, 114])
        XCTAssertEqual(snap.count("afs"), 2)
    }

    /// التكرارُ لا يضاعف العدّ — المجموعةُ تحفظ ذلك، والعدّ يُقرأ منها لا من الملفّات.
    func testRepeatedNamesCountOnce() {
        let snap = CarPlayDownloads.make(["afs": ["036.mp3", "036.mp3"]])
        XCTAssertEqual(snap.count("afs"), 1)
    }

    // MARK: المقارنة

    /// المسحُ يجري ثمّ تُقارن اللقطةُ بسابقتها، ولا تُعاد صياغةُ القوائم إلا إن تبدّلتا.
    /// فلو ساوت اللقطةُ نفسَها ولم تُساوِ ما يخالفها، بقيت الشاشةُ ساكنةً بلا سبب.
    func testEqualityDrivesTheRebuildDecision() {
        let a = CarPlayDownloads.make(["afs": ["001.mp3", "002.mp3"]])
        let b = CarPlayDownloads.make(["afs": ["002.mp3", "001.mp3"]])
        let c = CarPlayDownloads.make(["afs": ["001.mp3"]])
        XCTAssertEqual(a, b, "ترتيبُ أسماء الملفّات لا يعني شيئًا — لا يُعاد البناء لأجله")
        XCTAssertNotEqual(a, c, "سورةٌ حُذفت: تبدّلٌ يجب أن تراه القائمة")
    }
}
