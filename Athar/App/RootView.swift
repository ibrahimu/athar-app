import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: AppTab = .home

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
        case .khatmah:  NavigationStack { KhatmahView(isRootTab: true) }
        case .wird:     NavigationStack { WirdView(isRootTab: true) }
        case .hadith:   NavigationStack { HadithView(isRootTab: true) }
        case .names:    NavigationStack { NamesView(isRootTab: true) }
        case .ahkam:    NavigationStack { AhkamView(isRootTab: true) }
        case .prayerLog: NavigationStack { PrayerLogView(isRootTab: true) }
        case .calendar: NavigationStack { HijriCalendarView(isRootTab: true) }
        case .zakat:    NavigationStack { ZakatView(isRootTab: true) }
        case .settings: SettingsView()
        }
    }

    /// تنقّل من شاشة اليوم إلى تبويب حاضر في الشريط. أما المخفيّ منه فتدفعه «اليوم»
    /// في مكدّسها كبقيّة الأقسام — لا ورقة كاملة بلا زرّ إغلاق.
    private func open(_ tab: AppTab) {
        if store.visibleTabs.contains(tab) { selection = tab }
    }
}
