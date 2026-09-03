import SwiftUI

// MARK: - كل الأقسام

/// شاشة تجمع أقسام التطبيق كلها، فما لا يسعه الشريط السفلي (خمسة فقط)
/// يبقى في متناول اليد هنا: الحج والعمرة، والقبلة، والحفظ، والتلاوة.
struct SectionsView: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    /// تبديل التبويب الحيّ — تمرّره «اليوم» كي لا تُدفع نسخة ثانية من قسم قائم في الشريط.
    var onOpenTab: ((AppTab) -> Void)? = nil

    private var inBar: [AppTab] { store.visibleTabs.filter { $0 != .home } }
    private var offBar: [AppTab] {
        AppTab.allCases.filter { $0 != .home && $0 != .settings && !store.visibleTabs.contains($0) }
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !offBar.isEmpty {
                        group(title: loc("ليست في الشريط"),
                              subtitle: loc("افتحها من هنا، أو أضِفها إلى الشريط من «ترتيب الشريط السفلي» أدناه."),
                              tabs: offBar, pushes: true)
                            .appearStagger(0)
                    }
                    if !inBar.isEmpty {
                        group(title: loc("في الشريط السفلي"), subtitle: nil, tabs: inBar, pushes: false)
                            .appearStagger(1)
                    }
                    NavigationLink { AppearanceView() } label: {
                        AtharLinkRow(icon: "square.grid.2x2",
                                     title: loc("ترتيب الشريط السفلي"),
                                     subtitle: loc("اختر الأقسام الخمسة التي تظهر أسفل الشاشة"))
                    }
                    .pressable()
                    .appearStagger(2)
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
    private func group(title: String, subtitle: String?, tabs: [AppTab], pushes: Bool) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SettingsGroupTitle(text: title)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tabs) { tab in
                    let tile = SectionTile(tab: tab, tint: Theme.accent(for: tab.accentKey))
                    if !pushes, let open = onOpenTab {
                        Button { open(tab); dismiss() } label: { tile }
                            .pressable()
                    } else {
                        NavigationLink { SectionDestination(tab: tab) } label: { tile }
                            .pressable()
                    }
                }
            }
        }
    }
}

// MARK: - بطاقة قسم

struct SectionTile: View {
    let tab: AppTab
    /// اللون يُمرَّر قيمةً من الأب لا يُقرأ ساكنًا، ليُعاد رسم البلاطة فور تبديل الطابع.
    var tint: Color

    var body: some View {
        AtharCard(padding: 14, tint: tint) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                // الصلاة والحج رمزاهما مرسومان (سجّادة وكعبة) فلا يسعهما IconChip؛
                // تُرسم الرقاقة بمقاسه المتوسّط نفسه: ٤٠ نقطة، ورمز ٤٥٪ منها، وصبغة ٠٫١٣.
                TabGlyph(tab: tab, size: 18)
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(tint.opacity(0.13)))
                Text(tab.title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(tab.blurb)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(2)
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

    @ViewBuilder
    var body: some View {
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
        case .settings:   SettingsView(embedded: true)
        }
    }
}

/// الصلاة تحتاج المخزن في مُهيّئها، فتُبنى في غلافٍ صغير.
private struct PrayerViewEmbedded: View {
    @EnvironmentObject private var store: AtharStore
    var body: some View { PrayerView(embedded: true, store: store) }
}
