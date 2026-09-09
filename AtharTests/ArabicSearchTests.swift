import XCTest
@testable import Athar

/// مفتاح البحث الموحّد: ما يكتبه العربيّ بلوحته العادية يجب أن يجد ما في البيانات،
/// وإلا ظنّ أنّ آيته أو ذكره ليس في التطبيق.
final class ArabicSearchTests: XCTestCase {

    // MARK: المسافة — علّة «الحمدلله»

    /// الشكوى بعينها: «الحمد» تجد، و«الحمدلله» لا تجد — والمسافة وحدها هي الفارق.
    func testAttachedWordsFindSpacedText() {
        let ayah = Quran.text(AyahRef(surah: 1, ayah: 2))
        XCTAssertNotNil(ayah)
        let key = ArabicSearch.key(ayah!)
        XCTAssertTrue(key.contains(ArabicSearch.key("الحمد")), "«الحمد» تجد")
        XCTAssertTrue(key.contains(ArabicSearch.key("الحمدلله")), "«الحمدلله» متّصلةً تجد أيضًا")
        XCTAssertTrue(key.contains(ArabicSearch.key("الحمد لله")), "وبمسافةٍ كذلك")
    }

    func testQuranSearchFindsAttachedQuery() {
        XCTAssertFalse(Quran.search("الحمدلله", limit: 5).isEmpty)
        XCTAssertFalse(Quran.search("بسمالله", limit: 5).isEmpty)
        XCTAssertFalse(Quran.search("الحمد لله", limit: 5).isEmpty)
    }

    /// أوّل ما يُطابَق هو الفاتحة — فالبحث يقع على موضعه لا على أيّ موضع.
    func testFirstHitIsTheExpectedAyah() {
        XCTAssertEqual(Quran.search("الحمدللهربالعالمين", limit: 1).first,
                       AyahRef(surah: 1, ayah: 2))
    }

    // MARK: التشكيل والرسم العثماني

    func testStripsDiacriticsAndUthmaniMarks() {
        XCTAssertEqual(ArabicSearch.key("ٱلْحَمْدُ"), ArabicSearch.key("الحمد"))
        XCTAssertEqual(ArabicSearch.key("فَٱذْكُرُونِىٓ"), ArabicSearch.key("فاذكروني"))
    }

    /// الألف الخنجرية على أوجهها الثلاثة — يُكتب الإملائيّ فيُوجد العثمانيّ.
    func testDaggerAlifMapsToImlaaiSpelling() {
        XCTAssertEqual(ArabicSearch.key("ٱلصَّلَوٰةَ"), ArabicSearch.key("الصلاة"))
        XCTAssertEqual(ArabicSearch.key("ٱلزَّكَوٰةَ"), ArabicSearch.key("الزكاة"))
        XCTAssertEqual(ArabicSearch.key("عَلَىٰ"), ArabicSearch.key("على"))
        XCTAssertEqual(ArabicSearch.key("ٱلْعَٰلَمِينَ"), ArabicSearch.key("العالمين"))
    }

    /// والواو الأصلية لا تُؤكل: «ٱلسَّمَٰوَٰتِ» إملاؤها «السماوات» لا «السماات»،
    /// و«ٱلْوَٰلِدَيْنِ» إملاؤها «الوالدين». وهي في مئاتٍ من المواضع.
    func testRealWawSurvivesTheDaggerAlif() {
        XCTAssertEqual(ArabicSearch.key("ٱلسَّمَٰوَٰتِ"), ArabicSearch.key("السماوات"))
        XCTAssertEqual(ArabicSearch.key("وَبِٱلْوَٰلِدَيْنِ"), ArabicSearch.key("وبالوالدين"))
        XCTAssertEqual(ArabicSearch.key("ٱلْحَيَوٰةِ"), ArabicSearch.key("الحياة"))
    }

    func testQuranFindsWawWords() {
        XCTAssertFalse(Quran.search("السماوات", limit: 3).isEmpty)
        XCTAssertFalse(Quran.search("خلق السماوات والأرض", limit: 3).isEmpty)
        XCTAssertFalse(Quran.search("وبالوالدين احسانا", limit: 3).isEmpty)
        XCTAssertFalse(Quran.search("اموالهم", limit: 3).isEmpty)
    }

