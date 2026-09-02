import SwiftUI
import WidgetKit

struct SettingsView: View {
    /// حين تُعرض داخل مكدّس تنقّل قائم، لا نغلّفها بمكدّس آخر.
    var embedded = false

    @EnvironmentObject private var store: AtharStore
    @State private var showResetConfirm = false
    @State private var permissionDenied = false

    private var morningBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: store.morningReminderMinutes) },
            set: { store.morningReminderMinutes = Self.minutes(from: $0); scheduleReminders() }
        )
    }

    private var eveningBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: store.eveningReminderMinutes) },
            set: { store.eveningReminderMinutes = Self.minutes(from: $0); scheduleReminders() }
        )
    }

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
        Group {
            ZStack {
                AtharBackground()
                ScrollView {
                    VStack(spacing: 26) {
                        reminders
                        prayer
                        display
                        stats
                        about
                        blessing
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 34)
                    .readableWidth(560)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("الإعدادات")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("هل تريد تصفير كل الإحصائيات؟", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("تصفير", role: .destructive) {
                    store.resetAllProgress()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                Button("إلغاء", role: .cancel) {}
            }
            .alert("الإشعارات موقوفة", isPresented: $permissionDenied) {
                Button("فتح الإعدادات") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("لاحقًا", role: .cancel) {}
            } message: {
                Text("لتفعيل التذكير، اسمح للتطبيق بالإشعارات من إعدادات الجهاز.")
            }
        }
    }

    // MARK: التذكير

    private var reminders: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "التذكير")
            SettingsCard {
                SettingsRow(icon: "bell.badge.fill", tint: Theme.gold,
                            title: "تذكير الأذكار",
                            subtitle: store.remindersEnabled ? nil : "تنبيه لطيف للصباح والمساء") {
                    Toggle("", isOn: Binding(
                        get: { store.remindersEnabled },
                        set: { enabled in
                            store.remindersEnabled = enabled
                            Task {
                                if enabled, await !Reminders.requestAuthorization() {
                                    store.remindersEnabled = false
                                    permissionDenied = true
                                    return
                                }
                                await Reminders.reschedule(store: store)
                            }
                        }
                    ))
                    .labelsHidden()
                }

                if store.remindersEnabled {
                    SettingsDivider()
                    SettingsRow(icon: "sunrise.fill", tint: Theme.accent(for: "dawn"), title: "أذكار الصباح") {
                        DatePicker("", selection: morningBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    SettingsDivider()
                    SettingsRow(icon: "moon.stars.fill", tint: Theme.accent(for: "dusk"), title: "أذكار المساء") {
                        DatePicker("", selection: eveningBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
        .animation(.smooth(duration: 0.28), value: store.remindersEnabled)
    }

    // MARK: الصلاة

    private var prayer: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "الصلاة")
            SettingsCard {
                SettingsRow(icon: "bell.and.waves.left.and.right.fill", tint: Theme.accent,
                            title: "تنبيه دخول الوقت",
                            subtitle: "إشعار عند أذان كل صلاة") {
                    Toggle("", isOn: Binding(
                        get: { store.athanAlerts },
                        set: { enabled in
                            store.athanAlerts = enabled
                            Task {
                                if enabled, await !Reminders.requestAuthorization() {
                                    store.athanAlerts = false
                                    permissionDenied = true
                                    return
                                }
                                await Reminders.rescheduleAthan(store: store)
                            }
                        }
                    ))
                    .labelsHidden()
                }

                SettingsDivider()
                SettingsPickerRow(
                    icon: "slider.horizontal.3", tint: Theme.accent(for: "sea"),
                    title: "طريقة الحساب", options: CalculationMethod.allCases,
                    selection: Binding(
                        get: { store.calculationMethod },
                        set: { store.calculationMethod = $0; refreshPrayers() }))

                SettingsDivider()
                SettingsPickerRow(
                    icon: "sun.haze.fill", tint: Theme.accent(for: "dawn"),
                    title: "وقت العصر", options: AsrMethod.allCases,
                    selection: Binding(
                        get: { store.asrMethod },
                        set: { store.asrMethod = $0; refreshPrayers() }))

                SettingsDivider()
                SettingsRow(icon: "location.fill", tint: Theme.accent(for: "calm"), title: "الموقع") {
                    SettingsValue(text: store.placeName)
                }
            }
        }
    }

    // MARK: العرض

    private var display: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "العرض")
            SettingsCard {
                NavigationLink { AppearanceView() } label: {
                    SettingsRow(icon: "paintpalette.fill", tint: Theme.accent(for: "calm"),
                                title: "المظهر",
                                subtitle: "\(store.appTheme.title) · \(store.appearance.title)") {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)

                SettingsDivider()
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 13) {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.accent(for: "sea"))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Theme.accent(for: "sea").opacity(0.12)))
                        Text("حجم الخط")
                            .font(Theme.display(16))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        SettingsValue(text: String(format: "%.0f٪", store.fontScale * 100))
                    }

                    HStack(spacing: 10) {
                        Text("أ").font(.system(size: 13)).foregroundStyle(Theme.inkFaint)
                        Slider(
                            value: Binding(get: { store.fontScale }, set: { store.fontScale = $0 }),
                            in: 0.85...1.6, step: 0.05
                        )
                        .tint(Theme.accent)
                        Text("أ").font(.system(size: 21)).foregroundStyle(Theme.inkFaint)
                    }

                    Text("سُبْحَانَ اللهِ وَبِحَمْدِهِ")
                        .font(Theme.dhikrFont(size: 19, scale: store.fontScale))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Theme.surfaceAlt)
                        )
                        .animation(.smooth(duration: 0.2), value: store.fontScale)
                }
                .padding(14)

                SettingsDivider()
                SettingsPickerRow(
                    icon: "hand.point.up.left.fill", tint: Theme.accent(for: "calm"),
                    title: "منطقة العدّ", options: CountTapArea.allCases,
                    selection: Binding(
                        get: { store.countTapArea },
                        set: { store.countTapArea = $0 }))

                SettingsDivider()
                SettingsRow(icon: "hand.tap.fill", tint: Theme.gold, title: "الاهتزاز عند العدّ") {
                    Toggle("", isOn: Binding(
                        get: { store.hapticsEnabled },
                        set: { store.hapticsEnabled = $0 }
                    ))
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: إحصائياتي

    private var stats: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "أثري")
            SettingsCard {
                HStack(spacing: 0) {
                    statPill("flame.fill", Theme.gold, store.displayStreak.counterText, "يوم متتابع")
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 44)
                    statPill("trophy.fill", Theme.accent(for: "dawn"), store.bestStreak.counterText, "أطول تتابع")
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 44)
                    statPill("infinity", Theme.accent, store.totalDhikrCount.counterText, "مجموع الأذكار")
                }
                .padding(.vertical, 16)

                SettingsDivider()
                Button { showResetConfirm = true } label: {
                    SettingsRow(icon: "arrow.counterclockwise", tint: Color.red.opacity(0.85),
                                title: "تصفير الإحصائيات") {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statPill(_ icon: String, _ tint: Color, _ value: String, _ label: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(tint)
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: عن التطبيق

    private var about: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "عن التطبيق")
            SettingsCard {
                SettingsRow(icon: "info.circle.fill", tint: Theme.inkSoft, title: "الإصدار") {
                    SettingsValue(text: appVersion)
                }
                SettingsDivider()
                linkRow("hand.raised.fill", Theme.accent(for: "calm"), "سياسة الخصوصية",
                        "https://ibrahimu.github.io/athar-app/privacy.html")
                SettingsDivider()
                linkRow("lifepreserver.fill", Theme.accent(for: "sea"), "الدعم والتواصل",
                        "https://ibrahimu.github.io/athar-app/support.html")
                SettingsDivider()
                ShareLink(item: Self.appStoreURL,
                          message: Text("تطبيق أثر — أذكار وأوقات الصلاة ومسبحة. مجاني بلا إعلانات، ويعمل بدون إنترنت.")) {
                    SettingsRow(icon: "square.and.arrow.up.fill", tint: Theme.accent,
                                title: "انشر التطبيق", subtitle: "دلَّ على خيرٍ فله مثل أجر فاعله") {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func linkRow(_ icon: String, _ tint: Color, _ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            SettingsRow(icon: icon, tint: tint, title: title) {
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: الخاتمة

    private var blessing: some View {
        VStack(spacing: 10) {
            Image(systemName: "drop.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.gold.opacity(0.7))
            Text("﴿ وَمَا تُقَدِّمُوا لِأَنفُسِكُم مِّنْ خَيْرٍ تَجِدُوهُ عِندَ اللَّهِ ﴾")
                .font(Theme.dhikrFont(size: 15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Text("صدقة جارية عن كل من ساهم فيه أو دلَّ عليه")
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: Helpers

    private func scheduleReminders() {
        Task { await Reminders.reschedule(store: store) }
    }

    private func refreshPrayers() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { await Reminders.rescheduleAthan(store: store) }
    }

    /// App Store page for أثر (Apple ID 6806411693).
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6806411693")!

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}
