import SwiftUI

// MARK: - كل الأقسام

/// شاشة تجمع أقسام التطبيق كلها، فما لا يسعه الشريط السفلي (خمسة فقط)
/// يبقى في متناول اليد هنا: الحج والعمرة، والقبلة، والحفظ، والتلاوة.
struct SectionsView: View {
    @EnvironmentObject private var store: AtharStore

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
                              subtitle: loc("افتحها من هنا، أو أضِفها للشريط من المظهر."),
                              tabs: offBar)
                    }
                    if !inBar.isEmpty {
                        group(title: loc("في الشريط السفلي"), subtitle: nil, tabs: inBar)
                    }
                    NavigationLink { AppearanceView() } label: {
                        AtharCard(padding: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 36, height: 36)
                                    .background(Circle().fill(Theme.accent.opacity(0.12)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc("ترتيب الشريط السفلي"))
                                        .font(Theme.display(15, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                    Text(loc("اختر الأقسام الخمسة التي تظهر أسفل الشاشة"))
                                        .font(Theme.display(11))
                                        .foregroundStyle(Theme.inkFaint)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                }
                                Spacer()
                                Image(systemName: "chevron.forward")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                        }
                    }
                    .pressable()
                }
                .padding(.horizontal, 18)
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

    private func group(title: String, subtitle: String?, tabs: [AppTab]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            SettingsGroupTitle(text: title)
            if let subtitle {
                Text(subtitle)
                    .font(Theme.display(11.5))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 6)
                    .padding(.bottom, 2)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tabs) { tab in
                    NavigationLink { SectionDestination(tab: tab) } label: { SectionTile(tab: tab) }
                        .pressable()
                }
            }
        }
    }
}

// MARK: - بطاقة قسم

struct SectionTile: View {
    let tab: AppTab
    @EnvironmentObject private var store: AtharStore

    private var tint: Color { Theme.accent(for: tab.accentKey) }

    var body: some View {
        AtharCard(padding: 14, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 9) {
                TabGlyph(tab: tab, size: 17)
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
