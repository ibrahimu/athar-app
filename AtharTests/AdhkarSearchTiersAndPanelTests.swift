import XCTest
@testable import Athar

/// ثلاثُ عللٍ تجمعها علّةٌ واحدة: الشاشة تقول غير ما تعرفه البيانات — بحثٌ يخنق
/// درجاته الدنيا فلا تُبلغ، ولوحةٌ عرضُها مكتوبٌ لا مقيس، ورقمٌ هنديّ في نصٍّ حيّ.
final class AdhkarSearchTiersAndPanelTests: XCTestCase {

    private let easternDigits = CharacterSet(charactersIn: "٠١٢٣٤٥٦٧٨٩")

    // MARK: بحث الأذكار — «الخلاء»

    /// الشكوى بعينها. «الخلاء» كانت تُخرج ثلاثة أبوابٍ لا صلة لها بها: الدرجةُ
    /// المتساهلة في `ArabicSearch.matches` تُسقط الألفات فيصير مفتاحُها «لخل»،
    /// فتقع في «كَلِمَةِ الْإِخْلَاصِ» و«الْخَلِيفَةُ»، فلا تخيب درجةُ المتون قطّ،
    /// ولا يُبلغ المصدرُ والفضلُ من بعدها — وهما وحدهما يقولان أين تُقال «غُفْرَانَكَ».
    func testKhalaReachesTheAdhkarWhoseReferenceNamesIt() {
        let expected = AdhkarLibrary.categories.filter { category in
            category.items.contains { $0.reference.contains("الخلاء") || $0.virtue.contains("الخلاء") }
        }
        XCTAssertFalse(expected.isEmpty, "في البيانات أذكارٌ مصدرُها يذكر الخلاء")
        XCTAssertEqual(AdhkarSearch.categories(matching: "الخلاء").map(\.id), expected.map(\.id),
                       "تُخرج ما ذُكر فيه الخلاء وحده — لا بابًا زائدًا ولا ناقصًا")
    }

    /// ولا متنَ يقع فيه «الخلاء» أصلًا — فلولا تأخيرُ التساهل لبقيت درجةُ المتون
    /// ممتلئةً بما لا صلة له، وبقي البابُ الصحيح لا يُبلغ.
    func testKhalaMatchesNoDhikrTextPreciselyThoughTheLooseTierWouldClaimItDoes() {
        for category in AdhkarLibrary.categories {
            for dhikr in category.items {
                XCTAssertFalse(AdhkarSearch.precise(dhikr.text, "الخلاء"), "\(category.id)/\(dhikr.id)")
            }
        }
        XCTAssertTrue(AdhkarLibrary.categories.contains { category in
            category.items.contains { ArabicSearch.matches($0.text, "الخلاء") }
        }, "المتساهلة تدّعيها — ولهذا أُخِّرت إلى آخر الدرجات")
    }

    /// والمعروض تحت عنوان الباب هو الذي رشّحه، لا أوّلُ ما في الباب.
    func testPreviewPointsAtTheDhikrThatMatched() throws {
        let category = try XCTUnwrap(AdhkarSearch.categories(matching: "الخلاء").first)
        let match = try XCTUnwrap(AdhkarSearch.firstMatch(in: category, query: "الخلاء"))
        XCTAssertTrue(match.reference.contains("الخلاء") || match.virtue.contains("الخلاء"), match.id)
    }

    // MARK: ترتيب الدرجات

    /// درجةُ المتون تبقى أوّلًا ولا تُزاحَم: ما وجدته لا يُخلط به مصدرٌ ولا فضل،
    /// وإلا لأخرجت «رواه مسلم» الأبوابَ كلَّها على كل بحث.
    func testTextTierAnswersAloneWhenItAnswers() {
        for query in ["الحمد لله", "الحمدلله", "سبحان الله", "غفرانك"] {
            let found = AdhkarSearch.categories(matching: query)
            XCTAssertFalse(found.isEmpty, query)
            for category in found {
                XCTAssertTrue(AdhkarSearch.precise(category.title, query)
                              || AdhkarSearch.precise(category.subtitle, query)
                              || category.items.contains { AdhkarSearch.precise($0.text, query) },
                              "\(query) — \(category.id) خرج بلا متنٍ يطابقه")
            }
        }
    }