    /// «الرحمن» تُكتب بلا ألف وهي في المصحف بألفٍ خنجرية — يجدها التساهل.
    func testLooseFindsRahman() {
        XCTAssertFalse(Quran.search("الرحمن", limit: 3).isEmpty)
        XCTAssertFalse(Quran.search("الصلاة", limit: 3).isEmpty)
        XCTAssertFalse(Quran.search("الزكاة", limit: 3).isEmpty)
    }

    func testUnifiesHamzaTaMarbutaAndAlifMaqsura() {
        XCTAssertEqual(ArabicSearch.key("إسراء"), ArabicSearch.key("اسراء"))
        XCTAssertEqual(ArabicSearch.key("رحمة"), ArabicSearch.key("رحمه"))
        XCTAssertEqual(ArabicSearch.key("ذكرى"), ArabicSearch.key("ذكري"))
        XCTAssertEqual(ArabicSearch.key("مؤمن"), ArabicSearch.key("مومن"))
    }

    // MARK: الأرقام واللاتيني

    func testArabicIndicDigitsBecomeWestern() {
        XCTAssertEqual(ArabicSearch.key("٥٥"), "55")
        XCTAssertEqual(ArabicSearch.key("۵۵"), "55")
    }

    func testLatinIsLowercasedAndPunctuationDropped() {
        XCTAssertEqual(ArabicSearch.key("Al-Fatihah"), "alfatihah")
        XCTAssertEqual(ArabicSearch.key("«الذكر»، (١)"), ArabicSearch.key("الذكر1"))
    }

    // MARK: على بيانات التطبيق

    func testHadithSearchFindsAttachedQuery() {
        XCTAssertFalse(HadithLibrary.search("انماالاعمالبالنيات").isEmpty,
                       "«إنما الأعمال بالنيات» متّصلةً")
    }

    /// رقمُ الآية داخل الذكر («۝١») كان يبقى رقمًا لاصقًا بين الكلمتين، فمن كتب
    /// الآيتين متتابعتين كما يقرؤهما على الشاشة لم يجد شيئًا.
    func testAyahNumberMarksDoNotBreakMatching() {
        let ikhlas = "قُلْ هُوَ اللَّهُ أَحَدٌ ۝١ اللَّهُ الصَّمَدُ ۝٢ لَمْ يَلِدْ وَلَمْ يُولَدْ"
        let key = ArabicSearch.key(ikhlas)
        XCTAssertFalse(key.contains("1"), "لا يبقى رقمُ آيةٍ في المفتاح")
        XCTAssertTrue(key.contains(ArabicSearch.key("قل هو الله أحد الله الصمد")),
                      "الآيتان متتابعتين تُوجدان")
    }

    /// موضوعُ كثيرٍ من الأذكار لا يقع إلا في مصدره: «غُفْرَانَكَ» كلمةٌ واحدة،
    /// ومصدرها وحده يقول إنّها عند الخروج من الخلاء.
    func testAdhkarAreFoundByTheirReference() {
        for typed in ["المطر", "الوضوء", "الخلاء", "دخول المسجد", "سيد الاستغفار"] {
            let hit = AdhkarLibrary.categories.contains { c in
                c.items.contains { ArabicSearch.matches($0.reference, typed) || ArabicSearch.matches($0.virtue, typed) }
                    || c.items.contains { ArabicSearch.matches($0.text, typed) }
                    || c.title.searchKey.contains(typed.searchKey)
            }
            XCTAssertTrue(hit, "لا يُوجد شيء بـ«\(typed)»")
        }
    }

    /// الياء الصغيرة العليا حرفٌ يُنطق: «إِبْرَٰهِـۧمَ» و«ٱلنَّبِيِّـۧنَ».
    func testSmallHighYehIsALetter() {
        XCTAssertEqual(ArabicSearch.key("إِبْرَٰهِـۧمَ"), ArabicSearch.key("ابراهيم"))
        XCTAssertFalse(Quran.search("ابراهيم", limit: 3).isEmpty)
        XCTAssertFalse(Quran.search("خاتم النبيين", limit: 3).isEmpty)
    }

