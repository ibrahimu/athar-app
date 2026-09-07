import UIKit
import BackgroundTasks
import UserNotifications

/// اختصارات الضغط المطوّل على الأيقونة (المصحف، المسبحة، القبلة، الحديث) — تُستقبل هنا وتُحوَّل وجهةً.
/// ومن هنا أيضًا يُنصَّب مندوب الإشعارات ويُسجَّل تجديد الخلفية.
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// معرّف مهمة التجديد — مُدرَج في `BGTaskSchedulerPermittedIdentifiers` بملف Info.
    static let refreshTaskId = "com.ibrahim.athar.refresh"

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem { Self.handle(item) }

        // قبل العودة بـtrue: نقرةُ الإشعار التي أيقظت التطبيق من إقلاعٍ بارد تُسلَّم
        // للمندوب في هذه اللحظة، فمن نصّبه بعدها فقدها وفُتحت الشاشة الخطأ.
        let center = UNUserNotificationCenter.current()
        center.delegate = NotificationDelegate.shared
        center.setNotificationCategories(NotificationDelegate.makeCategories())

        // التسجيل يجب أن يتمّ قبل انتهاء الإقلاع وإلا رفضه النظام.
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskId, using: nil) { task in
            Self.handleRefresh(task)
        }
        Self.scheduleRefresh()

        // مراقبة تبدّل المدينة: تبدأ مرة واحدة مع الإقلاع، وتُبقي الأذان على مواقيت
        // المكان الذي يراه المستخدم مهما بدّله ومن أي شاشة. (`assumeIsolated` لأن
        // الإقلاع على الخيط الرئيس قطعًا، والمُجدوِل معزول به.)
        MainActor.assumeIsolated { Reminders.startWatchingPlace(store: AtharStore.shared) }

        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(Self.handle(shortcutItem))
    }

    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let tab = AppTab(rawValue: item.type.replacingOccurrences(of: "com.ibrahim.athar.", with: "")) else { return false }
        DispatchQueue.main.async { AtharStore.shared.pendingRoute = .tab(tab) }
        return true
    }

    // MARK: - تجديد الخلفية

    /// سقف النظام أربعة وستون تنبيهًا معلّقًا، وخطة الأذان تستهلكها في نحو أسبوع.
    /// من لم يفتح «أثر» بعدها انقطع عنه الأذان بلا أن يدري. نصف يومٍ بين طلبٍ وطلب
    /// يكفي: النظام لا يعد بموعد، لكنه يوازن بين ما يطلبه التطبيق وما يستحقه من فرص.
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 12 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handleRefresh(_ task: BGTask) {
        // الطلب التالي أوّلًا: لو انقضت المهلة قبل أن تكتمل الخطة بقيت السلسلة قائمة.
        scheduleRefresh()

        let guardian = RefreshGuard()
        let work = Task { @MainActor in
            await Reminders.rescheduleAll(store: AtharStore.shared)
            guardian.finish(task, success: true)
        }
        task.expirationHandler = {
            work.cancel()
            guardian.finish(task, success: false)
        }
    }
}

/// إعلان الانتهاء مرة واحدة: النظام يعتبر تكراره خطأً، والمهلة قد تنقضي على خيط
/// النظام بينما الجدولة تكمل على الخيط الرئيس — فالقفل لا الترتيب.
private final class RefreshGuard {
    private let lock = NSLock()
    private var done = false

    func finish(_ task: BGTask, success: Bool) {
        lock.lock()
        let first = !done
        done = true
        lock.unlock()
        if first { task.setTaskCompleted(success: success) }
    }
}
