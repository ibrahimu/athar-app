import SwiftUI

// MARK: - كل الأقسام

/// شاشة تجمع أقسام التطبيق كلها في أربع عائلات — القرآن، الصلاة والعبادة، الذكر والعلم، الأدوات —
/// فما لا يسعه الشريط السفلي (خمسة فقط) يبقى في متناول اليد هنا، والحاضر في الشريط يُميَّز بعلامة.
struct SectionsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    /// تبديل التبويب الحيّ — تمرّره «اليوم» كي لا تُدفع نسخة ثانية من قسم قائم في الشريط.
    var onOpenTab: ((AppTab) -> Void)? = nil

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(Array(AppTab.Group.allCases.enumerated()), id: \.element) { i, g in
                        let tabs = AppTab.sections.filter { $0.group == g }
                        if !tabs.isEmpty {
                            group(title: g.title, tabs: tabs).appearStagger(i)
                        }
                    }

                    VStack(spacing: 10) {
                        NavigationLink { AppearanceView() } label: {
                            AtharLinkRow(icon: "square.grid.2x2",
                                         title: loc("ترتيب الشريط السفلي"),
                                         subtitle: loc("اختر الأقسام الخمسة التي تظهر أسفل الشاشة — أيّ قسم هنا يصلح تبويبًا"))
                        }
                        .pressable()
                        NavigationLink { AppearanceView(focus: .homeCards) } label: {
                            AtharLinkRow(icon: "rectangle.stack.fill",
                                         title: loc("بطاقات شاشة اليوم"),
                                         subtitle: loc("رتّب ما يظهر في «اليوم» أو أخفِ ما لا تحتاجه"))
                        }
                        .pressable()
                    }
                    .appearStagger(AppTab.Group.allCases.count)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 6)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("الأقسام"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    /// الأقسام الغائبة عن الشريط تُدفع هنا؛ أما الحاضرة فيه فيُبدَّل إليها ويُغلق هذا المكدّس،
    /// وإلا صار للمصحف والصلاة نسختان بحالتين منفصلتين.
    private func group(title: String, tabs: [AppTab]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SettingsGroupTitle(text: title)
            // محاذاة علوية: تحجز البلاطة سطرَي الوصف فتتساوى، وإن اختلفت بقيت رؤوسها
            // على خطّ واحد بدل أن يتوسّط الأقصر جارَه الأطول.
            // ثلاثة أعمدة على الشاشات العريضة (iPad) بدل اثنين.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top),
                                     count: sizeClass == .regular ? 3 : 2), spacing: 12) {
                ForEach(tabs) { tab in
                    let inBar = store.visibleTabs.contains(tab)
                    let tile = SectionTile(tab: tab, tint: Theme.accent(for: tab.accentKey), inBar: inBar)
                    if inBar, let open = onOpenTab {
                        Button { open(tab); dismiss() } label: { tile }
                            .pressable()
                    } else {
                        NavigationLink { SectionDestination(tab: tab) } label: { tile }
                            .pressable()
                    }
                }
            }
            .id("\(store.appTheme.rawValue)-\(store.unifyIcons)-\(store.visibleTabs.map(\.rawValue).joined())")
        }
    }
}

// MARK: - بطاقة قسم

struct SectionTile: View {
    let tab: AppTab
    /// اللون يُمرَّر قيمةً من الأب لا يُقرأ ساكنًا، ليُعاد رسم البلاطة فور تبديل الطابع.
    var tint: Color
    /// حاضر في الشريط السفلي — يُميَّز بنقطة صغيرة وكلمة، فيعرف المستخدم أين يجده.
    var inBar: Bool = false

    var body: some View {
        AtharCard(padding: 14, tint: tint) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack(alignment: .top) {
                    // الصلاة والحج رمزاهما مرسومان (سجّادة وكعبة) فلا يسعهما IconChip؛
                    // تُرسم الرقاقة بمقاسه المتوسّط نفسه: ٤٠ نقطة، ورمز ٤٥٪ منها، وصبغة ٠٫١٣.
                    TabGlyph(tab: tab, size: 18)
                        .foregroundStyle(tint)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(tint.opacity(0.13)))
                    Spacer(minLength: 4)
                    if inBar {
                        HStack(spacing: 4) {
                            Circle().fill(tint).frame(width: 5, height: 5)
                            Text(loc("في الشريط"))
                        }
                        .font(Theme.display(10, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(Capsule().fill(tint.opacity(0.10)))
                    }
                }
                Text(tab.title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(tab.blurb)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    // يُحجز سطران دائمًا، فتشترك بلاطات الصفّ في ارتفاع واحد وإن كان وصف
                    // إحداها سطرًا واحدًا وجارتها سطرين.
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - وجهة القسم

/// يفتح القسم داخل مكدّس «الأقسام» نفسه — بلا مكدّس ثانٍ ولا شريط عنوان مكرّر.
struct SectionDestination: View {
    let tab: AppTab

    var body: some View {
        Group {
            switch tab {
        case .home:       HomeView(onOpenTab: { _ in }, embedded: true)
        case .mushaf:     MushafView(embedded: true)
        case .adhkar:     AdhkarIndexView(embedded: true)
        case .prayer:     PrayerViewEmbedded()
        case .tasbih:     TasbihView(embedded: true)
        case .hajj:       HajjView(embedded: true)
        case .qibla:      QiblaView()
        case .hifz:       HifzView()
        case .recitation: RecitationView()
        case .khatmah:    KhatmahView()
        case .wird:       WirdView()
        case .hadith:     HadithView()
        case .names:      NamesView()
        case .ahkam:      AhkamView()
        case .prayerLog:  PrayerLogView()
        case .calendar:   HijriCalendarView()
        case .zakat:      ZakatView()
        case .sunan:      SunanView()
        case .settings:   SettingsView(embedded: true)
            }
        }
        // شاشة مدفوعة من «الأقسام» لا تحتاج شريط التبويبات فوقها — بعضها كان يبقيه
        // لأنه لا يعرف isRootTab، فيظهر الشريط على المصحف المضمَّن والقبلة وغيرهما.
        .toolbar(.hidden, for: .tabBar)
    }
}

/// الصلاة تحتاج المخزن في مُهيّئها، فتُبنى في غلافٍ صغير.
private struct PrayerViewEmbedded: View {
    @EnvironmentObject private var store: AtharStore
    var body: some View { PrayerView(embedded: true, store: store) }
}
