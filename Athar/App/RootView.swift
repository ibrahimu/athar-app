import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: AppTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(store.visibleTabs) { tab in
                view(for: tab)
                    .tabItem { Label(tab.title, systemImage: tab.icon) }
                    .tag(tab)
            }
        }
        .onChange(of: store.visibleTabs) { _, tabs in
            // لو حُذف التبويب المختار، ارجع لليوم (موجود دائمًا) بدل شاشة فارغة.
            if !tabs.contains(selection) { selection = .home }
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
        case .settings: SettingsView()
        }
    }

    /// تنقّل من شاشة اليوم — إن كان التبويب مخفيًا، افتح المصحف بدلًا منه.
    private func open(_ tab: AppTab) {
        selection = store.visibleTabs.contains(tab) ? tab : .home
    }
}
