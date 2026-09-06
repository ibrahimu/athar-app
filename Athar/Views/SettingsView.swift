import SwiftUI

/// جذر الإعدادات: ستّ مجموعات قصيرة يُتوقَّع مكان كل شيء فيها — المظهر والخط في
/// الجذر لأنها الأكثر لمسًا، وما سواها صفٌّ واحد يفتح صفحته (الصلاة، التذكيرات،
/// المصحف، البيانات) بدل عشرات الصفوف المبعثرة في شاشة واحدة.
struct SettingsView: View {
    /// حين تُعرض داخل مكدّس تنقّل قائم، لا نغلّفها بمكدّس آخر.
    var embedded = false

    @EnvironmentObject private var store: AtharStore

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 30) {
                if !AppConfig.arabicOnly { languageRow.appearStagger(0) }
                appearance.appearStagger(1)
                prayer.appearStagger(2)
                reminders.appearStagger(3)
                reading.appearStagger(4)
                data.appearStagger(5)
                app.appearStagger(6)
                blessing.appearStagger(7)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 6)
            .padding(.bottom, 34)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        // الخلفية خلف ScrollView لا حوله في ZStack، فيبقى هو جذر الشاشة الذي
        // يكتشفه شريط العنوان ويعامل حافته العلوية عند التمرير تحته.
        .background {
            ZStack {
                AtharBackground(tint: Theme.accent, secondary: Theme.gold)
                settingsAura
            }
        }
        .navigationTitle(loc("settings"))
        .navigationBarTitleDisplayMode(.inline)
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

    /// سهم الصفوف التي تفتح شاشة — واحد للجميع فلا يتفرّق مقاسه.
    private var chevron: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.inkFaint)
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

    // MARK: المظهر والخط

    private var appearance: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("المظهر والخط"), tint: Theme.accent(for: "calm"))
            SettingsCard {
                NavigationLink { AppearanceView() } label: {
                    SettingsRow(icon: "paintpalette.fill", tint: Theme.accent(for: "calm"),
                                title: loc("rowAppearance"),
                                subtitle: "\(store.appTheme.title) · \(store.backgroundPattern.title)") {
                        chevron
                    }
                }
                .buttonStyle(.plain)

                SettingsDivider()
                fontChips

                SettingsDivider()
                fontScale

                SettingsDivider()
                lighting
            }
        }
    }

    /// خط الواجهة: ثلاث رقاقات، كلٌّ منها مكتوبة بخطّها هي — فما تراه هو ما ستختاره.
    private var fontChips: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                IconChip(icon: "textformat", tint: Theme.accent(for: "dusk"), size: .sm)
                Text(loc("خط الواجهة"))
                    .font(Theme.display(16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(AppFont.allCases) { font in fontChip(font) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("خط الواجهة"))
            Text(loc("القرآن والأذكار والحديث تبقى بخط النسخ مهما اخترت هنا."))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func fontChip(_ font: AppFont) -> some View {
        let on = store.uiFont == font
        return Button {
            withAnimation(Motion.gentle) { store.uiFont = font }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 3) {
                // العيّنة بالخط نفسه لا بخط الواجهة الحالي.
                Text("أثر")
                    .font(font.font(size: Theme.scaled(19), weight: .medium))
                    .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                Text(font.title)
                    .font(Theme.display(11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.onAccent.opacity(0.85) : Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceAlt))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(on ? .clear : Theme.hairline.opacity(0.6), lineWidth: 0.5)
            )
        }
        .pressable()
        .accessibilityLabel(font.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var fontScale: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                IconChip(icon: "textformat.size", tint: Theme.accent(for: "sea"), size: .sm)
                Text(loc("rowFont"))
                    .font(Theme.display(16, weight: .regular))
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
                .accessibilityLabel(loc("حجم الخط"))
                .accessibilityValue(String(format: "%.0f٪", store.fontScale * 100))
                Text("أ").font(.system(size: 21)).foregroundStyle(Theme.inkFaint)
            }

            Text(loc("سُبْحَانَ اللهِ وَبِحَمْدِهِ"))
                .font(Theme.dhikrFont(size: 19, scale: store.fontScale))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                        .fill(Theme.surfaceAlt)
                )
                .animation(Motion.snappy, value: store.fontScale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    /// الإضاءة (حسب الجهاز / فاتح / داكن) — المفتاح نفسه الذي في شاشة المظهر، لكنه
    /// هنا في الجذر لأنه يُلمس أكثر من أي إعداد مظهر آخر.
    private var lighting: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                IconChip(icon: "circle.lefthalf.filled", tint: Theme.accent(for: "night"), size: .sm)
                Text(loc("lighting"))
                    .font(Theme.display(16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(AppearanceMode.allCases) { mode in lightingChip(mode) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("lighting"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func lightingChip(_ mode: AppearanceMode) -> some View {
        let on = store.appearance == mode
        return Button {
            withAnimation(Motion.smooth) { store.appearance = mode }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: mode == .system ? "circle.lefthalf.filled"
                                : mode == .light ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 13))
                Text(mode.title).font(Theme.display(13, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceAlt))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(on ? .clear : Theme.hairline.opacity(0.6), lineWidth: 0.5)
            )
        }
        .pressable()
        .accessibilityLabel(mode.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: الصلاة والمواقيت

    private var prayer: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الصلاة والمواقيت"), tint: Theme.accent(for: "night"))
            SettingsCard {
                NavigationLink { PrayerSettingsView() } label: {
                    SettingsRow(icon: "moon.stars.fill", tint: Theme.accent(for: "night"),
                                title: loc("المواقيت والتنبيهات"),
                                subtitle: "\(store.placeName) · \(store.calculationMethod.shortTitle)") {
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: التذكيرات

    /// عدد التذكيرات المفعّلة — تنبيه الأذان ليس منها؛ مكانه مجموعة الصلاة.
    private var activeReminders: Int {
        [store.remindersEnabled, store.hadithReminder, store.wirdEnabled, store.qiyamAlert,
         store.istighfarAlerts, store.jumuahAlert, store.fastingAlert, store.whiteDaysAlert]
            .filter { $0 }.count
    }

    private var remindersSubtitle: String {
        switch activeReminders {
        case 0:  return loc("لا تذكيرات مفعّلة")
        case 1:  return loc("تذكير واحد مفعّل")
        case 2:  return loc("تذكيران مفعّلان")
        default: return loc("%1$@ تذكيرات مفعّلة", activeReminders.counterText)
        }
    }

    private var reminders: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("التذكيرات"), tint: Theme.accent(for: "gold"))
            SettingsCard {
                NavigationLink { RemindersSettingsView() } label: {
                    SettingsRow(icon: "bell.badge.fill", tint: Theme.accent(for: "gold"),
                                title: loc("الأذكار والحديث والورد والسنن"),
                                subtitle: remindersSubtitle) {
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: المصحف والقراءة

    private var reading: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("المصحف والقراءة"), tint: Theme.accent(for: "green"))
            SettingsCard {
                NavigationLink { ReadingSettingsView() } label: {
                    SettingsRow(icon: "book.closed.fill", tint: Theme.accent(for: "green"),
                                title: loc("وضع القراءة والصوت"),
                                subtitle: "\(store.readingMode.title) · \(store.readingTheme.title)") {
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: بياناتك

    private var data: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("بياناتك"), tint: Theme.accent(for: "sea"))
            SettingsCard {
                NavigationLink { DataSettingsView() } label: {
                    SettingsRow(icon: "externaldrive.fill.badge.icloud", tint: Theme.accent(for: "sea"),
                                title: loc("المزامنة والنسخ والإحصاء"),
                                subtitle: store.cloudSyncEnabled ? loc("مزامنة iCloud مفعّلة") : loc("تصدير واستيراد، وأرقامك وتصفيرها")) {
                        chevron
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: التطبيق

    private var app: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("التطبيق"), tint: Theme.accent(for: "dusk"))
            SettingsCard {
                SettingsRow(icon: "hand.tap.fill", tint: Theme.accent(for: "gold"), title: loc("rowHaptics")) {
                    Toggle("", isOn: Binding(
                        get: { store.hapticsEnabled },
                        set: { store.hapticsEnabled = $0 }
                    ))
                    .labelsHidden()
                    .accessibilityLabel(loc("rowHaptics"))
                }
                SettingsDivider()
                SettingsPickerRow(
                    icon: "hand.point.up.left.fill", tint: Theme.accent(for: "calm"),
                    title: loc("منطقة العدّ"), options: CountTapArea.allCases,
                    selection: Binding(
                        get: { store.countTapArea },
                        set: { store.countTapArea = $0 }))
                SettingsDivider()
                NavigationLink { SourcesView() } label: {
                    SettingsRow(icon: "checkmark.seal.fill", tint: Theme.accent(for: "green"),
                                title: loc("المصادر والحقوق"),
                                subtitle: loc("نصوصٌ موثّقة ومراجَعة — اطّلع على مصدر كل ما في التطبيق")) {
                        chevron
                    }
                }
                .buttonStyle(.plain)
                SettingsDivider()
                linkRow("hand.raised.fill", Theme.accent(for: "calm"), loc("rowPrivacy"),
                        "https://ibrahimu.github.io/athar-app/privacy.html")
                SettingsDivider()
                linkRow("lifepreserver.fill", Theme.accent(for: "sea"), loc("rowSupport"),
                        "https://ibrahimu.github.io/athar-app/support.html")
                SettingsDivider()
                Link(destination: URL(string: "https://ehsan.sa")!) {
                    sadaqahRow
                }
                .buttonStyle(.plain)
                SettingsDivider()
                ShareLink(item: Self.appStoreURL,
                          message: Text(loc("تطبيق أثر — أذكار وأوقات الصلاة ومسبحة. مجاني بلا إعلانات، ويعمل بلا إنترنت."))) {
                    // يفتح ورقة المشاركة لا شاشة، والرقاقة تحمل رمز المشاركة أصلًا؛ فلا سهم.
                    SettingsRow(icon: "square.and.arrow.up.fill", tint: Theme.accent,
                                title: loc("rowShare"), subtitle: loc("مَن دلَّ على خيرٍ فله مثل أجر فاعله"))
                }
                .buttonStyle(.plain)
                SettingsDivider()
                SettingsRow(icon: "info.circle.fill", tint: Theme.inkSoft, title: loc("rowVersion")) {
                    SettingsValue(text: appVersion)
                }
            }
        }
    }

    /// صفّ إحسان: كصفّ الإعداد نفسه، لكن الرقاقة تحمل شعار المنصة بدل رمز النظام —
    /// بألوانه الأصلية، وقالبًا بلون واحد حين تُوحَّد الأيقونات.
    private var sadaqahRow: some View {
        let gold = Theme.accent(for: "gold")
        let chip = IconChip.Size.sm.rawValue
        return HStack(spacing: 13) {
            Image("EhsanLogo")
                .renderingMode(store.unifyIcons ? .template : .original)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.accent)
                .frame(width: chip * 0.55, height: chip * 0.55)
                .frame(width: chip, height: chip)
                .background(Circle().fill(gold.opacity(0.13)))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(loc("rowSadaqah"))
                    .font(Theme.display(16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                Text(loc("المنصة الوطنية للعمل الخيري"))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
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
            // الآية برسم المصحف المضمَّن نفسه، وبلون النص الشرعي، ومعها مرجعها.
            Text("وَمَا تُقَدِّمُوا۟ لِأَنفُسِكُم مِّنْ خَيْرٍ تَجِدُوهُ عِندَ ٱللَّهِ")
                .font(Theme.dhikrFont(size: 15))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(loc("البقرة: 110"))
                .font(Theme.display(10))
                .foregroundStyle(Theme.inkFaint)
            Text(loc("صدقة جارية عن كل من ساهم فيه أو دلَّ عليه"))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: Helpers

    /// App Store page for أثر (Apple ID 6806411693).
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id6806411693")!

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
