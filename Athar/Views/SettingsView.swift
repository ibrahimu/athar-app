import SwiftUI
import WidgetKit

struct SettingsView: View {
    /// حين تُعرض داخل مكدّس تنقّل قائم، لا نغلّفها بمكدّس آخر.
    var embedded = false

    @EnvironmentObject private var store: AtharStore
    @State private var showResetConfirm = false
    @State private var permissionDenied = false
    @State private var scheduledAlerts = 0
    @State private var testSent = false

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
                    VStack(spacing: 30) {
                        languageRow
                        reminders
                        sunanReminders
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
            .navigationTitle(loc("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .task { scheduledAlerts = await Reminders.scheduledAthanCount() }
            .confirmationDialog("هل تريد تصفير كل الإحصائيات؟", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("تصفير", role: .destructive) {
                    store.resetAllProgress()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                Button(loc("cancel"), role: .cancel) {}
            }
            .alert("الإشعارات موقوفة", isPresented: $permissionDenied) {
                Button("فتح الإعدادات") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(loc("later"), role: .cancel) {}
            } message: {
                Text("لتفعيل التذكير، اسمح للتطبيق بالإشعارات من إعدادات الجهاز.")
            }
        }
    }

    // MARK: التذكير

    private var reminders: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpReminders"))
            SettingsCard {
                SettingsRow(icon: "bell.badge.fill", tint: Theme.gold,
                            title: loc("rowAdhkarRem"),
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
                    SettingsRow(icon: "sunrise.fill", tint: Theme.accent(for: "dawn"), title: loc("rowMorning")) {
                        DatePicker("", selection: morningBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    SettingsDivider()
                    SettingsRow(icon: "moon.stars.fill", tint: Theme.accent(for: "dusk"), title: loc("rowEvening")) {
                        DatePicker("", selection: eveningBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
        .animation(Motion.smooth, value: store.remindersEnabled)
    }

    // MARK: اللغة

    private var languageRow: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("language"))
            SettingsCard {
                SettingsPickerRow(
                    icon: "globe", tint: Theme.accent(for: "sea"),
                    title: loc("language"), options: AppLanguage.allCases,
                    selection: Binding(get: { store.appLanguage },
                                       set: { store.appLanguage = $0 }))
            }
        }
    }

    // MARK: تنويع التذكيرات

    private func alertToggle(_ get: @escaping () -> Bool, _ set: @escaping (Bool) -> Void) -> Binding<Bool> {
        Binding(get: get, set: { on in
            set(on)
            Task {
                if on, await !Reminders.requestAuthorization() {
                    set(false); permissionDenied = true; return
                }
                await Reminders.rescheduleAll(store: store)
            }
        })
    }

    private var sunanReminders: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpSunan"))
            SettingsCard {
                SettingsRow(icon: "sparkles", tint: Theme.gold, title: loc("rowJumuah"),
                            subtitle: loc("subJumuah")) {
                    Toggle("", isOn: alertToggle({ store.jumuahAlert }, { store.jumuahAlert = $0 })).labelsHidden()
                }
                SettingsDivider()
                SettingsRow(icon: "fork.knife", tint: Theme.accent(for: "sea"), title: loc("rowFasting"),
                            subtitle: loc("subFasting")) {
                    Toggle("", isOn: alertToggle({ store.fastingAlert }, { store.fastingAlert = $0 })).labelsHidden()
                }
                SettingsDivider()
                SettingsRow(icon: "moon.circle.fill", tint: Theme.accent(for: "dusk"), title: loc("rowWhite"),
                            subtitle: loc("subWhite")) {
                    Toggle("", isOn: alertToggle({ store.whiteDaysAlert }, { store.whiteDaysAlert = $0 })).labelsHidden()
                }
                SettingsDivider()
                SettingsRow(icon: "moon.stars.fill", tint: Theme.accent(for: "night"), title: loc("rowQiyam"),
                            subtitle: loc("subQiyam")) {
                    Toggle("", isOn: alertToggle({ store.qiyamAlert }, { store.qiyamAlert = $0 })).labelsHidden()
                }
                SettingsDivider()
                SettingsRow(icon: "drop.fill", tint: Theme.accent(for: "sea"), title: loc("rowIstighfar"),
                            subtitle: loc("subIstighfar")) {
                    Toggle("", isOn: alertToggle({ store.istighfarAlerts }, { store.istighfarAlerts = $0 })).labelsHidden()
                }
            }
        }
    }

    // MARK: الصلاة

    private var prayer: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpPrayer"))
            SettingsCard {
                SettingsRow(icon: "bell.and.waves.left.and.right.fill", tint: Theme.accent,
                            title: loc("rowAthan"),
                            subtitle: loc("subAthan")) {
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

                if store.athanAlerts {
                    SettingsDivider()
                    Button {
                        Task {
                            testSent = await Reminders.sendTestAlert()
                            if !testSent { permissionDenied = true }
                        }
                    } label: {
                        SettingsRow(icon: testSent ? "checkmark.circle.fill" : "bell.badge.waveform.fill",
                                    tint: testSent ? Theme.accent : Theme.gold,
                                    title: testSent ? "أُرسل — سيصلك خلال ٥ ثوانٍ" : "جرّب التنبيه الآن",
                                    subtitle: scheduledAlerts > 0
                                        ? "\(scheduledAlerts.counterText) تنبيهًا مجدولًا للأيام القادمة"
                                        : "اضغط لتتأكد أن الإشعارات تعمل") {
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                    .pressable()
                }

                SettingsDivider()
                SettingsPickerRow(
                    icon: "slider.horizontal.3", tint: Theme.accent(for: "sea"),
                    title: loc("rowCalc"), options: CalculationMethod.allCases,
                    selection: Binding(
                        get: { store.calculationMethod },
                        set: { store.calculationMethod = $0; refreshPrayers() }))

                SettingsDivider()
                SettingsPickerRow(
                    icon: "sun.haze.fill", tint: Theme.accent(for: "dawn"),
                    title: loc("rowAsr"), options: AsrMethod.allCases,
                    selection: Binding(
                        get: { store.asrMethod },
                        set: { store.asrMethod = $0; refreshPrayers() }))

                SettingsDivider()
                SettingsRow(icon: "location.fill", tint: Theme.accent(for: "calm"), title: loc("rowLocation")) {
                    SettingsValue(text: store.placeName)
                }
            }
        }
    }

    // MARK: العرض

    private var display: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpDisplay"))
            SettingsCard {
                NavigationLink { AppearanceView() } label: {
                    SettingsRow(icon: "paintpalette.fill", tint: Theme.accent(for: "calm"),
                                title: loc("rowAppearance"),
                                subtitle: "\(store.appTheme.title) · \(store.appearance.title)") {
                        Image(systemName: "chevron.forward")
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
                        Text(loc("rowFont"))
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
                        .animation(Motion.snappy, value: store.fontScale)
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
                SettingsRow(icon: "hand.tap.fill", tint: Theme.gold, title: loc("rowHaptics")) {
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
            SettingsGroupTitle(text: loc("grpStats"))
            SettingsCard {
                HStack(spacing: 0) {
                    statPill("flame.fill", Theme.gold, store.displayStreak.counterText, loc("statStreak"))
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 44)
                    statPill("trophy.fill", Theme.accent(for: "dawn"), store.bestStreak.counterText, loc("statBest"))
                    Rectangle().fill(Theme.hairline).frame(width: 1, height: 44)
                    statPill("infinity", Theme.accent, store.totalDhikrCount.counterText, loc("statTotal"))
                }
                .padding(.vertical, 16)

                SettingsDivider()
                Button { showResetConfirm = true } label: {
                    SettingsRow(icon: "arrow.counterclockwise", tint: Color.red.opacity(0.85),
                                title: loc("rowReset")) {
                        Image(systemName: "chevron.forward")
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
            SettingsGroupTitle(text: loc("grpAbout"))
            SettingsCard {
                SettingsRow(icon: "info.circle.fill", tint: Theme.inkSoft, title: loc("rowVersion")) {
                    SettingsValue(text: appVersion)
                }
                SettingsDivider()
                linkRow("hand.raised.fill", Theme.accent(for: "calm"), loc("rowPrivacy"),
                        "https://ibrahimu.github.io/athar-app/privacy.html")
                SettingsDivider()
                linkRow("lifepreserver.fill", Theme.accent(for: "sea"), loc("rowSupport"),
                        "https://ibrahimu.github.io/athar-app/support.html")
                SettingsDivider()
                NavigationLink { SourcesView() } label: {
                    SettingsRow(icon: "text.book.closed.fill", tint: Theme.accent(for: "sea"),
                                title: loc("rowSources"),
                                subtitle: "نصوص المصحف والأذكار والخطوط") {
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)

                SettingsDivider()
                Link(destination: URL(string: "https://ehsan.sa")!) {
                    SettingsRow(icon: "heart.fill", tint: Theme.gold,
                                title: loc("rowSadaqah"),
                                subtitle: "المنصة الوطنية للعمل الخيري") {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)

                SettingsDivider()
                ShareLink(item: Self.appStoreURL,
                          message: Text("تطبيق أثر — أذكار وأوقات الصلاة ومسبحة. مجاني بلا إعلانات، ويعمل بدون إنترنت.")) {
                    SettingsRow(icon: "square.and.arrow.up.fill", tint: Theme.accent,
                                title: loc("rowShare"), subtitle: "دلَّ على خيرٍ فله مثل أجر فاعله") {
                        Image(systemName: "chevron.forward")
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
