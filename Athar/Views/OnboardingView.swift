import SwiftUI
import CoreLocation
import UserNotifications

/// تظهر مرة واحدة عند أول تشغيل، في خمس خطوات: ترحيب، موقع، تنبيهات، أذان، مظهر.
/// كل خطوة تُتخطّى بلا أثر، ولا شيء يُفعّل دون علم المستخدم — وكل ما يُختار هنا
/// يبقى قابلًا للتغيير لاحقًا من الإعدادات.
struct OnboardingView: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    // مشغّل الاستماع لخطوة الأذان — بالنمط نفسه الذي يراقب به AthanSoundPicker المفرد المشترك.
    @StateObject private var preview = AthanPreview.shared

    /// ترتيب الخطوات هو ترتيب الحالات؛ «التالي» يزيد الرقم واحدًا.
    private enum Step: Int, CaseIterable { case welcome, location, reminders, athan, appearance }
    @State private var step: Step = .welcome

    @State private var wantAdhkar = true
    @State private var wantAthan = true
    @State private var wantQiyam = false
    @State private var wantIstighfar = false
    @State private var wantWird = false
    @State private var showCityPicker = false
    @State private var working = false
    @State private var denied = false
    /// حالة إذن الإشعارات كما يراها نظام التشغيل — تُقرأ عند دخول خطوة الأذان وعند العودة من
    /// إعدادات الجهاز، حتى لا يوهم مفتاح مفعّل بأذان لن يصل لأن الإذن لم يُمنح.
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    /// الأيقونة والنقش يُختاران هنا كما يُختار الطابع، لكنّ الأيقونة لا تُلبَس إلا عند
    /// «ابدأ»: تبديلها يُطلق تنبيه النظام «تم تغيير أيقونة التطبيق»، فلو طُبّق مع كل
    /// ضغطة لقاطع التنبيهُ الترحيبَ مرّةً بعد مرّة. تُجمع النيّة هنا وتُنفَّذ مرّة واحدة.
    /// هل بلغ المستخدمُ خطوةَ المظهر فرأى قسم الأيقونة؟
    @State private var sawAppearance = false
    @State private var iconMode: AppIconMode = .theme
    @State private var pickedIcon: AppIconChoice = .original

    var body: some View {
        ZStack {
            AtharBackground()

            VStack(spacing: 0) {
                chrome
                // ZStack مع switch لا TabView: جذر التطبيق RTL، والصفحات المنزلقة تعكس
                // ترتيبها هناك؛ الانتقال الصريح من الأزرار أضمن ولا يسمح بالسحب فوق خطوة.
                ZStack {
                    switch step {
                    case .welcome:
                        page { welcome }
                    case .location:
                        page { OnboardingLocationStep(store: store) { showCityPicker = true } }
                    case .reminders:
                        page { reminders }
                    case .athan:
                        page { athan }
                    case .appearance:
                        page { appearance }
                            .onAppear { sawAppearance = true }
                    }
                }
            }

            VStack {
                Spacer()
                actions
            }
        }
        .alert(loc("الإشعارات موقوفة"), isPresented: $denied) {
            Button(loc("فتح الإعدادات")) { openSystemSettings() }
            // «لاحقًا» تُكمل إلى الخطوة التالية لا تُنهي التدفّق: رفض الإشعارات لا يعني رفض الباقي.
            Button(loc("later"), role: .cancel) { advance() }
        } message: {
            Text(loc("لتصلك التذكيرات، اسمح للتطبيق بالإشعارات من إعدادات الجهاز. يمكنك تفعيلها لاحقًا من إعدادات أثر."))
        }
        .sheet(isPresented: $showCityPicker) {
            // الكسوة الموحّدة تثبّت اتجاه الكتابة وتوحّد شكل الورقة مع الإعدادات.
            OnboardingLocationHost(store: store)
                .atharSheetChrome()
        }
        // مغادرة خطوة الأذان توقف الاستماع: لا يبقى أذان يعمل خلف خطوة أخرى.
        .onChange(of: step) { _, _ in preview.stop() }
        // الخلفية وحدها توقف الاستماع — لا «غير نشط» العابر (مركز التحكّم، إشعار، مكالمة)،
        // وإلا انقطع الأذان لمجرّد سحبةٍ من أعلى الشاشة. والعودة تعيد قراءة الإذن:
        // ربّما سمح به من إعدادات الجهاز.
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { preview.stopIfBackgrounded() }
            else if phase == .active, step == .athan { refreshNotifStatus() }
        }
        // دخول خطوة الأذان يقرأ الإذن الذي حسمته خطوة التذكيرات للتوّ (أو لم تحسمه).
        .task(id: step) { if step == .athan { refreshNotifStatus() } }
    }

    private func refreshNotifStatus() {
        Task { notifStatus = await Reminders.authorizationStatus() }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    // MARK: الإطار العلوي — مؤشّر الخطوات و«تخطّي»

    private var chrome: some View {
        ZStack {
            HStack(spacing: 6) {
                ForEach(Step.allCases, id: \.rawValue) { s in
                    Capsule()
                        .fill(s == step ? Theme.accent : Theme.accent.opacity(0.22))
                        .frame(width: s == step ? 22 : 7, height: 7)
                }
            }
            .animation(reduceMotion ? nil : Motion.snappy, value: step)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(loc("الخطوة %1$@ من %2$@",
                                    (step.rawValue + 1).counterText, Step.allCases.count.counterText))

            HStack {
                Spacer()
                // الترحيب بلا «تخطّي»: خطوته الأولى قراءة لا قرار.
                if step != .welcome {
                    Button(loc("تخطّي")) { finish() }
                        .font(Theme.display(14, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(minWidth: 60, minHeight: 44)   // هدف لمس كامل لا سطر نص وحده
                        .contentShape(Rectangle())
                }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 6)
        .readableWidth(520)
    }

    /// صفحة خطوة: تمرير خاص بها (ارتفاعات الخطوات مختلفة) وانتقال مكاني واحد.
    private func page<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView {
            content()
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 12)
                .padding(.bottom, 170)
                .readableWidth(520)
        }
        .scrollIndicators(.hidden)
        .transition(pageTransition)
    }

    /// الجديد يدخل من الحافة الختامية (يسار العربية) والقديم يخرج من البادئة —
    /// اتجاه القراءة نفسه. و«تقليل الحركة» يكتفي بالتلاشي.
    private var pageTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                          removal: .move(edge: .leading).combined(with: .opacity))
    }

    // MARK: ١ — الترحيب

    private var welcome: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                ZStack {
                    // نجمة ثمانية ذهبية خافتة خلف الاسم — زخرفة لا تنافس
                    EightPointStar()
                        .fill(Theme.goldGradient)
                        .opacity(0.14)
                        .frame(width: 104, height: 104)
                    EightPointStar()
                        .stroke(Theme.gold.opacity(0.45), lineWidth: 1)
                        .frame(width: 104, height: 104)
                    Text("أثر")
                        .font(Theme.display(34, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(height: 116)
                .accessibilityHidden(true)

                Text(loc("مرحبًا بك في أثر"))
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text(loc("مصحف وتفسير وأذكار ومواقيت وحديث — بلا إعلانات، مع خدمات سحابية اختيارية"))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsCard {
                feature("book.closed.fill", Theme.accent,
                        loc("المصحف والتفسير"), loc("مصحف كامل مع تفسير ميسّر وحفظ ومراجعة"))
                SettingsDivider()
                feature("bell.and.waves.left.and.right.fill", Theme.accent(for: "dawn"),
                        loc("مواقيت الصلاة والأذان"), loc("مواقيت حسب موقعك وتنبيه بصوت الأذان"))
                SettingsDivider()
                feature("sparkles", Theme.accent(for: "calm"),
                        loc("الأذكار والحديث"), loc("أذكار الصباح والمساء وأحاديث مشروحة"))
                SettingsDivider()
                feature("dot.radiowaves.left.and.right", Theme.accent(for: "sea"),
                        loc("التلاوة والبث المباشر"), loc("تلاوات لقرّاء مختارين وبثّ مباشر"))
                SettingsDivider()
                feature("applewatch", Theme.accent(for: "night"),
                        loc("الساعة والودجات"), loc("المواقيت والأذكار على معصمك وشاشتك الرئيسية"))
            }
        }
    }

    private func feature(_ icon: String, _ tint: Color, _ title: String, _ sub: String) -> some View {
        SettingsRow(icon: icon, tint: tint, title: title, subtitle: sub)
    }

    // MARK: ٣ — التنبيهات

    private var reminders: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(loc("التنبيهات"))
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("اختر ما تحب أن نُذكّرك به، ونتكفّل بالباقي."))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            SettingsCard {
                row("sunrise.fill", Theme.accent(for: "dawn"), loc("أذكار الصباح والمساء"),
                    loc("تذكير في الوقت الذي تختاره"), $wantAdhkar)
                SettingsDivider()
                row("bell.and.waves.left.and.right.fill", Theme.accent, loc("أوقات الصلاة"),
                    loc("تنبيه عند دخول كل وقت"), $wantAthan)
                SettingsDivider()
                row("moon.stars.fill", Theme.accent(for: "night"), loc("قيام الليل"),
                    loc("عند دخول ثلث الليل الآخر"), $wantQiyam)
                SettingsDivider()
                row("drop.fill", Theme.accent(for: "sea"), loc("الاستغفار والتسبيح"),
                    loc("تذكير خفيف على مدار اليوم"), $wantIstighfar)
                SettingsDivider()
                row("book.pages.fill", Theme.gold, loc("ورد القرآن"),
                    loc("تذكير بوردك اليومي"), $wantWird)
            }

            hint("slider.horizontal.3",
                 loc("يمكنك تخصيص تنبيه كل صلاة على حدة لاحقًا من الإعدادات ← تخصيص كل صلاة."))
        }
    }

    private func row(_ icon: String, _ tint: Color, _ title: String,
                     _ sub: String, _ on: Binding<Bool>) -> some View {
        SettingsRow(icon: icon, tint: tint, title: title, subtitle: sub) {
            // المفتاح بلا عنوان مرئي، فيقرأ VoiceOver اسم الصف بدل «مفتاح» فقط.
            Toggle("", isOn: on).labelsHidden()
                .accessibilityLabel(title)
        }
    }

    /// تلميح خافت أسفل البطاقة؛ يقبل زرًّا اختياريًا تحت النص (كزرّ «فتح الإعدادات» في خطوة الموقع).
    private func hint(_ icon: String, _ text: String,
                      action: (title: String, run: () -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                if let action {
                    Button(action.title, action: action.run)
                        .font(Theme.display(13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.surfaceAlt))
    }

    // MARK: ٤ — الأذان

    /// لون الخطوة — لون «صوت الأذان» نفسه في الإعدادات.
    private var athanTint: Color { Theme.accent(for: "dusk") }

    /// الخطوة كلها على شاشة واحدة بلا تمرير (ستة أصوات): مسافات أضيق من خطوة التذكيرات،
    /// والتلميح تحت مفتاحه مباشرةً لا في ذيل الصفحة حيث يختفي خلف الأزرار.
    private var athan: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(loc("الأذان"))
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("اختر صوت المؤذّن، واستمع قبل أن تقرّر."))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            // المتغيّر نفسه الذي تكتبه خطوة التذكيرات في «أوقات الصلاة»، فالمفتاحان متزامنان.
            SettingsCard {
                row("bell.and.waves.left.and.right.fill", athanTint, loc("الأذان عند دخول وقت الصلاة"),
                    loc("تنبيه بصوت المؤذّن الذي تختاره"), $wantAthan)
            }

            // المفتاح بلا إذن إشعارات لا يفعل شيئًا، فالتلميح يقول ذلك صراحةً — تحت المفتاح لا آخر الصفحة.
            if !wantAthan {
                hint("speaker.slash.fill",
                     loc("الصوت المختار يُستعمل حين تفعّل تنبيه الصلاة، الآن أو لاحقًا من الإعدادات."))
            } else if notifStatus == .authorized {
                hint("waveform",
                     loc("يصلك أوّل ثلاثين ثانية من الأذان المختار عند كل وقت."))
            } else if notifStatus == .notDetermined {
                // لم يُطلب الإذن (ضغط «لاحقًا» في خطوة التذكيرات)، ولا نطلبه هنا: التفعيل من الإعدادات.
                hint("bell.badge",
                     loc("لم يُطلب إذن الإشعارات بعد؛ فعّل الأذان لاحقًا من الإعدادات ← الصلاة."))
            } else {
                hint("bell.slash.fill",
                     loc("الإشعارات موقوفة؛ اسمح بها من إعدادات الجهاز ليصلك الأذان."),
                     action: (loc("فتح الإعدادات"), openSystemSettings))
            }

            VStack(spacing: 6) {
                SettingsGroupTitle(text: loc("صوت الأذان"), tint: athanTint)
                SettingsCard {
                    ForEach(Array(AthanSound.allCases.enumerated()), id: \.element.id) { i, sound in
                        soundRow(sound)
                        if i < AthanSound.allCases.count - 1 { SettingsDivider(inset: 44) }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : Motion.smooth, value: wantAthan)
        .animation(reduceMotion ? nil : Motion.smooth, value: notifStatus)
    }

    /// صف مؤذّن بأسلوب AthanSoundPicker: الاختيار يُكتب فورًا، والاستماع لا يغيّر الاختيار.
    private func soundRow(_ sound: AthanSound) -> some View {
        let selected = store.athanSound == sound
        let isPlaying = preview.playing == sound

        // صفٌّ مضغوط (سطران بلا فراغ زائد) حتى تتّسع الأصوات الستة مع المفتاح والتلميح في شاشة واحدة.
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Button {
                    guard !selected else { return }
                    store.athanSound = sound
                    Haptics.tap(enabled: store.hapticsEnabled)
                    // الإشعارات المجدولة تحمل الصوت وقت جدولتها، فإن كان التنبيه مفعّلًا
                    // أعدنا الجدولة فورًا — كما يفعل AthanSoundPicker عبر onChange — حتى لا
                    // يصدح الأذان التالي بالصوت القديم لو خرج المستخدم بـ«تخطّي».
                    if store.athanAlerts { Task { await Reminders.rescheduleAll(store: store) } }
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(selected ? Theme.accent : Theme.inkFaint)   // hairline يكاد يختفي

                        VStack(alignment: .leading, spacing: 1) {
                            Text(sound.title)
                                .font(Theme.display(15, weight: selected ? .semibold : .regular))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(sound.detail)
                                .font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                                .multilineTextAlignment(.leading)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])

                // نغمة النظام لا ملفّ لها فلا زرّ استماع.
                if sound != .system {
                    Button { preview.toggle(sound) } label: {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(isPlaying ? athanTint : Theme.accent)
                            .frame(width: 40, height: 36)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPlaying ? loc("إيقاف الاستماع إلى %1$@", sound.title)
                                                  : loc("استمع إلى %1$@", sound.title))
                }
            }

            if isPlaying {
                Text(loc("يُشغَّل التسجيل الكامل — التنبيه يستخدم أوّل 30 ثانية"))
                    .font(Theme.display(11))
                    .foregroundStyle(athanTint)
                    .padding(.top, 6)
                    .padding(.leading, 28)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .animation(reduceMotion ? nil : Motion.snappy, value: isPlaying)
    }

    // MARK: ٥ — المظهر

    private var appearance: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text(loc("المظهر"))
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("اختر ما يريح عينك — ويمكنك تغييره متى شئت من الإعدادات."))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("خط الواجهة"), tint: Theme.accent(for: "dusk"))
                HStack(spacing: 10) {
                    ForEach(AppFont.allCases) { fontTile($0) }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(loc("خط الواجهة"))
                Text(loc("القرآن والأذكار والحديث تبقى بخط النسخ مهما اخترت هنا."))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("colorTheme"), tint: Theme.accent(for: "gold"))
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(AppTheme.allCases) { themeDot($0) }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(loc("colorTheme"))
            }

            backgroundSection

            iconSection

            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("lighting"))
                HStack(spacing: 10) {
                    ForEach(AppearanceMode.allCases) { modeTile($0) }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(loc("lighting"))
            }
        }
    }

    // MARK: النقش والأيقونة

    /// نقش الورق: يُختار من أول تشغيل كما يُختار اللون، فالخلفية نصف ما تراه العين.
    private var backgroundSection: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("خلفية التطبيق"), tint: Theme.accent(for: "sea"))
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(BackgroundPattern.allCases) { patternTile($0) }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("خلفية التطبيق"))
        }
    }

    private func patternTile(_ pattern: BackgroundPattern) -> some View {
        let on = store.backgroundPattern == pattern
        return Button {
            withAnimation(Motion.gentle) { store.backgroundPattern = pattern }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.canvas)
                    PaperMotif(tint: Theme.accent, pattern: pattern, intensity: 9)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                    if on {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.accent)
                            .background(Circle().fill(Theme.surface).padding(2))
                    }
                }
                .frame(width: 76, height: 60)
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(on ? Theme.accent : Theme.hairline.opacity(0.6), lineWidth: on ? 2.5 : 1))
                Text(pattern.title)
                    .font(Theme.display(12, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pattern.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// أيقونة التطبيق: إمّا أن تمشي مع الطابع المختار، وإمّا أن يخصّها باختيار.
    /// وتُطوى حيث يمنع النظام البدائل — خيارٌ لا يُنفَّذ خُلفٌ للوعد.
    @ViewBuilder private var iconSection: some View {
        if AppIconManager.supported {
            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("أيقونة التطبيق"), tint: Theme.accent(for: "dusk"))
                Picker("", selection: $iconMode) {
                    ForEach(AppIconMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(loc("أيقونة التطبيق"))

                if iconMode == .theme {
                    Text(loc("تلبس أيقونتك لون الطابع الذي اخترته — وتتبعه كلّما بدّلته."))
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(AppIconChoice.allCases) { iconChoiceTile($0) }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 7)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(loc("أيقونة التطبيق"))
                }
            }
            .animation(reduceMotion ? nil : Motion.smooth, value: iconMode)
        }
    }

    private func iconChoiceTile(_ choice: AppIconChoice) -> some View {
        let on = pickedIcon == choice
        let side: CGFloat = 54
        let corner = side * 0.22
        return Button {
            withAnimation(Motion.gentle) { pickedIcon = choice }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 6) {
                Group {
                    if let image = UIImage(named: choice.previewAsset) ?? UIImage(named: choice.assetName ?? "AppIcon") {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: corner, style: .continuous).fill(Theme.surfaceAlt)
                    }
                }
                .frame(width: side, height: side)
                .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 0.5))
                .overlay(RoundedRectangle(cornerRadius: corner + 5, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: 2.5)
                    .padding(-5)
                    .opacity(on ? 1 : 0))
                Text(choice.title)
                    .font(Theme.display(11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// بلاطة خط: العيّنة بالخط نفسه لا بخط الواجهة الحالي — هذا ما سيراه المستخدم إن اختاره.
    private func fontTile(_ font: AppFont) -> some View {
        let on = store.uiFont == font
        return Button {
            withAnimation(Motion.gentle) { store.uiFont = font }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 6) {
                Text("أثر")
                    .font(font.font(size: Theme.scaled(30), weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(font.title)
                    .font(font.font(size: Theme.scaled(13), weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.surfaceGradient)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(on ? Theme.accent : Theme.hairline.opacity(0.6), lineWidth: on ? 2.5 : 1))
            )
            .overlay(alignment: .topTrailing) {
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .padding(7)
                }
            }
            .shadow(color: on ? Theme.accent.opacity(0.22) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(font.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// كرة لون الطابع: ألوان الطابع نفسه لا الطابع الفعّال، حتى يرى المستخدم ما سيختاره.
    private func themeDot(_ theme: AppTheme) -> some View {
        let on = store.appTheme == theme
        let accent  = Color.adaptive(light: Color(hex: theme.accent.light),  dark: Color(hex: theme.accent.dark))
        let accent2 = Color.adaptive(light: Color(hex: theme.accent2.light), dark: Color(hex: theme.accent2.dark))
        let canvas  = Color.adaptive(light: Color(hex: theme.canvas.light),  dark: Color(hex: theme.canvas.dark))
        return Button {
            withAnimation(Motion.gentle) { store.appTheme = theme }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [accent, accent2],
                                             startPoint: .topTrailing, endPoint: .bottomLeading))
                        .frame(width: 44, height: 44)
                        .shadow(color: accent.opacity(0.35), radius: 4, y: 2)
                    if on {
                        // لون الورق لا الأبيض: بعض الطوابع لها لون فاتح في الوضع الداكن،
                        // فالأبيض عليه يختفي. الورق دائمًا نقيض اللون.
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(canvas)
                    }
                }
                .overlay(Circle().strokeBorder(on ? accent : .clear, lineWidth: 2).padding(-4))
                Text(theme.title)
                    .font(Theme.display(11, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? accent : Theme.inkSoft)
                    .lineLimit(1)
            }
            .frame(width: 62)
            .scaleEffect(on ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func modeTile(_ mode: AppearanceMode) -> some View {
        let on = store.appearance == mode
        return Button {
            withAnimation(Motion.smooth) { store.appearance = mode }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode == .system ? "circle.lefthalf.filled"
                                : mode == .light ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 17))
                Text(mode.title).font(Theme.display(12, weight: on ? .semibold : .regular))
            }
            .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(on ? .clear : Theme.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: الأزرار السفلية

    private var actions: some View {
        VStack(spacing: 10) {
            switch step {
            case .welcome:
                primary(loc("التالي")) { advance() }
            case .location:
                primary(loc("التالي")) { advance() }
                later { advance() }
            case .reminders:
                // بلا اختيار لا يوجد ما يُفعَّل، فيصدق الزر ويقول «التالي».
                primary(anySelected ? loc("فعّل التذكيرات") : loc("التالي"), busy: working) { enable() }
                later { advance() }
            case .athan:
                // الاختيار كُتب فورًا في الصفوف، فلا «تفعيل» هنا — «التالي» و«لاحقًا» كلاهما يُكمل.
                primary(loc("التالي")) { advance() }
                later { advance() }
            case .appearance:
                primary(loc("ابدأ باستخدام التطبيق")) { finish() }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 18)
        .padding(.top, 14)
        .readableWidth(520)
        .background(
            LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas, Theme.canvas],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func primary(_ title: String, busy: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if busy { ProgressView().tint(Theme.onAccent) }
                Text(title)
            }
            .font(Theme.display(16, weight: .semibold))
            // الزر الأساسي الموحّد: التدرّج باتجاه العربية والتوهّج نفسه في كل الشاشات.
            .gradientButton()
        }
        .pressable()
        .disabled(busy)
    }

    private func later(_ action: @escaping () -> Void) -> some View {
        Button(loc("later"), action: action)
            .font(Theme.display(14))
            .foregroundStyle(Theme.inkSoft)
            .frame(minWidth: 88, minHeight: 44)     // هدف لمس كامل لا سطر نص وحده
            .contentShape(Rectangle())
    }

    private var anySelected: Bool {
        wantAdhkar || wantAthan || wantQiyam || wantIstighfar || wantWird
    }

    // MARK: المنطق

    private func advance() {
        if step == .athan { commitAthan() }
        guard let next = Step(rawValue: step.rawValue + 1) else { finish(); return }
        withAnimation(reduceMotion ? nil : Motion.smooth) { step = next }
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    /// مغادرة خطوة الأذان بأي زرّ («التالي»، «لاحقًا»، «تخطّي»): المفتاح قد تبدّل بعد أن كتبته
    /// خطوة التذكيرات، فنثبّته ونعيد الجدولة إن تبدّل فقط — تبدّل الصوت أُعيدت جدولته لحظة
    /// اختياره. بلا طلب إذن جديد؛ الإذن شأن خطوة التذكيرات وحدها، ومن لم يمنحه بعد لا يُكتب
    /// له شيء (كما لو ضغط «لاحقًا» هناك). المخزن مفرد مشترك، فتُكمل المهمة بعد الإغلاق أيضًا.
    private func commitAthan() {
        Task {
            guard await Reminders.authorizationStatus() == .authorized else { return }
            guard store.athanAlerts != wantAthan else { return }
            store.athanAlerts = wantAthan
            await Reminders.rescheduleAll(store: store)
        }
    }

    private func enable() {
        guard anySelected else { advance(); return }
        working = true
        Task {
            let granted = await Reminders.requestAuthorization()
            guard granted else {
                working = false
                denied = true
                return
            }
            store.remindersEnabled  = wantAdhkar
            store.athanAlerts       = wantAthan
            store.qiyamAlert        = wantQiyam
            store.istighfarAlerts   = wantIstighfar
            store.wirdEnabled       = wantWird
            await Reminders.rescheduleAll(store: store)
            working = false
            Haptics.done(enabled: store.hapticsEnabled)
            advance()
        }
    }

    private func finish() {
        preview.stop()
        // «تخطّي» من خطوة الأذان يحترم ما قلبه المستخدم في المفتاح كما تفعل «لاحقًا».
        if step == .athan { commitAthan() }
        commitIcon()
        store.didOnboard = true
        // من لم يعرف إصدارًا قبل هذا لا يُعرض عليه «ما الجديد» يعدّد عليه جديدًا هو
        // عنده قديم: تُختم نسخته هنا، فلا يفاجئه الغطاء في فتحه الثاني.
        store.whatsNewShownVersion = WhatsNewView.version
        // من لم يعرف إصدارًا قبل هذا لا يُعرض عليه «ما الجديد» يعدّد عليه جديدًا
        // هو عنده قديم: تُختم نسخته هنا، فلا يفاجئه الغطاء في فتحه الثاني.
        store.whatsNewShownVersion = WhatsNewView.version
        dismiss()
    }

    /// تُلبَس الأيقونة مرّةً واحدة عند الخروج من الترحيب لا مع كل ضغطة، فتنبيه النظام
    /// «تم تغيير أيقونة التطبيق» يقع مرّةً بعد أن يفرغ المستخدم، لا في وجهه وهو يختار.
    /// ويُمهَل لحظة بعد انزياح الغطاء: تنبيهُ نظامٍ يُطلَق على شاشةٍ تُغادر قد يضيع.
    private func commitIcon() {
        // خطوةٌ تُتخطّى لا تترك أثرًا: من ضغط «تخطّي» قبل «المظهر» لم يرَ قسم الأيقونة
        // قطّ، فلا تُقلَب نيّتُه نيابةً عنه فتتبدّل أيقونتُه لاحقًا بلا أن يطلب.
        guard sawAppearance else { return }
        guard AppIconManager.supported else { return }
        store.appIconMode = iconMode
        let wanted = iconMode == .theme ? AppIconChoice.matching(store.appTheme) : pickedIcon
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            try? await AppIconManager.set(wanted)
        }
    }
}

// MARK: - ٢ — خطوة الموقع

/// تملك مزوّد الموقع طوال عمر الخطوة (لا داخل زرّ) حتى لا ينقطع التتبّع في منتصفه
/// مع إعادة رسم الشاشة عند تبدّل الخط أو الطابع.
private struct OnboardingLocationStep: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var location: LocationProvider
    let onManual: () -> Void

    init(store: AtharStore, onManual: @escaping () -> Void) {
        _location = StateObject(wrappedValue: LocationProvider(store: store))
        self.onManual = onManual
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                illustration
                Text(loc("حدّد موقعك"))
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("تُحسب المواقيت والقبلة على جهازك. قد تستخدم Apple موقعك للتعرّف على اسم المدينة"))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                Button {
                    location.request()
                    Haptics.tap(enabled: store.hapticsEnabled)
                } label: {
                    HStack(spacing: 8) {
                        if location.isResolving {
                            ProgressView().tint(Theme.onAccent)
                        } else {
                            Image(systemName: store.usesDeviceLocation ? "checkmark.circle.fill" : "location.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        Text(store.usesDeviceLocation ? loc("تم تحديد موقعك") : loc("السماح بالوصول للموقع"))
                    }
                    .font(Theme.display(16, weight: .semibold))
                    .gradientButton()
                }
                .pressable()
                .disabled(location.isResolving)

                Button { onManual() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .semibold))
                        Text(loc("التحديد يدويًا"))
                    }
                    .font(Theme.display(15, weight: .semibold))
                    .softButton()
                }
                .pressable()
            }

            SettingsCard {
                SettingsRow(icon: "mappin.and.ellipse", tint: Theme.accent(for: "calm"),
                            title: loc("الموقع الحالي: %1$@", store.placeName),
                            subtitle: placeDetail)

                if location.failed {
                    SettingsDivider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc("تعذّر تحديد الموقع. تأكد من السماح للتطبيق بالوصول للموقع، أو اختر مدينتك يدويًا."))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        // الرفض الصريح لا يُرفع إلا من إعدادات النظام، فنفتحها كما في مسار الإشعارات.
                        if location.status == .denied {
                            Button(loc("فتح الإعدادات")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(Theme.display(13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    /// من أين جاء الاسم المعروض: موقع الجهاز، مدينة اختارها، أو الافتراضي (مكة) الذي لم يُبدَّل بعد.
    private var placeDetail: String {
        if store.usesDeviceLocation { return loc("حسب موقع جهازك") }
        if store.cityId != nil { return loc("مدينة اخترتها يدويًا") }
        return loc("الافتراضي حتى تحدّد موقعك")
    }

    /// تركيب دوائر بسيط بدل صورة: يتبع الطابع ويبقى واضحًا في الوضعين.
    private var illustration: some View {
        ZStack {
            Circle().stroke(Theme.accent.opacity(0.10), lineWidth: 1).frame(width: 184, height: 184)
            Circle().stroke(Theme.accent.opacity(0.22), lineWidth: 1).frame(width: 156, height: 156)
            Circle().fill(Theme.accentSoft).frame(width: 128, height: 128)
            Image(systemName: "location.fill")
                .font(.system(size: 52, weight: .medium))
                .foregroundStyle(Theme.accentGradient)
        }
        .frame(height: 190)
        .accessibilityHidden(true)
    }
}

// MARK: - ورقة اختيار المدينة

/// مضيف صغير يملك مزوّد الموقع طوال عمر الورقة: LocationPickerView يستقبله
/// كـ@ObservedObject أي أنه لا يملكه، فلو أُنشئ داخل مغلِّف الورقة لضاع مع كل
/// إعادة رسم وانقطع تتبّع الموقع في منتصفه.
private struct OnboardingLocationHost: View {
    @StateObject private var location: LocationProvider
    /// طلب موقع الجهاز تلقائيًا عند الفتح. صار الافتراضي «لا»: الورقة تُفتح من زر
    /// «التحديد يدويًا»، فلا نفاجئ من اختار اليدوي بطلب إذن — وزر الموقع في الورقة يبقى له.
    private let autoRequest: Bool

    init(store: AtharStore, autoRequest: Bool = false) {
        _location = StateObject(wrappedValue: LocationProvider(store: store))
        self.autoRequest = autoRequest
    }

    var body: some View {
        LocationPickerView(location: location)
            .onAppear { if autoRequest, location.status == .notDetermined { location.request() } }
    }
}