    /// المتساهل يُضاف بعد الدقيق لا بدلًا منه: مصادفةٌ واحدة كانت تحجب الصواب.
    func testDemonstrativesAreFound() {
        for typed in ["ذلك", "هذا", "اولئك", "الرحمن", "التوراة"] {
            XCTAssertFalse(Quran.search(typed, limit: 5).isEmpty, "«\(typed)» لا تُوجد")
        }
    }

    /// «إِسْرَٰٓءِيلَ»: الهمزةُ على الياء تُردّ ياءً فتلتقي بياءٍ بعدها.
    func testDoubledLettersCollapseInLoose() {
        XCTAssertFalse(Quran.search("بني اسرائيل", limit: 3).isEmpty)
    }

    /// رمز ﷺ حرفٌ في نظر النظام، فكان يقطع الجملة على من كتبها متّصلة.
    func testProphetSymbolIsDropped() {
        XCTAssertEqual(ArabicSearch.key("قال رسول الله ﷺ لأصحابه"),
                       ArabicSearch.key("قال رسول الله لأصحابه"))
    }

    /// «سورة الكهف» كما تُقرأ في الشاشة.
    func testSurahNameWithPrefix() {
        let kahf = Quran.surah(18)!
        XCTAssertTrue(ArabicSearch.matchesSurahName(kahf.name, "سورة الكهف"))
        XCTAssertTrue(ArabicSearch.matchesSurahName(kahf.name, "الكهف"))
        XCTAssertTrue(ArabicSearch.matchesSurahName(Quran.surah(55)!.name, "الرحمان"))
        XCTAssertFalse(ArabicSearch.matchesSurahName(kahf.name, "البقرة"))
    }

    /// تخريج الحديث وصفٌ يبحث به الناس.
    func testHadithFoundByCitation() {
        XCTAssertFalse(HadithLibrary.search("متفق عليه").isEmpty)
    }

    /// أسماء السور كما تُكتب: بلا «سورة»، وبـ«ال» ودونها حيث يصحّ.
    func testSurahNamesAreFound() {
        let kahf = Quran.surah(18)!
        XCTAssertTrue(kahf.name.searchKey.contains("الكهف".searchKey))
        let baqarah = Quran.surah(2)!
        XCTAssertTrue(baqarah.name.searchKey.contains("البقره".searchKey))
    }

    /// مدنٌ أُضيفت لأنّ من لم يجد مدينته اختار غيرها فاختلفت مواقيته.
    func testAddedSaudiCitiesAreFindable() {
        for typed in ["الاحساء", "الهفوف", "خميس مشيط", "خميسمشيط", "الخبر", "نجران", "الباحه"] {
            let n = typed.searchKey
            XCTAssertTrue(City.all.contains { $0.name.searchKey.contains(n) },
                          "لا تُوجد مدينة بـ«\(typed)»")
        }
    }

    /// إحداثيات المدن كلّها في مداها الصحيح — رقمٌ مقلوب يعني مواقيت بلدٍ آخر.
    func testEveryCityHasSaneCoordinates() {
        for c in City.all {
            XCTAssertTrue((-90...90).contains(c.latitude), "\(c.name): عرض خارج المدى")
            XCTAssertTrue((-180...180).contains(c.longitude), "\(c.name): طول خارج المدى")
            XCTAssertNotNil(TimeZone(identifier: c.tz), "\(c.name): منطقة زمنية مجهولة")
        }
        XCTAssertEqual(Set(City.all.map(\.id)).count, City.all.count, "المعرّفات لا تتكرّر")
    }

    /// المملكة: كل مدنها داخل حدودها تقريبًا — يكشف إحداثيًّا وقع في غير موضعه.
    func testSaudiCitiesLieInsideSaudiArabia() {
        for c in City.all where c.country == "السعودية" {
            XCTAssertTrue((16.0...32.5).contains(c.latitude), "\(c.name): عرض خارج المملكة")
            XCTAssertTrue((34.5...55.7).contains(c.longitude), "\(c.name): طول خارج المملكة")
        }
    }
}
