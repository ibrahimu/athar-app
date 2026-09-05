import SwiftUI
import WidgetKit

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: AppTab = .home
    /// قسم طلبه «سيري» أو اختصار وليس في الشريط — يُعرض غطاءً كاملًا بزرّ إغلاق.
    @State private var coveredTab: AppTab?
    /// «ما الجديد» تراكبٌ فوق التبويبات كلها: الأوراق المطلوبة لحظة الإقلاع كانت تُهدم فور ظهورها.
    @State private var showWhatsNew = false

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
        // تغيّر المنطقة الزمنية (سفر): تُعاد جدولة التنبيهات وتُحدَّث الودجات فورًا،
        // وإلا بقيت تنبيهات الأذان على توقيت البلد السابق حتى الفتح التالي.
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            Task { await Reminders.rescheduleAll(store: store) }
            WidgetCenter.shared.reloadAllTimelines()
            if store.liveActivityEnabled { LiveActivityManager.sync(store: store) }
        }
        .task {
            guard store.didOnboard,
                  CommandLine.arguments.contains("-whatsnew") || store.whatsNewShownVersion != WhatsNewView.version
            else { return }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(Motion.smooth) { showWhatsNew = true }
        }
        .overlay {
            if showWhatsNew {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                        .onTapGesture { closeWhatsNew() }
                    WhatsNewView(onClose: closeWhatsNew, onOpen: { tab in
                        if store.visibleTabs.contains(tab) { selection = tab } else { store.pendingTab = tab }
                    })
                    .environmentObject(store)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.top, 58)
                    .padding(.bottom, 24)
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 10)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(10)
            }
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

    private func closeWhatsNew() {
        withAnimation(Motion.smooth) { showWhatsNew = false }
        store.whatsNewShownVersion = WhatsNewView.version
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
