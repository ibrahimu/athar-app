import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: AppTab = .home
    /// تبويب مخفيّ من الشريط طُلب فتحه من شاشة اليوم — يُعرض كورقة كاملة.
    @State private var pushedTab: AppTab?

    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        switch tab {
        case .prayer: AtharIconRenderer.prayerMat
        case .hajj:   AtharIconRenderer.kaaba
        default:      Image(systemName: tab.icon)
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(store.visibleTabs) { tab in
                view(for: tab)
                    .tabItem { Label { Text(tab.title) } icon: { icon(for: tab) } }
                    .tag(tab)
            }
        }
        .onChange(of: store.visibleTabs) { _, tabs in
            // لو حُذف التبويب المختار، ارجع لليوم (موجود دائمًا) بدل شاشة فارغة.
            if !tabs.contains(selection) { selection = .home }
        }
        // كل شاشة تبويب تحمل NavigationStack خاصًّا بها، فنعرضها كما هي بلا تغليف.
        .sheet(item: $pushedTab) { tab in
            view(for: tab)
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
    }

    @ViewBuilder
    private func view(for tab: AppTab) -> some View {
        switch tab {
        case .home:     HomeView(onOpenTab: { open($0) })
        case .mushaf:   MushafView()
        case .adhkar:   AdhkarIndexView()
        case .prayer:   PrayerView(store: store)
        case .tasbih:   TasbihView()
        case .hajj:     HajjView()
        case .qibla:    NavigationStack { QiblaView(isRootTab: true) }
        case .hifz:     NavigationStack { HifzView(isRootTab: true) }
        case .recitation: NavigationStack { RecitationView(isRootTab: true) }
        case .settings: SettingsView()
        }
    }

    /// تنقّل من شاشة اليوم — وإن كان التبويب مخفيًا من الشريط عُرض كورقة،
    /// حتى لا تبتلع البطاقةُ النقرةَ بلا أي أثر.
    private func open(_ tab: AppTab) {
        if store.visibleTabs.contains(tab) {
            selection = tab
        } else {
            pushedTab = tab
        }
    }
}
