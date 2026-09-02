import SwiftUI

/// الورد اليومي: مقدار ثابت من الآيات كل يوم، مع تتبّع وتذكير.
struct WirdView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var showTargetPicker = false

    private var progress: Double {
        min(1, Double(store.wirdDoneToday) / Double(max(1, store.wirdTarget)))
    }
    private var done: Bool { store.wirdDoneToday >= store.wirdTarget }

    /// هوية الشاشة: فجريّ كهرماني.
    private var dawn: Color { Theme.accent(for: "dawn") }

    private var reminderBinding: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: store.wirdReminderMinutes / 60,
                                         minute: store.wirdReminderMinutes % 60,
                                         second: 0, of: Date()) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                store.wirdReminderMinutes = (c.hour ?? 20) * 60 + (c.minute ?? 0)
                Task { await Reminders.rescheduleWird(store: store) }
            }
        )
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: dawn, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 22) {
                    ring.appearStagger(0)
                    actions.appearStagger(1)
                    settings.appearStagger(2)
                    note.appearStagger(3)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("الورد اليومي"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var ring: some View {
        // القوس فجريّ كهرماني أثناء الورد، ويتحوّل إلى لون الإنجاز عند الإتمام
        // مع توهّج يشتدّ قرب الاكتمال، وعلامات خافتة بعدد آيات اليوم كوجه الساعة.
        let ringColor = done ? Theme.accent : dawn
        return ZStack {
            if done { CelebrationHalo(tint: dawn) }
            ProgressRing(progress: progress, color: ringColor, lineWidth: 13,
                         gradient: true, ticks: store.wirdTarget, glow: true)
            VStack(spacing: 4) {
                Text(store.wirdDoneToday.counterText)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [ringColor, ringColor.opacity(0.7)],
                                                    startPoint: .top, endPoint: .bottom))
                    .contentTransition(.numericText())
                Text(loc("من %1$@ آية", store.wirdTarget.counterText))
                    .font(Theme.display(13)).foregroundStyle(Theme.inkFaint)
                if done {
                    Text(loc("تمّ وردك اليوم"))
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(dawn)
                        .padding(.top, 2)
                }
            }
        }
        .frame(width: 210, height: 210)
        .padding(.top, 8)
        .animation(Motion.smooth, value: done)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                store.advanceWird(by: 1)
                Haptics.step(enabled: store.hapticsEnabled)
            } label: {
                Label(loc("قرأت آية"), systemImage: "plus")
                    .font(Theme.display(15, weight: .semibold))
                    .gradientButton(Theme.gradient(for: "dawn"), glow: dawn)
            }
            .pressable()

            Button {
                store.wirdDoneToday = 0
                Haptics.tap(enabled: store.hapticsEnabled)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 52).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).stroke(Theme.hairline))
            }
            .pressable()
        }
    }

    private var settings: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الإعداد"), tint: dawn)
            SettingsCard {
                SettingsRow(icon: "target", tint: dawn, title: loc("ورد اليوم")) {
                    HStack(spacing: 7) {
                        ForEach([5, 10, 20, 50], id: \.self) { n in
                            let on = store.wirdTarget == n
                            Button {
                                store.wirdTarget = n
                                Haptics.tap(enabled: store.hapticsEnabled)
                            } label: {
                                Text(n.counterText)
                                    .font(.system(size: 14, weight: on ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
                                    .frame(width: 36, height: 32)
                                    .background(
                                        RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                            .fill(on ? AnyShapeStyle(Theme.gradient(for: "dawn"))
                                                     : AnyShapeStyle(Theme.surfaceAlt))
                                    )
                                    .shadow(color: on ? dawn.opacity(0.35) : .clear,
                                            radius: on ? 6 : 0, y: on ? 3 : 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .animation(Motion.press, value: store.wirdTarget)
                }

                SettingsDivider()
                SettingsRow(icon: "bell.fill", tint: Theme.gold, title: loc("تذكير الورد")) {
                    Toggle("", isOn: Binding(
                        get: { store.wirdEnabled },
                        set: { on in
                            store.wirdEnabled = on
                            Task {
                                if on, await !Reminders.requestAuthorization() {
                                    store.wirdEnabled = false; return
                                }
                                await Reminders.rescheduleWird(store: store)
                            }
                        }
                    )).labelsHidden()
                }

                if store.wirdEnabled {
                    SettingsDivider()
                    SettingsRow(icon: "clock.fill", tint: Theme.accent(for: "dusk"), title: loc("وقت التذكير")) {
                        DatePicker("", selection: reminderBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
        .animation(Motion.smooth, value: store.wirdEnabled)
    }

    private var note: some View {
        // النص الشرعي بخطّ النسخ ولون الحبر (لا صبغة)، والشرح تحته بخطّ الواجهة الخافت.
        VStack(spacing: 6) {
            Text("«أحبُّ الأعمال إلى الله أدومها وإن قلّ»")
                .font(Theme.naskhFont(size: 14, scale: store.fontScale))
                .foregroundStyle(Theme.inkSoft)
            Text(loc("القليل الدائم خير من الكثير المنقطع."))
                .font(Theme.display(11.5))
                .foregroundStyle(Theme.inkFaint)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
