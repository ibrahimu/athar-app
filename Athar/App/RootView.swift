import SwiftUI
import WidgetKit

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: AppTab = .home
    /// قسم طلبه «سيري» أو اختصار وليس في الشريط — يُعرض غطاءً كاملًا بزرّ إغلاق.
    @State private var coveredTab: AppTab?

    @ViewBuilder
    private func icon(for tab: AppTab) -> some View {
        switch tab {
        case .prayer: AtharIconRenderer.prayerMat
        case .hajj:   AtharIconRenderer.kaaba
        default:      Image(systemName: tab.icon)
        }
    }

    /// «ما الجديد» تُعرض بعد الإعداد الأول فقط (لا فوق شاشة الترحيب) ومرة لكل إصدار.
    @State private var showWhatsNew = false

    var body: some View {
        TabView(selection: $selection) {
            ForEach(store.visibleTabs) { tab in
                view(for: tab)
                    .tabItem { Label { Text(tab.title) } icon: { icon(for: tab) } }
                    .tag(tab)
            }
        }
        .onAppear {
            if store.didOnboard, store.whatsNewShownVersion != WhatsNewView.version { showWhatsNew = true }
        }
        .sheet(isPresented: $showWhatsNew) {
            WhatsNewView(onOpen: { tab in
                if store.visibleTabs.contains(tab) { selection = tab } else { store.pendingTab = tab }
            })
            .environmentObject(store)
            .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        // تغيّر المنطقة الزمنية (سفر): تُعاد جدولة التنبيهات وتُحدَّث الودجات فورًا،
        // وإلا بقيت تنبيهات الأذان على توقيت البلد السابق حتى الفتح التالي.
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await Reminders.rescheduleAll(store: store) }
            WidgetCenter.shared.reloadAllTimelines()
            if store.liveActivityEnabled { LiveActivityManager.sync(store: store) }
        }
        .onChange(of: store.visibleTabs) { _, tabs in
            // لو حُذف التبويب المختار، ارجع لليوم (موجود دائمًا) بدل شاشة فارغة.
            if !tabs.contains(selection) { selection = .home }
        }
        // طلب «سيري» قد يسبق رسم الجذر (إقلاع بارد) أو يأتي والتطبيق حيّ — نستهلكه في الحالين.
        .onAppear(perform: consumePendingTab)
        .onChange(of: store.pendingTab) { _, _ in consumePendingTab() }
        .onChange(of: store.didOnboard) { _, done in
            // غطاء الترحيب يُطوى بحركة أولًا؛ عرضٌ فوريّ فوقه يُرفض لأن الجذر ما زال يعرض شيئًا.
            guard done else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { consumePendingTab() }
        }
        .fullScreenCover(item: $coveredTab) { tab in
            NavigationStack {
                SectionDestination(tab: tab)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(loc("إغلاق")) { coveredTab = nil }
                        }
                    }
            }
            // الغطاء لا يرث الاتجاه ولا الصبغة من الجذر، فنفرضهما كما تفعل بقية الأوراق.
            .environmentObject(store)
            .environment(\.layoutDirection, .rightToLeft)
            .tint(Theme.accent)
        }
    }

    /// يستهلك طلب «سيري»/الاختصار مرة واحدة: تبويبٌ في الشريط يُختار، وما سواه يُعرض غطاءً —
    /// ثم يُصفَّر الطلب حتى لا يُعاد فتحه مع كل تغيّر لاحق في المخزن. يُؤجَّل ما دام
    /// الترحيب معروضًا، لأن الجذر لا يستطيع عرض غطاءين معًا.
    private func consumePendingTab() {
        guard let tab = store.pendingTab, store.didOnboard else { return }
        store.pendingTab = nil
        if store.visibleTabs.contains(tab) {
            coveredTab = nil
            selection = tab
        } else {
            coveredTab = tab
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
        case .sunan:    NavigationStack { SunanView(isRootTab: true) }
        case .settings: SettingsView()
        }
    }

    /// تنقّل من شاشة اليوم إلى تبويب حاضر في الشريط. أما المخفيّ منه فتدفعه «اليوم»
    /// في مكدّسها كبقيّة الأقسام — لا ورقة كاملة بلا زرّ إغلاق.
    private func open(_ tab: AppTab) {
        if store.visibleTabs.contains(tab) { selection = tab }
    }
}
