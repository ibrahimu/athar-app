import AppIntents
import WidgetKit

// MARK: - المسبحة في الودجة
//
// عَدٌّ في مكانه: الودجة تكتب في مجموعة التطبيق ما تكتبه شاشة المسبحة سواءً،
// فلا يفترق عددان لذاكرٍ واحد.

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
        // العدّ الواحد تقرؤه ودجاتٌ عدّة (المسبحة والمجموع والتتابع)، فتُنعش كلّها.
        WidgetCenter.shared.reloadAllTimelines()
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
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
