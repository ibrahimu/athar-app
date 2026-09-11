import XCTest
import UserNotifications
@testable import Athar

/// «كل متنٍ منقول يُعرض بعزوه» قاعدةُ التطبيق في كل بطاقة — وكان التنبيه وحده
/// يخرقها: يصل الحديث إلى شاشة القفل مجرّدًا من نسبته، فيقرؤه صاحبه ولا يدري
/// أفي الصحيحين هو أم في غيرهما، ولا يملك أن يتثبّت. وهذه أخطر مواضع الخرق:
/// التنبيه يُقرأ في لحظةٍ عابرة ولا يُفتح بعدها شيء يُراجَع فيه العزو.
///
/// وتحرس هذه الاختبارات أمرين معًا: أن يصل العزو، وأن يكون مقروءًا من البيانات
/// (`hadith.json` و`adhkar.json` و`quran.json`) بمعرّفه لا مكتوبًا في الشيفرة —
/// فإن صُحّح في الملف تبدّل في التنبيه من نفسه.
final class ReminderAttributionTests: XCTestCase {

    /// سقف المتن الذي ارتضاه الملف نفسه لمتنٍ منقول (قصّ «حديث اليوم» عند ١٨٠).
    /// وما زاد عليه يقصّه النظام من آخره — وآخرُه هو العزو بعينه.
    private static let bodyLimit = 180

    private func makeStore(_ label: String = #function) -> AtharStore {
        AtharStore(defaults: UserDefaults(suiteName: "athar.tests.attribution.\(label).\(UUID().uuidString)")!)
    }

    /// ما بين علامتَي اقتباس — لنقابل اللفظ الواصل بلفظ مصدره.
    private func fragment(in text: String, between open: String, and close: String) -> String? {
        guard let start = text.range(of: open),
              let end = text.range(of: close, range: start.upperBound..<text.endIndex)
        else { return nil }
        return String(text[start.upperBound..<end.lowerBound])
    }

    /// ما بعد آخر شرطة: العزو يجيء بها في كل متن.
    private func attribution(of body: String) -> String {
        String(body.split(separator: "—").last ?? "").trimmingCharacters(in: .whitespaces)
    }

    // MARK: - الآيات

    /// آية الذكر كانت تصل بلا سورةٍ ولا رقم. ويُتحقّق مع العزو أنّ اللفظ الواصل
    /// هو لفظ المصحف المضمَّن حرفًا حرفًا: نسخةٌ مكتوبة باليد تكفي لتُبطل العزو.
    @MainActor
    func testMorningAdhkarBodyCarriesItsAyahReference() throws {
        let store = makeStore()
        store.remindersEnabled = true
        store.adhkarReminderByPrayer = false

        let plan = Reminders.makePlan(store: store)
        let morning = try XCTUnwrap(plan.first { $0.identifier == Reminders.morningId })
        let body = morning.content.body
        let baqarah = try XCTUnwrap(Quran.surah(2))

        XCTAssertTrue(body.contains("\(baqarah.name): \(152.counterText)"), body)
        let quoted = try XCTUnwrap(fragment(in: body, between: "﴿ ", and: " ﴾"))
        let verse = try XCTUnwrap(baqarah.verse(152))
        XCTAssertTrue(verse.hasPrefix(quoted), "لفظ الآية في التنبيه ليس لفظ المصحف: \(quoted)")
    }

    /// وكذلك حين تُشتقّ الأذكار من وقت الصلاة: طريقان إلى نفس المتن، فلا يصحّ
    /// أن يُعزى في أحدهما ويُترك في الآخر.
    @MainActor
    func testMorningAdhkarByPrayerCarriesTheSameReference() throws {
        let store = makeStore()
        store.remindersEnabled = true
        store.adhkarReminderByPrayer = true

        let plan = Reminders.makePlan(store: store)
        let morning = try XCTUnwrap(plan.first { $0.identifier.hasPrefix(Reminders.morningId) })
        let baqarah = try XCTUnwrap(Quran.surah(2))
        XCTAssertTrue(morning.content.body.contains("\(baqarah.name): \(152.counterText)"),
                      morning.content.body)
    }

    // MARK: - الأحاديث

    /// تنبيه الاستعداد يحمل «الصلاة على وقتها»، وكان يحمله بلا نسبة. والعزو
    /// يُقرأ من `hadith.json` بمعرّفه، ويُتحقّق أنّ اللفظ الواصل من ذلك الحديث
    /// نفسه لا من حديثٍ آخر يشبهه — فالعزو الصحيح لمتنٍ غير متنه أسوأ من لا عزو.
    @MainActor
    func testPreAthanBodyCarriesTheStoredTakhrijOfItsHadith() throws {
        let store = makeStore()
        store.athanAlerts = true
        store.preAthanMinutes = 10

        let plan = Reminders.makePlan(store: store)
        let pre = try XCTUnwrap(plan.first { $0.identifier.hasPrefix(Reminders.athanPrefix + "pre.") })
        let hadith = try XCTUnwrap(HadithLibrary.hadith(id: "r312"))

        XCTAssertFalse(hadith.source.isEmpty, "تخريج r312 غاب عن البيانات، فلا شيء يُلحق بالمتن")
        XCTAssertEqual(attribution(of: pre.content.body), hadith.source, pre.content.body)
        let quoted = try XCTUnwrap(fragment(in: pre.content.body, between: "«", and: "»"))
        XCTAssertTrue(hadith.text.hadithSearchKey.contains(quoted.hadithSearchKey),
                      "المتن الواصل ليس من الحديث الذي عُزي إليه: \(quoted)")
    }

