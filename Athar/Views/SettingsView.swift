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
    @StateObject private var preview = AthanPreview.shared
    /// ختم آخر ضغطة على «جرّب التنبيه الآن»: لا يُطفئ التأكيدَ إلا مؤقّتُ
    /// أحدث ضغطة، وإلا محا مؤقّتُ الضغطة الأولى تأكيدَ الضغطة التي تلتها.
    @State private var testToken = 0
    @State private var showCityPicker = false

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
                AtharBackground(tint: Theme.accent, secondary: Theme.gold)
                settingsAura
                ScrollView {
                    VStack(spacing: 30) {
                        if !AppConfig.arabicOnly { languageRow.appearStagger(0) }
                        reminders.appearStagger(1)
                        sunanReminders.appearStagger(2)
                        prayer.appearStagger(3)
                        display.appearStagger(4)
                        sources.appearStagger(5)
                        stats.appearStagger(6)
                        about.appearStagger(7)
                        blessing.appearStagger(8)
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
            .confirmationDialog(loc("هل تريد تصفير كل الإحصائيات؟"), isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button(loc("تصفير"), role: .destructive) {
                    store.resetAllProgress()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                Button(loc("cancel"), role: .cancel) {}
            }
            .alert(loc("الإشعارات موقوفة"), isPresented: $permissionDenied) {
                Button(loc("فتح الإعدادات")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(loc("later"), role: .cancel) {}
            } message: {
                Text(loc("لتفعيل التذكير، اسمح للتطبيق بالإشعارات من إعدادات الجهاز."))
            }
        }
    }

    /// طبقات ضوئية ناعمة فوق الخلفية: توهّج لوني علوي، بركة ذهبية سفلية،
    /// وشريط نقش باهت جدًا خلف البطاقات — عمق بلا ضجيج ولا منافسة للنص.
    private var settingsAura: some View {
        ZStack {
            RadialGradient(colors: [Theme.accent.opacity(0.10), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 380)
            RadialGradient(colors: [Theme.gold.opacity(0.06), .clear],
                           center: UnitPoint(x: 0.16, y: 0.62), startRadius: 0, endRadius: 320)
            PaperMotif(tint: Theme.accent)
                .frame(height: 260)
                .mask(LinearGradient(colors: [.clear, .black, .clear],
                                     startPoint: .top, endPoint: .bottom))
                .opacity(0.6)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    // MARK: التذكير

    private var reminders: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpReminders"), tint: Theme.accent(for: "gold"))
            SettingsCard {
                SettingsRow(icon: "bell.badge.fill", tint: Theme.accent(for: "gold"),
                            title: loc("rowAdhkarRem"),
                            subtitle: store.remindersEnabled ? nil : loc("تنبيه لطيف للصباح والمساء")) {
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
            SettingsGroupTitle(text: loc("grpSunan"), tint: Theme.accent(for: "dusk"))
            SettingsCard {
                SettingsRow(icon: "sparkles", tint: Theme.accent(for: "gold"), title: loc("rowJumuah"),
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
            SettingsGroupTitle(text: loc("grpPrayer"), tint: Theme.accent(for: "green"))
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
                    SettingsPickerRow(icon: "speaker.wave.2.fill", tint: Theme.accent(for: "dusk"),
                                            title: loc("صوت الأذان"), options: AthanSound.allCases,
                                            selection: Binding(get: { store.athanSound },
                                                               set: { store.athanSound = $0; refreshPrayers() }))
                    if store.athanSound != .system {
                        SettingsDivider()
                        Button { preview.toggle(store.athanSound) } label: {
                            SettingsRow(icon: preview.playing == store.athanSound ? "stop.circle.fill" : "play.circle.fill",
                                              tint: Theme.accent(for: "dusk"),
                                              title: preview.playing == store.athanSound ? loc("إيقاف الاستماع") : loc("استمع للأذان كاملًا"),
                                              subtitle: loc("التنبيه يصلك بأوّل ثلاثين ثانية منه")) { EmptyView() }
                        }
                        .buttonStyle(.plain)
                    }
                    SettingsDivider()
                    Button {
                        Task {
                            // التأكيد مؤقّت: يعود الصف بعد ثوانٍ إلى «جرّب التنبيه الآن»
                            // حتى تُنتج كل ضغطة تغيّرًا مرئيًا، ولا يبقى وعدٌ بتنبيهٍ وصل.
                            guard await Reminders.sendTestAlert(store: store) else {
                                permissionDenied = true
                                return
                            }
                            testToken &+= 1
                            let token = testToken
                            withAnimation(Motion.snappy) { testSent = true }
                            try? await Task.sleep(for: .seconds(8))
                            if testToken == token {
                                withAnimation(Motion.snappy) { testSent = false }
                            }
                        }
                    } label: {
                        SettingsRow(icon: testSent ? "checkmark.circle.fill" : "bell.badge.waveform.fill",
                                    tint: testSent ? Theme.accent : Theme.gold,
                                    title: testSent ? loc("أُرسل — سيصلك خلال ٥ ثوانٍ") : loc("جرّب التنبيه الآن"),
                                    subtitle: scheduledAlerts > 0
                                        ? "\(scheduledAlerts.counterText) تنبيهًا مجدولًا للأيام القادمة"
                                        : loc("اضغط لتتأكد أن الإشعارات تعمل")) {
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
                Button { showCityPicker = true } label: {
                    SettingsRow(icon: "location.fill", tint: Theme.accent(for: "calm"), title: loc("rowLocation")) {
                        HStack(spacing: 6) {
                            SettingsValue(text: store.placeName)
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            // تغيّر الموقع يعني مواقيت وأسماء مدنٍ جديدة، فنعيد جدولة الأذان
            // بعد إغلاق الورقة تمامًا كما تفعل صفوف طريقة الحساب والعصر،
            // وإلا بقيت تنبيهات المدينة السابقة تعمل سبعة أيام.
            .sheet(isPresented: $showCityPicker, onDismiss: { refreshPrayers() }) {
                // الأوراق لا ترث اتجاه الكتابة من جذر التطبيق، فنثبّته صراحةً.
                LocationPickerHost(store: store)
                    .environment(\.layoutDirection,
                                 AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
            }
        }
    }

    // MARK: العرض

    private var display: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpDisplay"), tint: Theme.accent(for: "calm"))
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
                        IconChip(icon: "textformat.size", tint: Theme.accent(for: "sea"))
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

                    Text(loc("سُبْحَانَ اللهِ وَبِحَمْدِهِ"))
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
                    title: loc("منطقة العدّ"), options: CountTapArea.allCases,
                    selection: Binding(
                        get: { store.countTapArea },
                        set: { store.countTapArea = $0 }))

                SettingsDivider()
                SettingsRow(icon: "hand.tap.fill", tint: Theme.accent(for: "gold"), title: loc("rowHaptics")) {
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
            SettingsGroupTitle(text: loc("grpStats"), tint: Theme.accent(for: "dawn"))
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
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint)
                .background(
                    Circle().fill(tint.opacity(0.22)).frame(width: 26, height: 26).blur(radius: 7)
                )
            Text(value)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                                startPoint: .top, endPoint: .bottom))
                .contentTransition(.numericText())
            Text(label)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: المصادر والتوثيق

    /// بطاقة توثيق بارزة تطمئن المستخدم أنّ كل نصٍّ في التطبيق من مصدر معلوم،
    /// مع ثلاث رقاقات موجزة، وكامل التفصيل بلمسة على SourcesView.
    private var sources: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("المصادر والتوثيق"), tint: Theme.accent(for: "green"))
            NavigationLink { SourcesView() } label: {
                SettingsCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 13) {
                            IconChip(icon: "checkmark.seal.fill", tint: Theme.accent(for: "green"))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc("نصوصٌ موثّقة ومراجَعة"))
                                    .font(Theme.display(16, weight: .medium))
                                    .foregroundStyle(Theme.ink)
                                Text(loc("اطّلع على مصدر كل ما في التطبيق"))
                                    .font(Theme.display(12))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        HStack(spacing: 8) {
                            sourceChip("book.closed.fill", loc("المصحف"), loc("مصحف تنزيل"))
                            sourceChip("moon.stars.fill", loc("الأذكار"), loc("الكتاب والسنّة"))
                            sourceChip("location.north.line.fill", loc("المواقيت"), loc("حساب فلكي"))
                        }
                    }
                    .padding(16)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func sourceChip(_ icon: String, _ title: String, _ sub: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(Theme.display(11.5, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(sub)
                .font(Theme.display(9.5))
                .foregroundStyle(Theme.inkFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.accent.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(Theme.accent.opacity(0.14), lineWidth: 0.5))
    }

    // MARK: عن التطبيق

    private var about: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("grpAbout"), tint: Theme.accent(for: "sea"))
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
                Link(destination: URL(string: "https://ehsan.sa")!) {
                    SettingsRow(icon: "heart.fill", tint: Theme.accent(for: "gold"),
                                title: loc("rowSadaqah"),
                                subtitle: loc("المنصة الوطنية للعمل الخيري")) {
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                .buttonStyle(.plain)

                SettingsDivider()
                ShareLink(item: Self.appStoreURL,
                          message: Text(loc("تطبيق أثر — أذكار وأوقات الصلاة ومسبحة. مجاني بلا إعلانات، ويعمل بدون إنترنت."))) {
                    SettingsRow(icon: "square.and.arrow.up.fill", tint: Theme.accent,
                                title: loc("rowShare"), subtitle: loc("مَن دلَّ على خيرٍ فله مثل أجر فاعله")) {
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
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Theme.gold.opacity(0.45)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                EightPointStar()
                    .fill(Theme.goldGradient)
                    .frame(width: 15, height: 15)
                Rectangle()
                    .fill(LinearGradient(colors: [Theme.gold.opacity(0.45), .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            .frame(maxWidth: 240)
            Text("﴿ وَمَا تُقَدِّمُوا لِأَنفُسِكُم مِّنْ خَيْرٍ تَجِدُوهُ عِندَ اللَّهِ ﴾")
                .font(Theme.dhikrFont(size: 15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            Text(loc("صدقة جارية عن كل من ساهم فيه أو دلَّ عليه"))
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



/// مضيف صغير يملك مزوّد الموقع طوال عمر الورقة: LocationPickerView يستقبله
/// كـ@ObservedObject أي أنه لا يملكه، فلو أُنشئ داخل مغلِّف الورقة لضاع مع كل
/// إعادة رسم وانقطع تتبّع الموقع في منتصفه.
private struct LocationPickerHost: View {
    @StateObject private var location: LocationProvider

    init(store: AtharStore) {
        _location = StateObject(wrappedValue: LocationProvider(store: store))
    }

    var body: some View {
        LocationPickerView(location: location)
    }
}

