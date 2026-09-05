import SwiftUI
import WidgetKit

@main
struct AtharApp: App {
    @StateObject private var store = AtharStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
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
                .id(AppConfig.arabicOnly ? AppLanguage.ar : store.appLanguage)
                .tint(Theme.accent)
                // القارئ الظاهر يفرض سِمة ورقه على شريط الحالة أيضًا.
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
                store.startCloudSync()            // لا يفعل شيئًا إن كانت المزامنة مطفأة
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