    /// وموضوعُ الذكر قد لا يقع إلا في مصدره: «الوضوء» و«المطر» لا يُنطقان في متنٍ،
    /// وإنما في «عند الفراغ من الوضوء» و«عند نزول المطر».
    func testSourceTierIsReachedWhenNoTextMatches() {
        for query in ["الوضوء", "المطر"] {
            let found = AdhkarSearch.categories(matching: query)
            XCTAssertFalse(found.isEmpty, query)
            for category in found {
                XCTAssertTrue(category.items.contains {
                    AdhkarSearch.precise($0.reference, query) || AdhkarSearch.precise($0.virtue, query)
                }, "\(query) — \(category.id)")
            }
        }
    }

    /// والتساهل لم يُلغَ بل أُخِّر: «الرحمان» كما يكتبها الناس تجد «الرَّحْمَنِ».
    func testLooseTierStillRescuesWhatPrecisionMisses() {
        let query = "الرحمان"
        let precise = AdhkarLibrary.categories.filter { category in
            AdhkarSearch.precise(category.title, query)
            || AdhkarSearch.precise(category.subtitle, query)
            || category.items.contains {
                AdhkarSearch.precise($0.text, query) || AdhkarSearch.precise($0.reference, query)
                    || AdhkarSearch.precise($0.virtue, query)
            }
        }
        XCTAssertTrue(precise.isEmpty, "لا تقع بالدقّة — وهذا موضع التساهل")
        XCTAssertFalse(AdhkarSearch.categories(matching: query).isEmpty, "ومع ذلك تجد")
    }

    /// الحقل الفارغ (وما لا يبقى منه مفتاح، كعلامة استفهام) يُبقي الأبواب كلّها.
    func testEmptyQueryKeepsEveryCategory() {
        for query in ["", "   ", "؟"] {
            XCTAssertEqual(AdhkarSearch.categories(matching: query).map(\.id),
                           AdhkarLibrary.categories.map(\.id), "«\(query)»")
        }
    }

    /// ومن طابق عنوانُ بابه لا يُعرض تحته سطرٌ زائد — العنوان يكفي.
    func testNoPreviewWhenTheTitleItselfMatched() throws {
        let category = try XCTUnwrap(AdhkarLibrary.categories.first)
        XCTAssertNil(AdhkarSearch.firstMatch(in: category, query: category.title))
    }

    // MARK: لوحة التفسير — قياسٌ لا مقدارٌ مكتوب

    /// أعراضٌ حقيقية: الآيباد بمقاساته، ونصفُ الشاشة المنقسمة، وداخلُ الهاتف
    /// المطويّ. في كلّها تبقى اللوحة بين حدَّيها، ويبقى للمصحف عرضُ هاتفٍ فأكثر —
    /// وكانت أربعمئة نقطةٍ مكتوبةً تترك له مئتين وثمانين في نصف الشاشة المنقسمة.
    func testPanelStaysWithinItsBoundsAndLeavesTheReaderAPhoneWidth() throws {
        let widths: [CGFloat] = [678, 725, 744, 834, 981, 1024, 1194, 1366]
        for available in widths {
            let panel = try XCTUnwrap(TafsirPanel.width(available: available), "\(available)")
            XCTAssertGreaterThanOrEqual(panel, TafsirPanel.minWidth, "\(available)")
            XCTAssertLessThanOrEqual(panel, TafsirPanel.maxWidth, "\(available)")
            XCTAssertGreaterThanOrEqual(available - panel, TafsirPanel.readerFloor, "\(available)")
        }
    }

    /// تكبر مع الشاشة وتصغر معها — وهذا كلّ الفرق عن المقدار المكتوب.
    func testPanelFollowsTheScreenInsteadOfStandingStill() throws {
        let wide = try XCTUnwrap(TafsirPanel.width(available: 1366))
        let middling = try XCTUnwrap(TafsirPanel.width(available: 834))
        let narrow = try XCTUnwrap(TafsirPanel.width(available: 678))
        XCTAssertGreaterThan(wide, middling)
        XCTAssertGreaterThan(middling, narrow)
        XCTAssertGreaterThan(wide, 400, "الشاشة الواسعة تستحقّ أكثر من الأربعمئة القديمة")
        XCTAssertLessThan(narrow, 400, "والضيّقة كانت تُخنق بها")
    }

