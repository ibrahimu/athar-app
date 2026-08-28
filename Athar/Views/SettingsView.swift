import SwiftUI
import WidgetKit

struct SettingsView: View {
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
        NavigationStack {
            Form {
                Section("التذكير") {
                    Toggle("تذكير الأذكار", isOn: Binding(
                        get: { store.remindersEnabled },
                        set: { enabled in
                            store.remindersEnabled = enabled
                            Task {
                                if enabled {
                                    let granted = await Reminders.requestAuthorization()
                                    if !granted {
                                        store.remindersEnabled = false
                                        permissionDenied = true
                                        return
                                    }
                                }
                                await Reminders.reschedule(store: store)
                            }
                        }
                    ))

                    if store.remindersEnabled {
                        DatePicker("أذكار الصباح", selection: morningBinding, displayedComponents: .hourAndMinute)
                        DatePicker("أذكار المساء", selection: eveningBinding, displayedComponents: .hourAndMinute)
                    }
                }

                Section("الصلاة") {
                    Toggle("تنبيه عند دخول وقت الصلاة", isOn: Binding(
                        get: { store.athanAlerts },
                        set: { enabled in
                            store.athanAlerts = enabled
                            Task {
                                if enabled {
                                    let granted = await Reminders.requestAuthorization()
                                    if !granted {
                                        store.athanAlerts = false
                                        permissionDenied = true
                                        return
                                    }
                                }
                                await Reminders.rescheduleAthan(store: store)
                            }
                        }
                    ))

                    Picker("طريقة الحساب", selection: Binding(
                        get: { store.calculationMethod },
                        set: { store.calculationMethod = $0; refreshPrayers() }
                    )) {
                        ForEach(CalculationMethod.allCases) { Text($0.title).tag($0) }
                    }

                    Picker("وقت العصر", selection: Binding(
                        get: { store.asrMethod },
                        set: { store.asrMethod = $0; refreshPrayers() }
                    )) {
                        ForEach(AsrMethod.allCases) { Text($0.title).tag($0) }
                    }

                    LabeledContent("الموقع", value: store.placeName)
                }

                Section("العرض") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("حجم الخط")
                            Spacer()
                            Text(String(format: "%.0f٪", store.fontScale * 100))
                                .font(Theme.display(13))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        Slider(
                            value: Binding(get: { store.fontScale }, set: { store.fontScale = $0 }),
                            in: 0.85...1.6, step: 0.05
                        )
                        Text("سُبْحَانَ اللهِ وَبِحَمْدِهِ")
                            .font(Theme.dhikrFont(size: 20, scale: store.fontScale))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Toggle("الاهتزاز عند العدّ", isOn: Binding(
                        get: { store.hapticsEnabled },
                        set: { store.hapticsEnabled = $0 }
                    ))
                }

                Section("إحصائياتي") {
                    LabeledContent("أيام متتابعة", value: store.displayStreak.counterText)
                    LabeledContent("أطول تتابع", value: store.bestStreak.counterText)
                    LabeledContent("مجموع الأذكار", value: store.totalDhikrCount.counterText)
                    Button("تصفير الإحصائيات", role: .destructive) { showResetConfirm = true }
                }

                Section("عن التطبيق") {
                    LabeledContent("الإصدار", value: appVersion)
                    Link("سياسة الخصوصية", destination: URL(string: "https://ibrahimu.github.io/athar-app/privacy.html")!)
                    Link("الدعم والتواصل", destination: URL(string: "https://ibrahimu.github.io/athar-app/support.html")!)
                    ShareLink(item: Self.appStoreURL,
                              message: Text("تطبيق أثر — أذكار وأوقات الصلاة ومسبحة. مجاني بلا إعلانات، ويعمل بدون إنترنت.")) {
                        Label("انشر التطبيق", systemImage: "square.and.arrow.up")
                    }
                }

                Section {
                    VStack(spacing: 8) {
                        Text("﴿ وَمَا تُقَدِّمُوا لِأَنفُسِكُم مِّنْ خَيْرٍ تَجِدُوهُ عِندَ اللَّهِ ﴾")
                            .font(Theme.dhikrFont(size: 15))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                        Text("صدقة جارية عن كل من ساهم فيه")
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("الإعدادات")
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
