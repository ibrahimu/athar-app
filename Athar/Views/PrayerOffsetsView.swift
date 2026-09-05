import SwiftUI
import WidgetKit

/// ضبط المواقيت يدويًّا: دقائق تُزاد أو تُنقص لكل فريضة حتى تطابق تقويم مسجد الحيّ.
/// يُطبَّق في المخزن مرة واحدة فتراه كل الشاشات والودجات والتنبيهات.
struct PrayerOffsetsView: View {
    @EnvironmentObject private var store: AtharStore
    private let prayers: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.system(size: 12)).foregroundStyle(Theme.inkFaint).padding(.top, 1)
                    Text(loc("الحساب الفلكي قد يختلف دقائق عن تقويم مسجدك. اضبط كل صلاة بالدقائق، والوقت المعروض هو النتيجة بعد التعديل."))
                        .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.surfaceAlt))

                SettingsCard {
                    ForEach(Array(prayers.enumerated()), id: \.element) { i, p in
                        row(p)
                        if i < prayers.count - 1 { SettingsDivider() }
                    }
                }

                if store.hasPrayerOffsets {
                    Button {
                        withAnimation(Motion.snappy) { store.resetPrayerOffsets() }
                        Haptics.done(enabled: store.hapticsEnabled)
                        Task { await Reminders.rescheduleAll(store: store) }
                    } label: {
                        Text(loc("إعادة الضبط إلى الحساب الفلكي"))
                            .font(Theme.display(14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .softButton(Theme.danger)
                    }
                    .pressable()
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground() }
        .navigationTitle(loc("ضبط المواقيت"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func row(_ p: Prayer) -> some View {
        let offset = store.prayerOffset(p)
        let color = Theme.accent(for: p.accentKey)
        return HStack(spacing: 13) {
            IconChip(icon: p.icon, tint: color, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.title).font(Theme.display(16)).foregroundStyle(Theme.ink)
                Text(store.prayerTimes()?[p].map(clock) ?? "—")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkFaint).monospacedDigit()
            }
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                step("minus", enabled: offset > -30) { change(p, -1) }
                    .accessibilityLabel(loc("تأخير %1$@ دقيقة", p.title))
                Text(offsetText(offset))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(offset == 0 ? Theme.inkFaint : Theme.ink)
                    .monospacedDigit()
                    .frame(minWidth: 48)
                    .contentTransition(.numericText())
                    .animation(Motion.snappy, value: offset)
                step("plus", enabled: offset < 30) { change(p, 1) }
                    .accessibilityLabel(loc("تقديم %1$@ دقيقة", p.title))
            }
            .background(Capsule().fill(Theme.surfaceAlt))
            .overlay(Capsule().strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
            .accessibilityElement(children: .contain)
            .accessibilityValue(offsetText(offset))
        }
        .padding(.horizontal, 16).padding(.vertical, 9)
    }

    private func step(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? Theme.accent : Theme.inkFaint)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func change(_ p: Prayer, _ delta: Int) {
        store.setPrayerOffset(store.prayerOffset(p) + delta, for: p)
        Haptics.tap(enabled: store.hapticsEnabled)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await Reminders.rescheduleAll(store: store) }
        WatchSync.shared.push(store: store)
    }

    private func offsetText(_ m: Int) -> String {
        m == 0 ? "٠" : (m > 0 ? "+\(m.counterText)" : "−\(abs(m).counterText)")
    }

    private func clock(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = store.placeTimeZone
        f.dateFormat = "h:mm a"
        return f.string(from: d)
    }
}
