import SwiftUI
import UserNotifications

/// جاهزية التنبيهات: بين ما ضبطه صاحب الجهاز وما يفعله النظام حقًّا فرقٌ لا يُرى —
/// إذنٌ سُحب، أو صوتٌ أُطفئ، أو سقفٌ امتلأ، أو تغطيةٌ انتهت أمس. تعرض هذه الصفحة
/// ذلك كما هو بلا تجميل: من أعياه أذانٌ لا يصل يجد ها هنا سببه، لا طمأنينةً كاذبة.
struct NotificationHealthView: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.scenePhase) private var scenePhase

    /// نسخةٌ من حال النظام لا الكائن الحيّ نفسه: الصفحة قراءةٌ للحظةٍ بعينها،
    /// وتجديدها صريحٌ عند الظهور والعودة — فلا يتبدّل ما تحت النظر بلا سبب ظاهر.
    @State private var health: Health?
    @State private var test: TestOutcome = .untried

    private enum TestOutcome: Equatable { case untried, scheduled, refused }

    private struct Health {
        let authorization: UNAuthorizationStatus
        let alert: UNNotificationSetting
        let sound: UNNotificationSetting
        let timeSensitive: UNNotificationSetting
        let summary: UNNotificationSetting
        let pending: Int
    }

    private var tint: Color { Theme.accent(for: "sea") }

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                permission
                delivery
                athanSound
                schedule
                trial
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: tint) }
        .navigationTitle(loc("جاهزية التنبيهات"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await refresh() }
        // العودة من إعدادات الجهاز هي أكثر ما يبدّل هذه الأرقام، ولا إشعار يبلّغنا
        // بتبدّلها — فتُقرأ من جديد مع كل عودة بدل أن تبقى صورةً مضى وقتها.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
        .animation(Motion.smooth, value: test)
    }

    // MARK: الإذن

    private var permission: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الإذن"), tint: tint)
            SettingsCard {
                SettingsRow(icon: "bell.badge.fill", tint: authorizationBadge.tint,
                            title: loc("إذن الإشعارات"),
                            subtitle: authorizationNote) {
                    badge(authorizationBadge.text, authorizationBadge.tint)
                }
                .accessibilityElement(children: .combine)

                // الرفض لا يُرفع من داخل التطبيق، والطلب لا يُعاد بعد أن رُدّ مرّة —
                // فالطريق الوحيد إعدادات الجهاز، ويُفتح بزرٍّ لا بوصفٍ لمكانها.
                if health?.authorization == .denied {
                    SettingsDivider()
                    Button { openSystemSettings() } label: {
                        SettingsRow(icon: "gearshape.fill", tint: tint,
                                    title: loc("فتح الإعدادات"),
                                    subtitle: loc("أثر ← الإشعارات ← السماح بالإشعارات"))
                    }
                    .buttonStyle(.plain)
                }

                if health?.authorization == .notDetermined {
                    SettingsDivider()
                    Button {
                        Task {
                            _ = await Reminders.requestAuthorization()
                            await refresh()
                        }
                    } label: {
                        SettingsRow(icon: "hand.raised.fill", tint: tint,
                                    title: loc("اطلب الإذن الآن"),
                                    subtitle: loc("لم يُسأل بعدُ عن الإشعارات؛ بلا إذنٍ لا يصل شيء"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var authorizationBadge: (text: String, tint: Color) {
        guard let health else { return (loc("جارٍ القراءة"), Theme.inkFaint) }
        switch health.authorization {
        case .authorized:   return (loc("مسموح"), Theme.success)
        case .provisional:  return (loc("مبدئيّ"), Theme.gold)
        case .ephemeral:    return (loc("مؤقّت"), Theme.gold)
        case .denied:       return (loc("موقوف"), Theme.danger)
        case .notDetermined: return (loc("لم يُطلب"), Theme.inkFaint)
        @unknown default:   return (loc("غير معروف"), Theme.inkFaint)
        }
    }

    private var authorizationNote: String? {
        guard let health else { return nil }
        switch health.authorization {
        case .provisional, .ephemeral:
            return loc("تصل بهدوء إلى مركز الإشعارات بلا صوت ولا بطاقة")
        case .denied:
            return loc("لا يصلك أذان ولا تذكير حتى يُسمح بها من إعدادات الجهاز")
        default:
            return nil
        }
    }

    // MARK: كيف تصل

    private var delivery: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("كيف تصل"), tint: tint)
            SettingsCard {
                SettingsRow(icon: "clock.badge.exclamationmark.fill", tint: Theme.accent(for: "gold"),
                            title: loc("الحسّاسة للوقت"),
                            subtitle: loc("تخترق «عدم الإزعاج» وأوضاع التركيز — بها يبلغك الأذان في وقته")) {
                    settingBadge(health?.timeSensitive)
                }
                .accessibilityElement(children: .combine)

                SettingsDivider()
                SettingsRow(icon: "speaker.wave.2.fill", tint: Theme.accent(for: "dusk"),
                            title: loc("الصوت"),
                            subtitle: health?.sound == .disabled
                                ? loc("الإشعارات تصل صامتة، فلا يُسمع الأذان وإن اختير")
                                : nil) {
                    settingBadge(health?.sound)
                }
                .accessibilityElement(children: .combine)

                SettingsDivider()
                SettingsRow(icon: "text.bubble.fill", tint: Theme.accent(for: "night"),
                            title: loc("البطاقة على الشاشة")) {
                    settingBadge(health?.alert)
                }
                .accessibilityElement(children: .combine)

                // «الملخّص المجدول» يجمع الإشعارات ويؤخّرها إلى موعده، وهو سببٌ خفيّ
                // لأذانٍ يصل متأخّرًا. لا يُعرض إلا حين يكون قائمًا فلا يزحم من لا يعنيه.
                if health?.summary == .enabled {
                    SettingsDivider()
                    SettingsRow(icon: "tray.full.fill", tint: Theme.gold,
                                title: loc("الملخّص المجدول"),
                                subtitle: loc("يؤخّر الإشعارات إلى موعد الملخّص، والحسّاسة للوقت تتخطّاه")) {
                        badge(loc("مفعّل"), Theme.gold)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    // MARK: صوت الأذان

    private var athanSound: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("صوت الأذان"), tint: tint)
            SettingsCard {
                SettingsRow(icon: "music.note", tint: Theme.accent(for: "dusk"),
                            title: loc("الصوت المختار"),
                            subtitle: store.athanAlerts ? nil : loc("تنبيه دخول الوقت موقوف، فلا يُسمع هذا الصوت")) {
                    SettingsValue(text: store.athanSound.shortTitle)
                }
                .accessibilityElement(children: .combine)
            }
            footnote(loc("يقطع iOS صوت أي إشعار عند 30 ثانية، فيصلك أول 30 ثانية من الأذان لا الأذان كله."))
        }
    }

    // MARK: الجدولة

    private var schedule: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الجدولة"), tint: tint)
            SettingsCard {
                SettingsRow(icon: "list.bullet.rectangle.fill", tint: tint,
                            title: loc("تنبيهات مجدولة الآن"),
                            subtitle: loc("سقف النظام %1$@ تنبيهًا لكل تطبيق", Reminders.systemLimit.counterText)) {
                    SettingsValue(text: pendingText)
                }
                .accessibilityElement(children: .combine)

                SettingsDivider()
                SettingsRow(icon: "arrow.clockwise", tint: Theme.accent(for: "green"),
                            title: loc("آخر تجديد")) {
                    SettingsValue(text: lastRefreshText)
                }
                .accessibilityElement(children: .combine)

                SettingsDivider()
                SettingsRow(icon: "calendar.badge.clock", tint: Theme.accent(for: "night"),
                            title: loc("التغطية حتى"),
                            subtitle: loc("آخر أذانٍ مجدول — وبعده يسكت النداء حتى تفتح أثر")) {
                    // التاريخ الطويل كان يتشظّى سطرين أو ثلاثة ويزاحم العنوان.
                    SettingsValue(text: coverageText)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                .accessibilityElement(children: .combine)

                // الإخفاقات لا تُعرض صفرًا: عدّادٌ ساكن على الصفر يعلّم القارئ تجاهله،
                // فإذا نطق يومًا لم ينتبه له.
                if failures > 0 {
                    SettingsDivider()
                    SettingsRow(icon: "exclamationmark.triangle.fill", tint: Theme.danger,
                                title: loc("طلبات ردّها النظام"),
                                subtitle: loc("قد يكون السقف امتلأ أو الإذن سُحب — افتح أثر ثانيةً بعد مراجعة ما فوق")) {
                        badge(failures.counterText, Theme.danger)
                    }
                    .accessibilityElement(children: .combine)
                }

                // ما ضاق عنه سقف النظام كان يُرمى صامتًا، والأبعدُ موعدًا أوّلُ من يسقط
                // (الأيام البيض، ثم الجمعة والصيام) — فيبقى صاحبه ينتظر تذكيرًا لن يأتي.
                if dropped > 0 {
                    SettingsDivider()
                    SettingsRow(icon: "tray.full.fill", tint: Theme.gold,
                                title: loc("لم يتّسع لها السقف"),
                                subtitle: loc("سقف النظام ٦٤ تنبيهًا معلّقًا — والأبعد موعدًا أوّل من يسقط. أوقف ما لا تحتاجه ليتّسع لغيره")) {
                        badge(dropped.counterText, Theme.gold)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            footnote(loc("التنبيهات تُجدَّد كلّما فُتح أثر. سنذكّرك قبل نهاية التغطية بساعات، لكن استمرارها يحتاج فتح التطبيق."))
        }
    }

    private var pendingText: String {
        guard let health else { return loc("جارٍ القراءة") }
        return loc("%1$@ من %2$@", health.pending.counterText, Reminders.systemLimit.counterText)
    }

    private var lastRefreshText: String {
        guard let date = store.defaults.object(forKey: Reminders.lastRefreshKey) as? Date else {
            return loc("لم يُجدَّد بعد")
        }
        // لحظةٌ وقعت بساعة الجهاز لا بساعة المدينة المحسوبة بها المواقيت.
        return Reminders.momentText(date, timeZone: .current)
    }

    private var coverageText: String {
        guard let date = store.defaults.object(forKey: Reminders.coverageKey) as? Date else {
            return loc("لا أذان مجدول")
        }
        return Reminders.momentText(date, timeZone: store.placeTimeZone)
    }

    private var failures: Int {
        store.defaults.integer(forKey: Reminders.failuresKey)
    }

    private var dropped: Int {
        store.defaults.integer(forKey: Reminders.droppedKey)
    }

    // MARK: التجربة

    private var trial: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap(enabled: store.hapticsEnabled)
                Task {
                    let scheduled = await Reminders.sendTestNotification(store: store)
                    test = scheduled ? .scheduled : .refused
                    await refresh()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bell.and.waves.left.and.right.fill")
                    Text(loc("جرّب تنبيهًا الآن"))
                }
                .font(Theme.display(16, weight: .semibold))
                .gradientButton(Theme.gradient(for: "sea"), glow: tint)
            }
            .pressable()
            .disabled(!canTest)
            .opacity(canTest ? 1 : 0.45)

            footnote(trialNote)
        }
    }

    /// بلا إذنٍ لا تصل التجربة، وزرٌّ لا يفعل شيئًا أسوأ من زرٍّ مُطفأ.
    private var canTest: Bool {
        guard let status = health?.authorization else { return false }
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    private var trialNote: String {
        switch test {
        case .scheduled: return loc("سيصلك بعد ثوانٍ — يمكنك إغلاق أثر لتراه كما يصلك في يومك.")
        case .refused:   return loc("تعذّرت جدولة التجربة؛ راجع الإذن والسقف أعلاه.")
        case .untried:
            return canTest
                ? loc("تنبيه واحد بعد ثوانٍ، مكتوبٌ في متنه أنه تجربة، بصوت الأذان المختار.")
                : loc("التجربة تحتاج إذن الإشعارات أوّلًا.")
        }
    }

    // MARK: لبنات صغيرة

    /// شارة الحال: نقطة ملوّنة ثم كلمة. النقطة زينةٌ تُخفى عن قارئ الشاشة، فاللون
    /// وحده لا يحمل معنًى — الكلمة تقوله كاملًا لمن لا يفرّق بين الأخضر والأحمر.
    private func badge(_ text: String, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.display(14, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private func settingBadge(_ setting: UNNotificationSetting?) -> some View {
        if let setting {
            switch setting {
            case .enabled:      badge(loc("مسموح"), Theme.success)
            case .disabled:     badge(loc("موقوف"), Theme.danger)
            case .notSupported: badge(loc("غير متاح"), Theme.inkFaint)
            @unknown default:   badge(loc("غير معروف"), Theme.inkFaint)
            }
        } else {
            badge(loc("جارٍ القراءة"), Theme.inkFaint)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(Theme.display(11))
            .foregroundStyle(Theme.inkFaint)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    // MARK: القراءة

    // التقييد بالفاعل الرئيس صراحةً: هنا تُكتب حالة العرض، فلا تُترك لاجتهاد
    // مغلّف `task` في أيّ خيطٍ ينفّذها.
    @MainActor
    private func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let pending = await Reminders.pendingCount()
        health = Health(authorization: settings.authorizationStatus,
                        alert: settings.alertSetting,
                        sound: settings.soundSetting,
                        timeSensitive: settings.timeSensitiveSetting,
                        summary: settings.scheduledDeliverySetting,
                        pending: pending)
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}
