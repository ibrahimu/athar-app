import XCTest
@testable import Athar

/// النصّ الشرعيّ يُحلّ بالمعرّف من adhkar.json ولا يُكتب في السويفت. وهذه الحراسة
/// وُضعت بعد أن نُسخت عبارات المسبحة في أكثر من موضع، فزاغ تشكيلُ إحداها (t02) في
/// نسخة الساعة عن تشكيله في الملف: كسرةٌ زِيدت على اللام. المعرّف يمنع الزيغ
/// ابتداءً، وهذه الاختبارات تمنع أن يُحذف معرّفٌ أو يُعاد النسخُ خلسةً.
final class SacredTextSourceTests: XCTestCase {

    /// معرّفات مسبحة الساعة (AtharWatch/AtharWatchApp.swift). لا تصلها الاختبارات
    /// لأنها في هدف watchOS، فتُحرَس معرّفاتها هنا: أن يبقى لكلٍّ منها أصلٌ في الملف.
    private let watchPhraseIds = ["t01", "t02", "t04", "p01", "t03", "m17"]

    func testAdhkarLibraryLoadsSoNoWidgetEverNeedsAWrittenFallback() {
        XCTAssertFalse(AdhkarLibrary.categories.isEmpty, "adhkar.json لم يُحمَّل من الحزمة")
        XCTAssertFalse(AdhkarLibrary.shortItems.isEmpty,
                       "بلا أذكار قصيرة تخلو بطاقة الودجة — ولا يُكتب فيها ذكرٌ بديل")
        XCTAssertEqual(Set(AdhkarLibrary.allItems.map(\.id)).count, AdhkarLibrary.allItems.count,
                       "المعرّف مفتاحُ النصّ، فلا يتكرّر")
    }

    func testTasbihPhrasesComeFromTheLibraryVerbatim() {
        XCTAssertEqual(TasbihView.phrases.count, TasbihView.phraseIds.count,
                       "معرّفٌ لم يُحلّ: حُذف من adhkar.json أو أُعيدت تسميته")
        for (id, text) in zip(TasbihView.phraseIds, TasbihView.phrases) {
            let item = AdhkarLibrary.allItems.first { $0.id == id }
            XCTAssertEqual(text, item?.text, id)
            XCTAssertFalse(text.isEmpty, id)
        }
        // شريط العبارات يُميّز بالنصّ نفسه (ForEach(id: \.self)) وكذلك الاختيار المحفوظ،
        // فتكرارُ لفظين يُسقط أحدهما من الشريط ويُبهم أيّهما المختار.
        XCTAssertEqual(Set(TasbihView.phrases).count, TasbihView.phrases.count)
    }

    func testWatchTasbihIdentifiersStillResolveInTheLibrary() {
        for id in watchPhraseIds {
            let item = AdhkarLibrary.allItems.first { $0.id == id }
            XCTAssertNotNil(item, "معرّف مسبحة الساعة \(id) لا أصل له في adhkar.json")
            XCTAssertFalse(item?.text.isEmpty ?? true, id)
        }
        // ما اشتركت فيه الشاشتان لفظٌ واحد لا لفظان — وهذا عينُ ما انكسر.
        for id in watchPhraseIds where TasbihView.phraseIds.contains(id) {
            let text = AdhkarLibrary.allItems.first { $0.id == id }?.text
            XCTAssertEqual(text, TasbihView.phrases[TasbihView.phraseIds.firstIndex(of: id)!], id)
        }
    }

    /// العبارة الافتراضية في الدفتر لفظٌ مكتوب هناك، فيلزم أن يطابق لفظ الملف حرفًا
    /// بحرف — وإلا فُتحت المسبحة على نصّ لا نظير له في الشريط فلا تُرى مختارة.
    @MainActor
    func testDefaultTasbihPhraseIsVerbatimFromTheLibrary() {
        let suite = "athar.tests.tasbihphrase.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = AtharStore(defaults: defaults)
        XCTAssertTrue(AdhkarLibrary.allItems.contains { $0.text == store.tasbihPhrase },
                      "العبارة الافتراضية «\(store.tasbihPhrase)» لا نظير لها في adhkar.json")
        XCTAssertTrue(TasbihView.phrases.contains(store.tasbihPhrase),
                      "العبارة الافتراضية ليست من عبارات الشريط، فتُفتح المسبحة بلا رقاقة مختارة")
        defaults.removePersistentDomain(forName: suite)
    }
}
