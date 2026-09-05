import SwiftUI

/// السنن الرواتب: خطّ زمني ليوم كامل — لكل فريضة ما قبلها وما بعدها من الرواتب،
/// المؤكّدة ممتلئة والمستحبّة مفرَّغة، وتحتها سنن الصلاة الأخرى (الوتر، الضحى...).
struct SunanView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    @State private var selected: SunnahPrayer?
    @State private var times: PrayerTimes?

    private var tint: Color { Theme.accent(for: "dawn") }
    private let prayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 18) {
                    hero.appearStagger(0)
                    timeline.appearStagger(1)
                    legend.appearStagger(2)
                    othersSection.appearStagger(3)
                    footer.appearStagger(4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("السنن الرواتب"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .onAppear { times = store.prayerTimes(for: Date()) }
        .sheet(item: $selected) { s in
            SunnahDetailSheet(sunnah: s, tint: tint)
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: البطاقة العليا

    private var hero: some View {
        AtharCard(padding: 18, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconChip(icon: "rays", tint: tint, size: .lg)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loc("%1$@ ركعة في اليوم والليلة", SunanLibrary.muakkadahCount.counterText))
                            .font(Theme.display(18, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(loc("الرواتب المؤكّدة التي داوم عليها النبي ﷺ"))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Capsule().fill(Theme.goldGradient).frame(width: 46, height: 3).opacity(0.8)
                Text(SunanLibrary.twelveHadith.text)
                    .font(Theme.dhikrFont(size: 17, scale: store.fontScale))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                Text(SunanLibrary.twelveHadith.source)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: الخطّ الزمني

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("يومك مع الرواتب"), tint: tint)
            SettingsCard {
                ForEach(Array(prayers.enumerated()), id: \.element) { i, p in
                    prayerRow(p)
                    if i < prayers.count - 1 { SettingsDivider(inset: 0) }
                }
            }
        }
    }

    /// صفّ فريضة: رواتبها القبلية في البداية، ثم الفريضة ووقتها، ثم البعدية.
    private func prayerRow(_ p: Prayer) -> some View {
        let color = Theme.accent(for: p.accentKey)
        let before = SunanLibrary.before(p)
        let after = SunanLibrary.after(p)
        return HStack(spacing: 10) {
            pillColumn(before, label: loc("قبل"), color: color)
                .frame(width: 64, alignment: .center)

            VStack(spacing: 4) {
                ZStack {
                    Circle().fill(color.opacity(0.13)).frame(width: 46, height: 46)
                    Image(systemName: p.icon).font(.system(size: 18, weight: .medium)).foregroundStyle(color)
                }
                Text(p.title).font(Theme.display(14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(times?[p].map(clock) ?? "—")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkFaint)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)

            pillColumn(after, label: loc("بعد"), color: color)
                .frame(width: 64, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func pillColumn(_ items: [SunnahPrayer], label: String, color: Color) -> some View {
        VStack(spacing: 5) {
            if items.isEmpty {
                Text("—").font(Theme.display(12)).foregroundStyle(Theme.hairline)
            } else {
                ForEach(items) { s in pill(s, color: color) }
            }
            Text(label).font(Theme.display(10)).foregroundStyle(Theme.inkFaint)
        }
    }

    /// رقاقة راتبة: العدد كبير، المؤكّدة ممتلئة بلون الفريضة والمستحبّة مفرَّغة.
    private func pill(_ s: SunnahPrayer, color: Color) -> some View {
        let strong = s.emphasis == .muakkadah
        return Button { selected = s; Haptics.tap(enabled: store.hapticsEnabled) } label: {
            Text(s.rakaat)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(strong ? Theme.onAccent : color)
                .frame(width: 44, height: 30)
                .background(Capsule().fill(strong ? color : color.opacity(0.08)))
                .overlay(Capsule().strokeBorder(color.opacity(strong ? 0 : 0.6), lineWidth: 1))
        }
        .pressable(scale: 0.92)
        .accessibilityLabel(loc("%1$@ — %2$@ ركعة، %3$@", s.title, s.rakaat, s.emphasis.title))
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(filled: true, text: loc("راتبة مؤكّدة"))
            legendItem(filled: false, text: loc("مستحبّة"))
            Spacer()
            Text(loc("انقر أي رقم لتفصيله")).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 4)
    }

    private func legendItem(filled: Bool, text: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(filled ? tint : tint.opacity(0.08))
                .overlay(Capsule().strokeBorder(tint.opacity(filled ? 0 : 0.6), lineWidth: 1))
                .frame(width: 22, height: 12)
            Text(text).font(Theme.display(11)).foregroundStyle(Theme.inkSoft)
        }
    }

    // MARK: سنن أخرى

    private var othersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("سنن أخرى للصلاة"), tint: tint)
            SettingsCard {
                ForEach(Array(SunanLibrary.others.enumerated()), id: \.element.id) { i, s in
                    Button { selected = s; Haptics.tap(enabled: store.hapticsEnabled) } label: {
                        SettingsRow(icon: s.icon, tint: tint, title: s.title,
                                    subtitle: loc("%1$@ ركعة · %2$@", s.rakaat, s.emphasis.title)) {
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                    .buttonStyle(.plain)
                    if i < SunanLibrary.others.count - 1 { SettingsDivider() }
                }
            }
        }
    }

    private var footer: some View {
        Text(SunanLibrary.note)
            .font(Theme.display(11))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }

    private func clock(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = store.placeTimeZone
        f.dateFormat = "h:mm"
        return f.string(from: d)
    }
}

// MARK: - ورقة التفصيل

private struct SunnahDetailSheet: View {
    let sunnah: SunnahPrayer
    let tint: Color
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AtharBackground(tint: tint)
            ScrollView {
                VStack(spacing: 16) {
                    Capsule().fill(Theme.hairline).frame(width: 36, height: 5).padding(.top, 10)

                    AtharCard(padding: 18, elevation: .e2, tint: tint) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                IconChip(icon: sunnah.icon, tint: tint, size: .lg)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(sunnah.title).font(Theme.display(20, weight: .bold)).foregroundStyle(Theme.ink)
                                    Text(loc("%1$@ ركعة · %2$@", sunnah.rakaat, sunnah.emphasis.title))
                                        .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                                }
                            }
                            Text(sunnah.detail)
                                .font(Theme.display(15))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SettingsGroupTitle(text: loc("الدليل"), tint: tint)
                        ForEach(sunnah.evidence, id: \.self) { e in
                            AtharCard(padding: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("«\(e.text)»")
                                        .font(Theme.dhikrFont(size: 17, scale: store.fontScale))
                                        .foregroundStyle(Theme.ink)
                                        .lineSpacing(7)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(e.source).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
            }
        }
    }
}
