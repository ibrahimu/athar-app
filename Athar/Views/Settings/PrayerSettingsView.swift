import SwiftUI
import WidgetKit

/// الصلاة والمواقيت: كل ما يخصّ المواقيت في صفحة واحدة — الموقع وطريقة الحساب
/// وضبط الدقائق أولًا، ثم تنبيهات الأذان وما حولها — بدل تبعثرها في جذر الإعدادات.
struct PrayerSettingsView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var showCityPicker = false
    @State private var permissionDenied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                times
                alerts
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: Theme.accent(for: "night")) }
        .navigationTitle(loc("الصلاة والمواقيت"))
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
        // تغيّر الموقع يعني مواقيت وأسماء مدنٍ جديدة، فنعيد جدولة الأذان
        // بعد إغلاق الورقة تمامًا كما تفعل صفوف طريقة الحساب والعصر،
        // وإلا بقيت تنبيهات المدينة السابقة تعمل سبعة أيام.
        .sheet(isPresented: $showCityPicker, onDismiss: { refreshPrayers() }) {
            // الكسوة الموحّدة تثبّت اتجاه الكتابة وتوحّد شكل الورقة مع نفس المنتقي في المواقيت والقبلة.
            LocationPickerHost(store: store)
                .atharSheetChrome()
        }
    }

    // MARK: المواقيت

    private var times: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("المواقيت"), tint: Theme.accent(for: "night"))
            SettingsCard {
                Button { showCityPicker = true } label: {
                    SettingsRow(icon: "location.fill", tint: Theme.accent(for: "calm"), title: loc("rowLocation")) {
                        HStack(spacing: 6) {
                            SettingsValue(text: store.placeName)
                            chevron
                        }
                    }
                }
                .buttonStyle(.plain)

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
                NavigationLink { PrayerOffsetsView() } label: {
                    SettingsRow(icon: "plusminus.circle.fill", tint: Theme.accent(for: "noon"),
                                title: loc("ضبط المواقيت بالدقائق"),
                                subtitle: store.hasPrayerOffsets ? loc("معدَّلة — اضغط للمراجعة") : loc("دقائق زيادةً أو نقصًا لتطابق مسجدك")) {
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: التنبيهات

    private var alerts: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("تنبيهات الصلاة"), tint: Theme.accent(for: "gold"))
            SettingsCard {
                // «تخصيص كل صلاة» لا يُجدوِل شيئًا والمفتاح العام مطفأ (scheduleAthan
                // يرتدّ عند أوّله)، فكان يَعِد بما لا يقع. فموضعه حيث موضع أخواته:
                // تحت المفتاح، لا فوقه.
                // النشاط الحيّ: عدّ الصلاة القادمة على شاشة القفل والجزيرة في النصف ساعة
                // الأخيرة قبل الأذان. إيقافه يُنهي ما هو قائم فورًا؛ وتشغيله يطلبه إن كان الأذان قريبًا.
                SettingsRow(icon: "timer", tint: Theme.accent(for: "sea"),
                            title: loc("النشاط الحيّ"),
                            subtitle: loc("عدّ الصلاة القادمة على شاشة القفل قبل الأذان بنصف ساعة")) {
                    Toggle("", isOn: Binding(
                        get: { store.liveActivityEnabled },
                        set: { enabled in
                            store.liveActivityEnabled = enabled
                            if enabled { LiveActivityManager.sync(store: store) } else { LiveActivityManager.endAll() }
                        }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(loc("النشاط الحيّ"))
                }

                SettingsDivider()
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
                    // المفتاح بلا عنوان مرئي، فيقرأ VoiceOver اسم الصف بدل «مفتاح» فقط.
                    .accessibilityLabel(loc("rowAthan"))
                }

                // صوت الأذان والتنبيه القبلي والإقامة لا معنى لها والتنبيه موقوف،
                // فتظهر تحت المفتاح حين يُفعَّل — كما كانت في جذر الإعدادات.
                if store.athanAlerts {
                    SettingsDivider()
                    NavigationLink { PrayerAlertsView() } label: {
                        SettingsRow(icon: "slider.horizontal.below.rectangle", tint: Theme.accent(for: "dusk"),
                                    title: loc("تخصيص كل صلاة"),
                                    subtitle: store.hasCustomPrayerPrefs ? loc("مخصَّصة — اضغط للمراجعة") : loc("صوت أو صمت أو تنبيه قبلي لكل فريضة")) {
                            chevron
                        }
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()
                    // شاشة مخصّصة لا SettingsChoiceList: فيها استماع لكل صوت،
                    // والاختيار لا يُغلقها حتى يقارن المستخدم بين الأصوات.
                    NavigationLink { AthanSoundPicker(onChange: refreshPrayers) } label: {
                        SettingsRow(icon: "speaker.wave.2.fill", tint: Theme.accent(for: "dusk"),
                                    title: loc("صوت الأذان")) {
                            HStack(spacing: 6) {
                                Text(store.athanSound.shortTitle)
                                    .font(Theme.display(15, weight: .medium))
                                    .foregroundStyle(Theme.inkSoft)
                                    .lineLimit(1)
                                chevron
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()
                    SettingsPickerRow(
                        icon: "alarm.fill", tint: Theme.accent(for: "gold"),
                        title: loc("تنبيه قبل الأذان"), options: PreAthanChoice.allCases,
                        selection: Binding(
                            get: { PreAthanChoice.from(minutes: store.preAthanMinutes) },
                            set: { choice in
                                store.preAthanMinutes = choice.rawValue
                                Task { await Reminders.rescheduleAthan(store: store) }
                            }))
                    SettingsDivider()
                    SettingsPickerRow(
                        icon: "bell.badge.fill", tint: Theme.accent(for: "green"),
                        title: loc("تنبيه الإقامة"), options: IqamahChoice.allCases,
                        selection: Binding(
                            get: { IqamahChoice.from(minutes: store.iqamahMinutes) },
                            set: { choice in
                                store.iqamahMinutes = choice.rawValue
                                Task { await Reminders.rescheduleAthan(store: store) }
                            }))
                }

                // الجاهزية تُعرض ولو كان الأذان موقوفًا: الأذكار والورد والختمة تمرّ
                // من الطريق نفسه، ومن لم يصله شيءٌ منها فسببه هنا لا في مفتاح الأذان.
                SettingsDivider()
                NavigationLink { NotificationHealthView() } label: {
                    SettingsRow(icon: "checkmark.seal.fill", tint: Theme.accent(for: "sea"),
                                title: loc("جاهزية التنبيهات"),
                                subtitle: healthSubtitle) {
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
            if store.athanAlerts { coverage }
        }
        .animation(Motion.smooth, value: store.athanAlerts)
    }

    /// مدى التغطية في سطر الصفّ نفسه: الرقم الذي يسأل عنه الناس أوّلًا يُرى بلا فتح صفحة.
    private var healthSubtitle: String {
        guard let date = store.defaults.object(forKey: Reminders.coverageKey) as? Date else {
            return loc("الإذن والصوت وعدد التنبيهات المجدولة")
        }
        return loc("الأذان مجدول حتى %1$@", Reminders.momentText(date, timeZone: store.placeTimeZone))
    }

    /// تذكيرٌ صريح بأن التغطية منتهية: سقف النظام لا يحتمل أكثر من أيام، والتجديد
    /// لا يقع إلا بفتح التطبيق — فقولُها مرّةً أصدق من صمتٍ يظنّه المستخدم ضمانًا.
    private var coverage: some View {
        Text(loc("افتح أثر كل بضعة أيام لتجديد التنبيهات. سنذكّرك قبل نهاية التغطية، لكن استمرارها يحتاج فتح التطبيق."))
            .font(Theme.display(12))
            .foregroundStyle(Theme.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
    }

    private func refreshPrayers() {
        WidgetCenter.shared.reloadAllTimelines()
        // قيام الليل وتنبيهات الأذان كلاهما يتبعان المكان وطريقة الحساب، فتُعاد جدولتهما معًا.
        Task { await Reminders.rescheduleAll(store: store) }
        WatchSync.shared.push(store: store)
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
