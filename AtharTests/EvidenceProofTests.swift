import XCTest
@testable import Athar

/// أدلّة المناسبات والزكاة: كانت متونها مكتوبةً في Occasions.swift وZakat.swift —
/// آيتان برسمٍ إملائي يخالف مصحف التطبيق العثماني ومقصوصتان دون تمامهما، وأحاديثُ
/// بألفاظٍ وتخريجاتٍ لا مقابل لها في hadith.json. فصار ما وُجد منها في البيانات يُحلّ
/// بمعرّفه، وهذه الاختبارات تحرس ألّا يعود نصٌّ شرعيٌّ يُكتب في السويفت باليد.
final class EvidenceProofTests: XCTestCase {

    /// كل معرّفٍ يُحال عليه لا بدّ أن يوجد في البيانات: لو أُخطئ في رقم حديثٍ أو آية
    /// لظهرت بطاقة المناسبة بدليلٍ فارغ — وفراغُ الدليل في شاشةٍ شرعية علّةٌ لا تُحتمل.
    func testEveryReferencedProofResolves() {
        for o in Occasions.all {
            switch o.proof {
            case .ayah, .hadith:
                XCTAssertFalse(o.evidence.isEmpty, "\(o.id): متن الدليل لم يُحلّ من البيانات")
                XCTAssertFalse(o.evidenceSource.isEmpty, "\(o.id): العزو لم يُحلّ من البيانات")
            case .unsourced(let text, let source):
                XCTAssertFalse(text.isEmpty, o.id)
                XCTAssertFalse(source.isEmpty, o.id)
            }
        }
    }

    /// المتن المُحال عليه يُعرض تامًّا كما في مصدره: لا «…» تقصّه، ولا زيادةَ عليه.
    func testResolvedProofsAreVerbatimAndUnabridged() throws {
        for o in Occasions.all {
            switch o.proof {
            case .ayah(let s, let a):
                let ayah = try XCTUnwrap(Quran.text(AyahRef(surah: s, ayah: a)), o.id)
                XCTAssertEqual(o.evidence, ayah, o.id)
            case .hadith(let id):
                let h = try XCTUnwrap(HadithLibrary.hadith(id: id), o.id)
                XCTAssertEqual(o.evidence, h.text, o.id)
                XCTAssertEqual(o.evidenceSource, h.citation, o.id)
            case .unsourced:
                continue
            }
            XCTAssertFalse(o.evidence.contains("…"), "\(o.id): متنٌ مقصوص")
        }
    }

    /// آية رمضان تأتي من المصحف العثماني بعينه: الرسم الإملائي «القرآن» كان مكتوبًا
    /// هنا باليد، ورسمُ المصحف «ٱلْقُرْءَانُ» — فاختلف حرف الشاشة عن حرف المصحف.
    func testRamadanAyahComesFromTheUthmaniMushaf() throws {
        let ramadan = try XCTUnwrap(Occasions.all.first(where: { $0.id == "ramadan" }))
        XCTAssertEqual(ramadan.proof, .ayah(surah: 2, ayah: 185))
        let ayah = try XCTUnwrap(Quran.surah(2)?.verse(185))
        XCTAssertEqual(ramadan.evidence, ayah)
        XCTAssertEqual(ramadan.evidenceSource, "سورة البقرة: 185")
    }

    /// المواضع الثلاثة التي بقي لفظها مكتوبًا لأنه ليس في بيانات التطبيق: زكاة الفطر،
    /// والنهي عن صوم العيدين، وأيام التشريق. وثباتُ هذه القائمة هو الحارس — فأيّ نصٍّ
    /// شرعيٍّ جديد يُكتب باليد في Occasions.swift يُسقط الاختبار قبل أن يبلغ الشاشة.
    func testHandWrittenProofsAreOnlyTheThreeKnownGaps() {
        let unsourced = Occasions.all.filter {
            if case .unsourced = $0.proof { return true }
            return false
        }.map(\.id)
        XCTAssertEqual(Set(unsourced), ["fitr", "adha", "tashreeq"])
    }

    /// عزو الحديث من الكتاب نفسه لا من عندنا: اسم الكتاب ورقمُه فيه ثم تخريج النووي.
    func testHadithProofsCiteTheirBook() {
        for o in Occasions.all {
            guard case .hadith = o.proof else { continue }
            XCTAssertTrue(o.evidenceSource.contains("رياض الصالحين")
                          || o.evidenceSource.contains("الأربعون النووية"), "\(o.id): \(o.evidenceSource)")
        }
    }

    /// أوّل دليلٍ تحت حاسبة الزكاة آيةُ البقرة تامّةً من المصحف. كانت مكتوبةً باليد
    /// «وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ» — رسمًا إملائيًّا لا يوافق ٱلصَّلَوٰةَ وٱلزَّكَوٰةَ في
    /// quran.json، ومقطوعةً دون آخر الآية. فمن قابل ما على الشاشة بمصحفه اختلفا.
    func testZakatEvidenceOpensWithTheMushafAyahInFull() throws {
        let first = try XCTUnwrap(Zakat.evidence.first)
        let ayah = try XCTUnwrap(Quran.text(AyahRef(surah: 2, ayah: 43)))
        XCTAssertEqual(first.text, ayah)
        XCTAssertEqual(first.source, "سورة البقرة: 43")
    }
}
