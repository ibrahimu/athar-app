import SwiftUI

/// تخصيص تنبيه كل فريضة: تشغيل أو إيقاف، الصوت (أذان / نغمة / صامت)، وتنبيه قبلي خاص.
struct PrayerAlertsView: View {
    @EnvironmentObject private var store: AtharStore
    private let prayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
    private let preChoices = [0, 5, 10, 15, 20, 30]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.inkFaint).padding(.top, 1)
                    Text(loc("يسري على تنبيه دخول الوقت. «اتّبع العام» يأخذ دقائق التنبيه القبلي من الإعداد العام."))
                        .font(Theme.display(12)).foregroundStyle(Theme.inkSoft).frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.surfaceAlt))

                ForEach(prayers) { p in card(p) }

                if store.hasCustomPrayerPrefs {
                    Button {
                        for p in prayers { store.setPrayerPrefs(AtharStore.PrayerAlertPrefs(), for: p) }
                        Task { await Reminders.rescheduleAthan(store: store) }
                        Haptics.done(enabled: store.hapticsEnabled)
                    } label: {
                        Text(loc("إعادة الكل إلى الإعداد العام")).font(Theme.display(14, weight: .semibold)).frame(maxWidth: .infinity).softButton(Theme.danger)
                    }
                    .pressable()
                }
            }
            .padding(.horizontal, Theme.gutter).padding(.top, 8).padding(.bottom, 32).readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground() }
        .navigationTitle(loc("تخصيص كل صلاة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func card(_ p: Prayer) -> some View {
        let prefs = store.prayerPrefs(p)
        let color = Theme.accent(for: p.accentKey)
        return SettingsCard {
            SettingsRow(icon: p.icon, tint: color, title: p.title, subtitle: prefs.enabled ? nil : loc("لا تنبيه لهذه الصلاة")) {
                Toggle("", isOn: Binding(get: { prefs.enabled }, set: { v in var n = prefs; n.enabled = v; save(n, p) }))
                    .labelsHidden().accessibilityLabel(loc("تنبيه %1$@", p.title))
            }
            if prefs.enabled {
                SettingsDivider()
                HStack(spacing: 8) {
                    Text(loc("الصوت")).font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Picker("", selection: Binding(get: { prefs.soundMode }, set: { m in var n = prefs; n.sound = m.rawValue; save(n, p) })) {
                        ForEach(AtharStore.PrayerSoundMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 260)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                SettingsDivider()
                HStack(spacing: 8) {
                    Text(loc("تنبيه قبلي")).font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
                    Spacer()
                    Picker("", selection: Binding(get: { prefs.preMinutes ?? -1 }, set: { v in var n = prefs; n.preMinutes = v < 0 ? nil : v; save(n, p) })) {
                        Text(loc("اتّبع العام")).tag(-1)
                        ForEach(preChoices, id: \.self) { m in Text(m == 0 ? loc("بدون") : loc("قبل %1$@ د", m.counterText)).tag(m) }
                    }
                    .pickerStyle(.menu).tint(color)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
            }
        }
    }

    private func save(_ prefs: AtharStore.PrayerAlertPrefs, _ p: Prayer) {
        store.setPrayerPrefs(prefs, for: p)
        Haptics.tap(enabled: store.hapticsEnabled)
        Task { await Reminders.rescheduleAthan(store: store) }
    }
}
