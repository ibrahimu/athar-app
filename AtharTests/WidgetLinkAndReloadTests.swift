import XCTest
@testable import Athar

/// حراسةٌ على النصّ لا على السلوك: ملفّا الودجة والنشاط الحيّ لا يُترجمان مع حزمة الاختبار
/// (هدفها التطبيق وحده)، والعلّتان المحروستان هنا لا يكشفهما محاكٍ ولا نظرةٌ عابرة —
/// إنعاشٌ عامّ يُنفق حصّة الأنواع الثمانية في كلّ حبّة، ورابطُ نقرٍ موضوعٌ حيث لا يعمل.
/// فتُقرأ الملفات من مكانها في المستودع ويُقابَل نصّها.
final class WidgetLinkAndReloadTests: XCTestCase {

    /// جذر المستودع من موضع هذا الملف: <الجذر>/AtharTests/<الملف>.
    private func source(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard let text = try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8) else {
            throw XCTSkip("تعذّرت قراءة \(path) — الحراسة نصّية لا تعمل إلا من المستودع نفسه")
        }
        return text
    }

    /// ما بين علامتين من النصّ، لتقتصر المقابلة على الموضع المقصود لا على الملفّ كلّه.
    private func slice(_ text: String, from: String, to: String) throws -> String {
        let start = try XCTUnwrap(text.range(of: from),
                                  "لم تُوجد العلامة «\(from)» — تغيّر الملفّ فراجع هذه الحراسة")
        let rest = text[start.upperBound...]
        let end = try XCTUnwrap(rest.range(of: to),
                                "لم تُوجد العلامة «\(to)» — تغيّر الملفّ فراجع هذه الحراسة")
        return String(rest[..<end.lowerBound])
    }

    // MARK: - إنعاش الودجات بعد الحبّة

    /// كانت كلّ حبّةٍ تنادي reloadAllTimelines فتُنعش الأنواع الثمانية جميعًا، وسبعةٌ منها
    /// لا تقرأ العدّ أصلًا — فتُستنفد حصّة الإنعاش اليومية قبل المساء، ويقف ما تعرضه
    /// الودجات كلّها على خبرٍ قديم جزاءً لمن أكثر من التسبيح.
    func testTheBeadReloadsOnlyTheWidgetThatShowsTheCount() throws {
        let intent = try source("Shared/TasbihIntent.swift")
        // النداء لا الذِّكر: التعليق في الملفّ يسمّي reloadAllTimelines ليُعرف ما تُرك ولماذا.
        XCTAssertFalse(intent.contains("WidgetCenter.shared.reloadAllTimelines"),
                       "إنعاشٌ عامّ في نيّة المسبحة: الحبّة الواحدة تُنفق حصّة الأنواع الثمانية")
        XCTAssertTrue(intent.contains("reloadTimelines(ofKind:"),
                      "الإنعاش يبقى مقصورًا على نوع الودجة التي تعرض العدّ")
    }

    /// اسمٌ لا يطابق `kind` يجعل الإنعاش نداءً في فراغ: لا خطأ ترجمةٍ ينبّه، ولا أثرَ
    /// على الشاشة — فيُقابَل الاسمان حرفًا بحرف لأن ملفّ الودجة لا يبلغه المشترك.
    func testTheReloadedKindMatchesTheWidgetItself() throws {
        let widget = try source("AtharWidget/AtharProgressWidget.swift")
        let declared = try slice(widget, from: "kind = \"", to: "\"")
        XCTAssertEqual(TasbihWidgets.kind, declared,
                       "الإنعاش على «\(TasbihWidgets.kind)» واسم الودجة «\(declared)»")
    }

    /// النيّة تُترجم مع الساعة أيضًا (تُنادى من الاختصارات هناك)، وعدّها تعرضه تعقيبتها
    /// لا ودجة الهاتف. فيُقابل اسمُ فرع watchOS اسمَ التعقيبة كما قوبل اسمُ الهاتف —
    /// وحزمةُ الاختبار هذه للهاتف، فلا سبيل إلى فرعها إلا من نصّ الملفّ.
    func testTheWatchBranchNamesTheComplicationThatShowsTheCount() throws {
        let complication = try source("AtharWatchWidget/TasbihComplication.swift")
        let declared = try slice(complication, from: "kind = \"", to: "\"")
        let intent = try source("Shared/TasbihIntent.swift")
        XCTAssertTrue(intent.contains("\"\(declared)\""),
                      "فرع الساعة لا يسمّي «\(declared)» — إنعاشٌ لا يبلغ تعقيبة المسبحة")
    }

    // MARK: - رابط النقر في النشاط الحيّ

    /// `widgetURL` داخل منطقةٍ موسّعة لا تَرِثه الهيئتان المضغوطة والصغرى، وهما أكثر ما
    /// يُرى من الجزيرة: كان العدّ التنازلي يُنقر فلا يُفتح شيء. وموضعه الذي يعمل فيه هو
    /// الجزيرة نفسها — `DynamicIsland.widgetURL` رابطٌ أصلٌ لهيئاتها كلّها.
    func testTheIslandTapTargetSitsWhereItWorks() throws {
        let activity = try source("AtharWidget/NextPrayerActivity.swift")

        let expanded = try slice(activity, from: "return DynamicIsland {", to: "} compactLeading:")
        XCTAssertFalse(expanded.contains("widgetURL"),
                       "رابطٌ داخل منطقةٍ موسّعة: لا يبلغ المضغوطة ولا الصغرى")

        let island = try slice(activity, from: "} minimal: {", to: "// MARK: - شاشة القفل")
        XCTAssertTrue(island.contains(".widgetURL(prayerLink)"),
                      "الجزيرة بلا widgetURL: نقرةٌ على العدّ لا تفتح المواقيت")
    }

    /// بطاقة شاشة القفل شجرةٌ أخرى لا تنالها جزيرةٌ، فلها رابطها وحدها.
    func testTheLockScreenCardKeepsItsOwnLink() throws {
        let activity = try source("AtharWidget/NextPrayerActivity.swift")
        let card = try slice(activity, from: "private struct NextPrayerLockScreenView", to: "// MARK: - المظهر")
        XCTAssertTrue(card.contains(".widgetURL(prayerLink)"),
                      "بطاقة القفل بلا رابط: نقرةٌ عليها لا تفتح المواقيت")
    }
}
