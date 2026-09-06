import SwiftUI
import CoreSpotlight
import WidgetKit

@main
struct AtharApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: AtharStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // خط «ثمانية» يُسجَّل قبل بناء المخزن وأي واجهة، حتى تجده Font.custom من أول رسم
        // (المخزن يضبط AppFont.current من المحفوظ في applyStoredTheme).
        FontLoader.registerAll()
        let store = AtharStore.shared
        // الخط المحفوظ قبل أول رسم — المخزن يضبط الطابع والنقش في init ولا يعرف الخط.
        store.applyStoredTheme()
        _store = StateObject(wrappedValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // تغيير اللغة يعيد بناء الجذر وحده — قبل غطاء الترحيب لا فوقه، وإلا هُدم الغطاء
                // وأُعيد عرضه من أوّله. أما خط الواجهة فتُعاد به مفاتيح التبويبات داخل RootView
                // لا الجذر كله، حتى لا تُطوى «الإعدادات» ولا يُهدم الترحيب مع كل بلاطة خط.
                .id(AppConfig.arabicOnly ? AppLanguage.ar.rawValue : store.appLanguage.rawValue)
                .fullScreenCover(isPresented: Binding(
                    get: { !store.didOnboard },
                    set: { if !$0 { store.didOnboard = true } }
                )) {
                    // الشاشة المعروضة لا ترث اتجاه الواجهة ولا صبغتها من الجذر، فنفرضهما صراحةً.
                    OnboardingView()
                        .environmentObject(store)
                        .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
                        .tint(Theme.accent)
                }
                .environmentObject(store)
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
                .tint(Theme.accent)
                // القارئ الظاهر يفرض سِمة ورقه على شريط الحالة أيضًا.
                // بحث iOS واختصارات الودجات: كلاهما يصبّ في وجهة معلّقة يعرضها الجذر.
                .onContinueUserActivity("com.apple.corespotlightitem") { activity in
                    if let id = activity.userInfo?["kCSSearchableItemActivityIdentifier"] as? String, let r = AppRoute(spotlightId: id) { store.pendingRoute = r }
                }
                .onOpenURL { url in if let r = AppRoute(url: url) { store.pendingRoute = r } }
                .preferredColorScheme({
                    switch store.readerScheme {
                    case .light: return .light
                    case .dark:  return .dark
                    case .none:  return store.appearance.colorScheme
                    }
                }())

        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                SpotlightIndexer.indexIfNeeded()  // مرة لكل إصدار من الفهرس
                store.startCloudSync()            // لا يفعل شيئًا إن كانت المزامنة مطفأة
                WatchSync.shared.activate()       // الساعة تأخذ مدينتك وطريقة حسابك من هنا
                WatchSync.shared.push(store: store)
                // Prayer alerts are only scheduled a week out; top them up on every launch.
                Task { await Reminders.rescheduleAll(store: store) }
                // النشاط الحيّ يُزامَن مع كل عودة: يُنهي ما انقضى ويطلب الصلاة القادمة —
                // وإن عطّله المستخدم أُنهي ما كان قائمًا حتى لا يبقى عدّ يتيم على شاشة القفل.
                if store.liveActivityEnabled {
                    LiveActivityManager.sync(store: store)
                } else {
                    LiveActivityManager.endAll()
                }
            case .background:
                store.pushCloudSync()
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
    }
}