    /// وما لا يسع الاثنين لا يُقسَم بينهما: غلافُ الهاتف المطويّ وداخلُه رأسيًّا،
    /// وقبل أوّل قياسٍ أصلًا — يأخذ المصحف الشاشة كلّها ويسقط زرُّ اللوحة معها.
    func testNoPanelWhereItWouldCrushTheReader() {
        let widths: [CGFloat] = [0, 375, 430, 604]
        for available in widths {
            XCTAssertNil(TafsirPanel.width(available: available), "\(available)")
        }
    }

    /// المقاسُ متّصلٌ لا حالتان: على كل عرضٍ بين الضيّق والواسع لا تنكسر القاعدة،
    /// ولا تظهر اللوحة ثمّ تختفي ثمّ تظهر. (توجيه آبل للهاتف المطويّ بعينه.)
    func testPanelBehavesAcrossTheWholeContinuumOfWidths() {
        var previous: CGFloat = 0
        var appeared = false
        for step in 0...1200 {
            let available = CGFloat(400 + step)
            guard let panel = TafsirPanel.width(available: available) else {
                XCTAssertFalse(appeared, "ظهرت ثمّ اختفت عند \(available)")
                continue
            }
            appeared = true
            XCTAssertGreaterThanOrEqual(panel, previous, "ضاقت اللوحة باتّساع الشاشة عند \(available)")
            XCTAssertGreaterThanOrEqual(available - panel, TafsirPanel.readerFloor, "\(available)")
            previous = panel
        }
        XCTAssertTrue(appeared)
    }

    // MARK: الأرقام الغربية في النصوص الحيّة

    /// أرقام التطبيق غربيةٌ في كل عدّادٍ وكل نصّ — فبطاقاتُ «ما الجديد» مثلها،
    /// وكان فيها رقمٌ هنديّ وحده يخالف ما يقرؤه المستخدم في الإشعار نفسه.
    func testWhatsNewCardsSpeakInWesternDigits() {
        for item in WhatsNewView.items {
            XCTAssertNil(item.title.rangeOfCharacter(from: easternDigits), item.id)
            XCTAssertNil(item.detail.rangeOfCharacter(from: easternDigits), item.id)
        }
    }

    /// والبطاقة تَعِد بما يقوله الزرّ حرفًا بحرف: لو تغيّرت دقائق التأجيل يومًا
    /// لكذّبت البطاقةُ الإشعارَ ولم ينتبه أحد.
    func testWhatsNewQuotesTheAthanActionVerbatim() throws {
        let actions = NotificationDelegate.makeCategories().flatMap(\.actions)
        let snooze = try XCTUnwrap(actions.first { $0.identifier == NotificationDelegate.snoozeAction })
        let card = try XCTUnwrap(WhatsNewView.items.first { $0.id == "athan" })
        XCTAssertTrue(card.detail.contains(snooze.title), "«\(snooze.title)» ليست كما في البطاقة")
    }

    /// وسقفُ التنبيهات يُقرأ من `Reminders` ويُكتب غربيًّا: كان الرقم مكتوبًا
    /// بالهندية في النصّ، وسائرُ الشاشة تقول العدد نفسه بالغربية.
    @MainActor
    func testNotificationCeilingTextIsWesternAndReadFromTheLimit() {
        let text = loc("سقف النظام %1$@ تنبيهًا معلّقًا — والأبعد موعدًا أوّل من يسقط. أوقف ما لا تحتاجه ليتّسع لغيره",
                       Reminders.systemLimit.counterText)
        XCTAssertTrue(text.contains(Reminders.systemLimit.counterText), "الرقم يُدرج فعلًا مكان القالب")
        XCTAssertFalse(text.contains("%1$@"), "ولا يبقى القالب ظاهرًا")
        XCTAssertNil(text.rangeOfCharacter(from: easternDigits))
        XCTAssertNil(Reminders.systemLimit.counterText.rangeOfCharacter(from: easternDigits))
    }
}
