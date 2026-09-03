import SwiftUI

/// تظهر مرة واحدة عند أول تشغيل: تعرض التذكيرات وتطلب الإذن مرة واحدة.
/// كل خيار قابل للإطفاء لاحقًا من الإعدادات — ولا شيء يُفعّل دون علم المستخدم.
struct OnboardingView: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    @State private var wantAdhkar = true
    @State private var wantAthan = true
    @State private var wantQiyam = false
    @State private var wantIstighfar = false
    @State private var wantWird = false
    @State private var showCityPicker = false
    @State private var working = false
    @State private var denied = false
    @State private var breathing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                VStack(spacing: 26) {
                    header
                    options
                    note
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 24)
                .padding(.bottom, 140)
                .readableWidth(520)
            }
            .scrollIndicators(.hidden)

            VStack {
                Spacer()
                actions
            }
        }
        .alert(loc("الإشعارات موقوفة"), isPresented: $denied) {
            Button(loc("فتح الإعدادات")) {
                if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
            }
            Button(loc("later"), role: .cancel) { finish() }
        } message: {
            Text(loc("لتصلك التذكيرات، اسمح للتطبيق بالإشعارات من إعدادات الجهاز. يمكنك تفعيلها لاحقًا من إعدادات أثر."))
        }
        .sheet(isPresented: $showCityPicker) {
            // الأوراق لا ترث اتجاه الكتابة من جذر التطبيق، فنثبّته صراحةً كما في الإعدادات.
            OnboardingLocationHost(store: store)
                .environment(\.layoutDirection,
                             AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
    }

    // MARK: الترويسة

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                // نجمة ثمانية ذهبية خافتة خلف القلب — زخرفة لا تنافس
                EightPointStar()
                    .fill(Theme.goldGradient)
                    .opacity(0.15)
                    .frame(width: 44, height: 44)

                // حلقات ذهبية متراكزة تتنفّس بهدوء (تحترم «تقليل الحركة»)
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Theme.gold.opacity(0.35 - Double(i) * 0.09), lineWidth: 1.5)
                            .frame(width: 54 + CGFloat(i) * 26, height: 54 + CGFloat(i) * 26)
                    }
                }
                .scaleEffect(breathing ? 1.06 : 1)

                // القلب — نقطة ذهبية بتوهّج دافئ
                Circle().fill(Theme.gold.opacity(0.9))
                    .frame(width: 14, height: 14)
                    .shadow(color: Theme.gold.opacity(0.55), radius: 10)
            }
            .frame(height: 110)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }

            Text(loc("لا يفوتك ذِكر"))
                .font(Theme.display(27, weight: .bold))
                .foregroundStyle(Theme.ink)

            Text(loc("اختر ما تحب أن نُذكّرك به، ونتكفّل بالباقي.\nكل شيء يعمل على جهازك، ولا نجمع عنك شيئًا."))
                .font(Theme.display(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
    }

    // MARK: الخيارات

    private var options: some View {
        SettingsCard {
            row("sunrise.fill", Theme.accent(for: "dawn"), loc("أذكار الصباح والمساء"),
                loc("تذكير في الوقت الذي تختاره"), $wantAdhkar)
            SettingsDivider()
            row("bell.and.waves.left.and.right.fill", Theme.accent, loc("أوقات الصلاة"),
                loc("تنبيه عند دخول كل وقت"), $wantAthan)
            SettingsDivider()
            // تنبيه الأذان مفعّل افتراضيًا، ومواقيته تُحسب لمكة ما لم يُختر موقع؛
            // فيرى المستخدم المدينة هنا ويبدّلها قبل «فعّل التذكيرات» لا بعد أن تصله في غير وقتها.
            Button { showCityPicker = true } label: {
                SettingsRow(icon: "location.fill", tint: Theme.accent(for: "calm"),
                            title: loc("الموقع: %1$@", store.placeName)) {
                    HStack(spacing: 4) {
                        Text(loc("تغيير"))
                            .font(Theme.display(14, weight: .medium))
                            .foregroundStyle(Theme.accent)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
            .buttonStyle(.plain)
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
    }

    private func row(_ icon: String, _ tint: Color, _ title: String,
                     _ sub: String, _ on: Binding<Bool>) -> some View {
        SettingsRow(icon: icon, tint: tint, title: title, subtitle: sub) {
            // المفتاح بلا عنوان مرئي، فيقرأ VoiceOver اسم الصف بدل «مفتاح» فقط.
            Toggle("", isOn: on).labelsHidden()
                .accessibilityLabel(title)
        }
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 2)
            Text(loc("لا إعلانات، ولا اشتراكات، ولا حسابات. ولا يجمع التطبيق أي بيانات عنك."))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous).fill(Theme.surfaceAlt))
    }

    // MARK: الأزرار

    private var actions: some View {
        VStack(spacing: 10) {
            Button { enable() } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(Theme.onAccent) }
                    Text(anySelected ? loc("فعّل التذكيرات") : loc("ابدأ"))
                }
                .font(Theme.display(16, weight: .semibold))
                // الزر الأساسي الموحّد: التدرّج باتجاه العربية والتوهّج نفسه في كل الشاشات.
                .gradientButton()
            }
            .pressable()
            .disabled(working)

            Button(loc("later")) { finish() }
                .font(Theme.display(14))
                .foregroundStyle(Theme.inkSoft)
                .frame(minWidth: 88, minHeight: 44)     // هدف لمس كامل لا سطر نص وحده
                .contentShape(Rectangle())
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 18)
        .padding(.top, 14)
        .background(
            LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas, Theme.canvas],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private var anySelected: Bool {
        wantAdhkar || wantAthan || wantQiyam || wantIstighfar || wantWird
    }

    // MARK: المنطق

    private func enable() {
        guard anySelected else { finish(); return }
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
            finish()
        }
    }

    private func finish() {
        store.didOnboard = true
        dismiss()
    }
}

/// مضيف صغير يملك مزوّد الموقع طوال عمر الورقة: LocationPickerView يستقبله
/// كـ@ObservedObject أي أنه لا يملكه، فلو أُنشئ داخل مغلِّف الورقة لضاع مع كل
/// إعادة رسم وانقطع تتبّع الموقع في منتصفه.
private struct OnboardingLocationHost: View {
    @StateObject private var location: LocationProvider

    init(store: AtharStore) {
        _location = StateObject(wrappedValue: LocationProvider(store: store))
    }

    var body: some View {
        LocationPickerView(location: location)
    }
}
