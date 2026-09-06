import SwiftUI

/// التذكيرات كلها في صفحة واحدة: اليومية (الأذكار والحديث والورد وقيام الليل والاستغفار)
/// ثم السنن (الجمعة والصيام والأيام البيض) — فيعرف المستخدم أين يبحث عن أي تذكير.
struct RemindersSettingsView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var rescheduleTask: Task<Void, Never>?
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

    private var hadithBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: store.hadithReminderMinutes) },
            set: {
                store.hadithReminderMinutes = Self.minutes(from: $0)
                scheduleHadith()
            }
        )
    }

    /// كما في شاشة الورد نفسها: الوقت يُحفظ ويُعاد جدولة تذكير الورد وحده.
    private var wirdBinding: Binding<Date> {
        Binding(
            get: { Self.date(fromMinutes: store.wirdReminderMinutes) },
            set: {
                store.wirdReminderMinutes = Self.minutes(from: $0)
                Task { await Reminders.rescheduleWird(store: store) }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                daily
                sunan
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: Theme.accent(for: "gold")) }
        .navigationTitle(loc("التذكيرات"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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

    // MARK: اليومية

    private var daily: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("اليومية"), tint: Theme.accent(for: "gold"))
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
                    // المفتاح بلا عنوان مرئي، فيقرأ VoiceOver اسم الصف بدل «مفتاح» فقط.
                    .accessibilityLabel(loc("rowAdhkarRem"))
                }

                if store.remindersEnabled {
                    if !store.adhkarReminderByPrayer {
                    SettingsDivider()
                    SettingsRow(icon: "sunrise.fill", tint: Theme.accent(for: "dawn"), title: loc("rowMorning")) {
                        DatePicker("", selection: morningBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityLabel(loc("rowMorning"))
                    }
                    }
                    SettingsDivider()
                    SettingsRow(icon: "clock.arrow.2.circlepath", tint: Theme.accent(for: "green"),
                                title: loc("بوقت الصلاة"), subtitle: loc("الصباح بعد الفجر والمساء بعد العصر تلقائيًّا")) {
                        Toggle("", isOn: Binding(get: { store.adhkarReminderByPrayer }, set: { store.adhkarReminderByPrayer = $0; scheduleReminders() }))
                            .labelsHidden()
                            .accessibilityLabel(loc("تذكير الأذكار بوقت الصلاة"))
                    }
                    if !store.adhkarReminderByPrayer {
                    SettingsDivider()
                    SettingsRow(icon: "moon.stars.fill", tint: Theme.accent(for: "dusk"), title: loc("rowEvening")) {
                        DatePicker("", selection: eveningBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityLabel(loc("rowEvening"))
                    }
                    }
                }

                SettingsDivider()
                SettingsRow(icon: "text.quote", tint: Theme.accent(for: "sea"),
                            title: loc("تذكير حديث اليوم"),
                            subtitle: store.hadithReminder ? nil : loc("حديث من الصحيحين كل يوم")) {
                    Toggle("", isOn: Binding(
                        get: { store.hadithReminder },
                        set: { enabled in
                            store.hadithReminder = enabled
                            Task {
                                if enabled, await !Reminders.requestAuthorization() {
                                    store.hadithReminder = false
                                    permissionDenied = true
                                    return
                                }
                                await Reminders.rescheduleHadith(store: store)
                            }
                        }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(loc("تذكير حديث اليوم"))
                }

                if store.hadithReminder {
                    SettingsDivider()
                    SettingsRow(icon: "clock.fill", tint: Theme.accent(for: "dusk"), title: loc("وقت التذكير")) {
                        DatePicker("", selection: hadithBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityLabel(loc("وقت تذكير الحديث"))
                    }
                }

                SettingsDivider()
                SettingsRow(icon: "bookmark.fill", tint: Theme.accent(for: "dawn"),
                            title: loc("تذكير الورد"),
                            subtitle: store.wirdEnabled ? nil : loc("وردك اليومي من الآيات في وقته")) {
                    Toggle("", isOn: Binding(
                        get: { store.wirdEnabled },
                        set: { on in
                            store.wirdEnabled = on
                            Task {
                                if on, await !Reminders.requestAuthorization() {
                                    store.wirdEnabled = false
                                    permissionDenied = true
                                    return
                                }
                                await Reminders.rescheduleWird(store: store)
                            }
                        }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(loc("تذكير الورد"))
                }

                if store.wirdEnabled {
                    SettingsDivider()
                    SettingsRow(icon: "clock.fill", tint: Theme.accent(for: "dusk"), title: loc("وقت التذكير")) {
                        DatePicker("", selection: wirdBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .accessibilityLabel(loc("وقت تذكير الورد"))
                    }
                }

                SettingsDivider()
                SettingsRow(icon: "moon.stars.fill", tint: Theme.accent(for: "night"), title: loc("rowQiyam"),
                            subtitle: loc("subQiyam")) {
                    Toggle("", isOn: alertToggle({ store.qiyamAlert }, { store.qiyamAlert = $0 })).labelsHidden()
                        .accessibilityLabel(loc("rowQiyam"))
                }

                SettingsDivider()
                SettingsRow(icon: "drop.fill", tint: Theme.accent(for: "sea"), title: loc("rowIstighfar"),
                            subtitle: loc("subIstighfar")) {
                    Toggle("", isOn: alertToggle({ store.istighfarAlerts }, { store.istighfarAlerts = $0 })).labelsHidden()
                        .accessibilityLabel(loc("rowIstighfar"))
                }

                if store.istighfarAlerts {
                    SettingsDivider()
                    SettingsPickerRow(
                        icon: "timer", tint: Theme.accent(for: "sea"),
                        title: loc("كل كم ساعة"), options: IstighfarInterval.allCases,
                        selection: Binding(
                            get: { IstighfarInterval.from(hours: store.istighfarEveryHours) },
                            set: { choice in
                                store.istighfarEveryHours = choice.rawValue
                                Task { await Reminders.rescheduleIstighfar(store: store) }
                            }))
                }
            }
        }
        .animation(Motion.smooth, value: store.remindersEnabled)
        .animation(Motion.smooth, value: store.adhkarReminderByPrayer)
        .animation(Motion.smooth, value: store.hadithReminder)
        .animation(Motion.smooth, value: store.wirdEnabled)
        .animation(Motion.smooth, value: store.istighfarAlerts)
    }

    // MARK: السنن

    private var sunan: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("السنن"), tint: Theme.accent(for: "dusk"))
            SettingsCard {
                SettingsRow(icon: "sparkles", tint: Theme.accent(for: "gold"), title: loc("rowJumuah"),
                            subtitle: loc("subJumuah")) {
                    Toggle("", isOn: alertToggle({ store.jumuahAlert }, { store.jumuahAlert = $0 })).labelsHidden()
                        .accessibilityLabel(loc("rowJumuah"))
                }
                SettingsDivider()
                SettingsRow(icon: "fork.knife", tint: Theme.accent(for: "sea"), title: loc("rowFasting"),
                            subtitle: loc("subFasting")) {
                    Toggle("", isOn: alertToggle({ store.fastingAlert }, { store.fastingAlert = $0 })).labelsHidden()
                        .accessibilityLabel(loc("rowFasting"))
                }
                SettingsDivider()
                SettingsRow(icon: "moon.circle.fill", tint: Theme.accent(for: "dusk"), title: loc("rowWhite"),
                            subtitle: loc("subWhite")) {
                    Toggle("", isOn: alertToggle({ store.whiteDaysAlert }, { store.whiteDaysAlert = $0 })).labelsHidden()
                        .accessibilityLabel(loc("rowWhite"))
                }
            }
        }
    }

    // MARK: Helpers

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

    /// عجلة الوقت تُطلق التغيير مع كل درجة؛ فتُؤجَّل الجدولة نصف ثانية وتُلغى السابقة —
    /// لا تُعاد جدولة كل إشعارات التطبيق عشرات المرات وأنت تدير العجلة.
    private func scheduleReminders() {
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await Reminders.reschedule(store: store)
        }
    }

    private func scheduleHadith() {
        rescheduleTask?.cancel()
        rescheduleTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await Reminders.rescheduleHadith(store: store)
        }
    }

    private static func date(fromMinutes minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minutes(from date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

/// فاصل تذكير الاستغفار بالساعات: خيارات قليلة لا حقل رقمي — الجدولة تبدأ من الثامنة
/// صباحًا حتى التاسعة مساءً، فكل ساعة يعني أربعة عشر إشعارًا وهذا كثير.
private enum IstighfarInterval: Int, CaseIterable, SettingsChoice {
    case h2 = 2, h3 = 3, h4 = 4, h6 = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .h2: return loc("كل ساعتين")
        case .h3: return loc("كل 3 ساعات")
        case .h4: return loc("كل 4 ساعات")
        case .h6: return loc("كل 6 ساعات")
        }
    }

    var shortTitle: String { title }

    var detail: String { loc("من الثامنة صباحًا حتى التاسعة مساءً — بلا إزعاج ليلي") }

    /// يطابق الساعات المخزَّنة بأقرب خيار، فلا تنكسر القائمة لو تغيّرت القيمة من خارجها.
    static func from(hours: Int) -> IstighfarInterval {
        allCases.min { abs($0.rawValue - hours) < abs($1.rawValue - hours) } ?? .h3
    }
}