    /// تنبيه صيام الاثنين والخميس: تخريجه في البيانات مفصَّل — فيه أنّ مسلمًا رواه
    /// بغير ذكر الصوم، والتنبيه يذكر الصوم. فلا يكفي «رواه مسلم» ولا يصحّ اختصاره:
    /// يصل كما هو، و«انوِ الصيام» تنزل إلى السطر الثاني كي لا تزاحمه فيُقصّ.
    @MainActor
    func testFastingBodyCarriesItsFullStoredTakhrij() throws {
        let store = makeStore()
        store.fastingAlert = true

        let plan = Reminders.makePlan(store: store)
        let monday = try XCTUnwrap(plan.first { $0.identifier == Reminders.fastingPrefix + "1" })
        let hadith = try XCTUnwrap(HadithLibrary.hadith(id: "r1256"))

        XCTAssertFalse(hadith.source.isEmpty)
        XCTAssertTrue(monday.content.body.hasSuffix("— \(hadith.source)"), monday.content.body)
        let quoted = try XCTUnwrap(fragment(in: monday.content.body, between: "«", and: "»"))
        XCTAssertTrue(hadith.text.hadithSearchKey.contains(quoted.hadithSearchKey),
                      "المتن الواصل ليس من الحديث الذي عُزي إليه: \(quoted)")
        XCTAssertFalse(monday.content.subtitle.isEmpty, "دعوة النيّة انتقلت إلى السطر الثاني ولم تختفِ")
    }

    // MARK: - الاستغفار

    /// أربعة متون تتناوب على تنبيه الاستغفار: آيةٌ وثلاث فضائل أذكار. كلّها كانت
    /// تصل بلا نسبة، وكلّها لها مرجع مخزون في `adhkar.json` أو موضع في المصحف.
    @MainActor
    func testEveryIstighfarBodyCarriesAReferenceReadFromTheData() throws {
        let store = makeStore()
        store.istighfarAlerts = true
        store.istighfarEveryHours = 3

        let plan = Reminders.makePlan(store: store)
        let bodies = plan.filter { $0.identifier.hasPrefix(Reminders.istighfarPrefix) }.map(\.content.body)
        XCTAssertFalse(bodies.isEmpty)

        let hud = try XCTUnwrap(Quran.surah(11))
        var expected = Set(["\(hud.name): \(90.counterText)"])
        for id in ["m17", "i05", "sl02"] {
            let dhikr = try XCTUnwrap(AdhkarLibrary.allItems.first { $0.id == id }, id)
            XCTAssertTrue(dhikr.hasReference, "مرجع \(id) غاب عن البيانات، فلا شيء يُلحق بفضيلته")
            expected.insert(dhikr.reference)
        }

        for body in bodies {
            XCTAssertTrue(expected.contains(attribution(of: body)), body)
        }
        // التناوب يمرّ على المتون الأربعة كلها في يوم واحد، فلا يفلت منها متن بلا عزو.
        XCTAssertEqual(Set(bodies.map { attribution(of: $0) }), expected)

        // والآية آيةٌ بلفظ المصحف: «هود: 90» عزوٌ لما في المصحف لا لما نكتبه نحن.
        let ayahBody = try XCTUnwrap(bodies.first { $0.contains("﴿") })
        let quoted = try XCTUnwrap(fragment(in: ayahBody, between: "﴿ ", and: " ﴾"))
        let verse = try XCTUnwrap(hud.verse(90))
        XCTAssertTrue(verse.hasPrefix(quoted), "لفظ الآية في التنبيه ليس لفظ المصحف: \(quoted)")
    }

    // MARK: - الطول والميزانية

    /// العزو يجيء في ذيل السطر، فالسطر الطويل يبتلعه: يقصّه النظام من آخره فيصل
    /// المتن بلا نسبة — وهو عين ما نتوقّاه. فيُقاس كل متنٍ في الخطة بسقف الملف نفسه.
    @MainActor
    func testNoPlannedBodyOutgrowsTheCutThatWouldSwallowItsAttribution() {
        let store = makeStore()
        enableEverything(store)
        for request in Reminders.makePlan(store: store) {
            XCTAssertLessThanOrEqual(request.content.body.count, Self.bodyLimit,
                                     "\(request.identifier): \(request.content.body)")
        }
    }

    /// العزو نصٌّ يُلحق بمتنٍ قائم لا تنبيهٌ يُضاف، فميزانية الـ٦٤ لا تتحرّك به:
    /// لو تحرّكت لسقط آخر أيام الأذان صامتًا — وهو أغلى ما في الخطة.
    @MainActor
    func testAttributionAddsNoNotificationToTheSystemBudget() {
        let store = makeStore()
        enableEverything(store)
        let plan = Reminders.makePlan(store: store)
        XCTAssertLessThanOrEqual(plan.count, Reminders.systemLimit)
        XCTAssertEqual(Set(plan.map(\.identifier)).count, plan.count)
        let prayers = plan.filter {
            $0.identifier.hasPrefix(Reminders.athanPrefix)
                && !$0.identifier.hasPrefix(Reminders.athanPrefix + "pre.")
                && !$0.identifier.hasPrefix(Reminders.athanPrefix + "iq.")
        }
        XCTAssertGreaterThanOrEqual(prayers.count, 25)
    }

    private func enableEverything(_ store: AtharStore) {
        store.athanAlerts = true
        store.preAthanMinutes = 10
        store.iqamahMinutes = 15
        store.remindersEnabled = true
        store.adhkarReminderByPrayer = true
        store.hadithReminder = true
        store.qiyamAlert = true
        store.istighfarAlerts = true
        store.jumuahAlert = true
        store.fastingAlert = true
        store.whiteDaysAlert = true
        store.wirdEnabled = true
    }
}
