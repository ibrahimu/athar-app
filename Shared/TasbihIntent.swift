import AppIntents
import WidgetKit

// MARK: - المسبحة في الودجة
//
// عَدٌّ في مكانه: الودجة تكتب في مجموعة التطبيق ما تكتبه شاشة المسبحة سواءً،
// فلا يفترق عددان لذاكرٍ واحد.

/// النوع الذي يُنعَش بعد الحبّة: «أثري» على الهاتف — وهي وحدها التي تعرض عدّ المسبحة
/// والمجموع والتتابع، ومنها يُضغط الزرّ — وتعقيبةُ المسبحة على الساعة. والاسم منسوخٌ
/// نصًّا كما في WatchSyncReceiver لأن `kind` خاصٌّ بملفّ الودجة لا يبلغه المشترك،
/// فيحرسه اختبارٌ يقابل الاسمين حرفًا بحرف.
enum TasbihWidgets {
    #if os(watchOS)
    static let kind = "AtharWatchTasbih"
    #else
    static let kind = "AtharProgressWidget"
    #endif
}

extension AtharStore {
    /// ضغطة العدّ بكل ما يترتّب عليها: العدّاد، ودفتر اليوم، والمجموع، والتتابع —
    /// كما تكتبها شاشة المسبحة. ونقصُ واحدٍ منها يجعل ما تعدّه الودجة أثرًا
    /// لا يجده صاحبه في إحصائه.
    func countTasbih() {
        tasbihCount += 1
        noteDhikr()
        totalDhikrCount += 1
        touchStreak()
    }
}

/// عَدّة من الودجة نفسها. و`openAppWhenRun = false` هو المقصود كلّه:
/// من فتح التطبيق ليعدّ واحدة فقد شُغل عمّا جاء له.
struct TasbihTapIntent: AppIntent {
    static var title: LocalizedStringResource { "سبّح" }
    static var description: IntentDescription { IntentDescription("يزيد عدّ المسبحة واحدًا من الودجة بلا فتح التطبيق.") }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        AtharStore.shared.countTasbih()
        // الودجة التي ضُغط زرّها يُنعشها WidgetKit من تلقائه، وهذا النداء لأخواتها من
        // نوعها على الشاشة. وكان عامًّا (reloadAllTimelines) فيُنفق في كلّ حبّةٍ من حصّة
        // الإنعاش اليومية للأنواع الثمانية كلّها — وسبعةٌ منها لا تقرأ العدّ أصلًا،
        // فيُصيب الذاكرَ جفافُها في آخر النهار ثمنًا لتسبيحه.
        WidgetCenter.shared.reloadTimelines(ofKind: TasbihWidgets.kind)
        return .result()
    }
}

/// تصفير عدّاد المسبحة من الودجة — كزرّ «إعادة العدّ» في الشاشة سواءً:
/// العدّاد وحده يعود صفرًا، ويبقى مجموع الأذكار وأيام التتابع على حالهما،
/// فما مضى من ذكرٍ لا يُمحى بضغطة.
struct TasbihResetIntent: AppIntent {
    static var title: LocalizedStringResource { "تصفير المسبحة" }
    static var description: IntentDescription { IntentDescription("يعيد عدّاد المسبحة إلى الصفر بلا فتح التطبيق.") }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        AtharStore.shared.tasbihCount = 0
        // والتصفير كالعدّ: العدّاد لا تعرضه إلا «أثري»، فلا يُنعَش سواها.
        WidgetCenter.shared.reloadTimelines(ofKind: TasbihWidgets.kind)
        return .result()
    }
}
