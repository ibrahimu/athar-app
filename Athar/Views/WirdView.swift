import SwiftUI

/// الورد اليومي: مقدار ثابت من الآيات كل يوم، مع تتبّع وتذكير.
struct WirdView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var showTargetPicker = false

    private var progress: Double {
        min(1, Double(store.wirdDoneToday) / Double(max(1, store.wirdTarget)))
    }
    private var done: Bool { store.wirdDoneToday >= store.wirdTarget }

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
            AtharBackground()
            ScrollView {
                VStack(spacing: 22) {
                    ring
                    actions
                    settings
                    note
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("الورد اليومي")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var ring: some View {
        ZStack {
            ProgressRing(progress: progress, color: done ? Theme.accent : Theme.gold, lineWidth: 13)
            VStack(spacing: 4) {
                Text(store.wirdDoneToday.counterText)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("من \(store.wirdTarget.counterText) آية")
                    .font(Theme.display(13)).foregroundStyle(Theme.inkFaint)
                if done {
                    Text("تمّ وردك اليوم")
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 2)
                }
            }
        }
        .frame(width: 210, height: 210)
        .padding(.top, 8)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                store.advanceWird(by: 1)
                Haptics.step(enabled: store.hapticsEnabled)
            } label: {
                Label("قرأت آية", systemImage: "plus")
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accent))
            }
            .buttonStyle(.plain)

            Button {
                store.wirdDoneToday = 0
                Haptics.tap(enabled: store.hapticsEnabled)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 52).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline))
            }
            .buttonStyle(.plain)
        }
    }

    private var settings: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "الإعداد")
            SettingsCard {
                SettingsRow(icon: "target", tint: Theme.accent(for: "sea"), title: "ورد اليوم") {
                    HStack(spacing: 8) {
                        ForEach([5, 10, 20, 50], id: \.self) { n in
                            Button {
                                store.wirdTarget = n
                                Haptics.tap(enabled: store.hapticsEnabled)
                            } label: {
                                Text(n.counterText)
                                    .font(Theme.display(13, weight: store.wirdTarget == n ? .bold : .regular))
                                    .foregroundStyle(store.wirdTarget == n ? .white : Theme.inkSoft)
                                    .frame(width: 34, height: 30)
                                    .background(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(store.wirdTarget == n ? Theme.accent : Theme.surfaceAlt)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SettingsDivider()
                SettingsRow(icon: "bell.fill", tint: Theme.gold, title: "تذكير الورد") {
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
                    SettingsRow(icon: "clock.fill", tint: Theme.accent(for: "dusk"), title: "وقت التذكير") {
                        DatePicker("", selection: reminderBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.25), value: store.wirdEnabled)
    }

    private var note: some View {
        Text("«أحبُّ الأعمال إلى الله أدومها وإن قلّ»\nالقليل الدائم خير من الكثير المنقطع.")
            .font(Theme.display(12))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
