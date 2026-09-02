import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: AppTab = .home
    @State private var prayerMatIcon: Image?
    @State private var kaabaIcon: Image?

    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        switch tab {
        case .prayer: if let prayerMatIcon { prayerMatIcon } else { Image(systemName: tab.icon) }
        case .hajj:   if let kaabaIcon { kaabaIcon } else { Image(systemName: tab.icon) }
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
        .task {
            if prayerMatIcon == nil { prayerMatIcon = AtharIconRenderer.templateImage(PrayerMatShape()) }
            if kaabaIcon == nil { kaabaIcon = AtharIconRenderer.templateImage(KaabaShape()) }
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
