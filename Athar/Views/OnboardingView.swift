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
                .padding(.horizontal, 22)
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
            Toggle("", isOn: on).labelsHidden()
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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceAlt))
    }

    // MARK: الأزرار

    private var actions: some View {
        VStack(spacing: 10) {
            Button { enable() } label: {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(Theme.onAccent) }
                    Text(anySelected ? loc("فعّل التذكيرات") : loc("ابدأ"))
                        .font(Theme.display(17, weight: .semibold))
                }
                .foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.accent, Theme.accent2],
                                             startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: Theme.accent.opacity(0.35), radius: 12, y: 6)
            }
            .pressable()
            .disabled(working)

            Button(loc("later")) { finish() }
                .font(Theme.display(14))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 22)
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
