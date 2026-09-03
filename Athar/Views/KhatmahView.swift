import SwiftUI

/// تحدي الختمة: يختار المستخدم مدة الختمة أو مقدار اليوم، والتطبيق يحسب
/// الباقي ويوزّع ورد كل يوم، ويريه أهو متقدّم أم متأخّر عن خطته.
///
/// الهوية اللونية: أخضر ← ذهبي. الأخضر للتقدّم والخطة، والذهبي لِذُرى الإنجاز
/// (حلقة الإتمام والهالة). الزخرفة تحت النص لا تنافسه أبدًا.
struct KhatmahView: View {
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent, secondary: Theme.gold)
            ScrollView {
                Group {
                    if store.khatmahActive { active } else { setup }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("الختمة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        // تثبيت أساس «ورد اليوم» هنا لا في جسم الواجهة: الكتابة في التخزين
        // أثناء الرسم أثر جانبي يعيد الرسم بلا نهاية.
        .task { store.refreshKhatmahDayBase() }
    }

    // MARK: الإعداد

    @State private var days = 30
    @State private var mode: KhatmahMode = .open

    private let dayOptions = [7, 10, 15, 30, 60]

    private var setup: some View {
        VStack(spacing: 24) {
            // مقدّمة: نجمة خضراء باهتة خلف الأيقونة الذهبية
            VStack(spacing: 10) {
                ZStack {
                    EightPointStar()
                        .fill(Theme.accent.opacity(0.04))
                        .frame(width: 96, height: 96)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.goldGradient)
                }
                Text(loc("ابدأ ختمتك"))
                    .font(Theme.display(24, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("حدّد مدة الختمة، ونحسب لك ورد كل يوم\nونتابع معك أين وصلت."))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)
            .appearStagger(0)

            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("أختمها في"))
                HStack(spacing: 8) {
                    ForEach(dayOptions, id: \.self) { d in
                        let on = days == d
                        Button {
                            days = d
                            Haptics.tap(enabled: store.hapticsEnabled)
                        } label: {
                            VStack(spacing: 2) {
                                Text(d.counterText)
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                // تمييز العدد: ٧ و١٠ «أيام»، و١٥ و٣٠ و٦٠ «يومًا» — كما في planSummary تحتها.
                                Text(loc((3...10).contains(d) ? "أيام" : "يومًا")).font(Theme.display(11))
                            }
                            .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(dayChipBackground(on))
                            .scaleEffect(on ? 1.03 : 1)
                        }
                        .pressable()
                        .accessibilityAddTraits(on ? .isSelected : [])
                        .animation(Motion.press, value: days)
                    }
                }
                Text(planSummary)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity)
            }
            .appearStagger(1)

            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("توزيع الورد"))
                SettingsCard {
                    ForEach(Array(KhatmahMode.allCases.enumerated()), id: \.element.id) { i, m in
                        Button {
                            mode = m
                            Haptics.tap(enabled: store.hapticsEnabled)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode == m ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(mode == m ? Theme.accent : Theme.hairline)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.title).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                                    Text(m.detail).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(mode == m ? .isSelected : [])
                        if i < KhatmahMode.allCases.count - 1 { SettingsDivider() }
                    }
                }
            }
            .appearStagger(2)

            Button {
                store.startKhatmah(days: days, mode: mode)
                Haptics.done(enabled: store.hapticsEnabled)
            } label: {
                Text(loc("ابدأ التحدي"))
                    .font(Theme.display(17, weight: .semibold))
                    .gradientButton(Theme.gradient(for: "green"), glow: Theme.accent)
            }
            .pressable()
            .appearStagger(3)
        }
    }

    /// خلفية رقاقة اليوم: المختار تعبئة خضراء متدرّجة بظلّ ملوّن ونبض؛ غير المختار
    /// سطح ثانوي بحدّ شعري.
    @ViewBuilder
    private func dayChipBackground(_ on: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        if on {
            shape.fill(Theme.accentGradient)
                .shadow(color: Theme.accent.opacity(0.25), radius: 9, y: 5)
        } else {
            shape.fill(Theme.surfaceAlt)
                .overlay(shape.strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
        }
    }

    /// تمييز العدد في العربية: الواحد بلا عدد، والاثنان مثنّى، ومن ٣ إلى ١٠
    /// جمع قلّة (أجزاء). ولذلك لا يصحّ «٤ جزء» ولا «٢ جزء».
    private var planSummary: String {
        let per = Int((Double(Quran.pageCount) / Double(days)).rounded(.up))
        let juz = Double(30) / Double(days)
        let n = Int(juz.rounded())
        let juzText = juz < 1 ? loc("نحو نصف جزء")
                    : n == 1 ? loc("جزء")
                    : n == 2 ? loc("جزءان")
                    : loc("%1$@ أجزاء", n.counterText)
        return loc("%1$@ صفحة تقريبًا كل يوم — %2$@ يوميًّا", per.counterText, juzText)
    }

    // MARK: التحدي النشط

    private var active: some View {
        VStack(spacing: 22) {
            ringSection.appearStagger(0)
            // عند الإتمام لا معنى لبطاقة ورد اليوم ولا لأزرار العدّ: نطاقها
            // يصير ٦٠٤–٦٠٤، والضغط عليها لا يغيّر شيئًا ويكرّر هزّة الإتمام.
            if isComplete {
                completionCard.appearStagger(1)
            } else {
                statusLine.appearStagger(1)
                todayCard.appearStagger(2)
                if !store.khatmahMode.slotNames.isEmpty { slots.appearStagger(3) }
                actions.appearStagger(4)
            }
            cancelButton.appearStagger(5)
        }
    }

    private var progress: Double { Double(store.khatmahPagesDone) / Double(Quran.pageCount) }
    private var isComplete: Bool { store.khatmahPagesDone >= Quran.pageCount }

    /// أرقام «الجوهرة»: تعبئة خضراء متدرّجة، وتتحوّل ذهبية عند الإتمام.
    private var percentJewel: LinearGradient {
        isComplete
            ? Theme.goldGradient
            : LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .top, endPoint: .bottom)
    }

    private var ringSection: some View {
        ZStack {
            // هالة الاحتفاء الذهبية عند ختم القرآن — ذروة الإنجاز فقط
            if isComplete {
                CelebrationHalo(tint: Theme.gold)
                    .frame(width: 240, height: 240)
            }
            ZStack {
                KhatmahRing(progress: progress, lineWidth: 13, glow: true,
                            accent: Theme.accent, gold: Theme.gold)
                VStack(spacing: 3) {
                    Text("\(Int((progress * 100).rounded()).counterText)٪")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(percentJewel)
                        .contentTransition(.numericText())
                    Text(loc("%1$@ من %2$@ صفحة", store.khatmahPagesDone.counterText, Quran.pageCount.counterText))
                        .font(Theme.display(12)).foregroundStyle(Theme.inkFaint)
                    Text(loc("اليوم %1$@ من %2$@", store.khatmahDayIndex.counterText, store.khatmahTotalDays.counterText))
                        .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(width: 200, height: 200)
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private var statusLine: some View {
        let d = store.khatmahDelta
        // تمييز العدد: صفحة واحدة، صفحتان، ثم جمع القلّة (٣–١٠ صفحات)،
        // ثم المفرد المنصوب (١١ فأكثر صفحة).
        let n = abs(d)
        let byPages = n == 1 ? loc("بصفحة واحدة")
                    : n == 2 ? loc("بصفحتين")
                    : n <= 10 ? loc("بـ%1$@ صفحات", n.counterText)
                    : loc("بـ%1$@ صفحة", n.counterText)
        Group {
            if d >= 0 {
                Label(d == 0 ? loc("على الخطة تمامًا") : loc("متقدّم %1$@ — ما شاء الله", byPages),
                      systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Label(loc("متأخّر %1$@ — عوّض ما فاتك على مهل", byPages),
                      systemImage: "arrow.counterclockwise")
                    .foregroundStyle(Theme.accent(for: "gold"))
            }
        }
        .font(Theme.display(13, weight: .semibold))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill((d >= 0 ? Theme.accent : Theme.gold).opacity(0.12)))
    }

    // MARK: ورد اليوم — البطاقة البطلة

    /// نافذة ورد اليوم: من أساس اليوم المحفوظ — ما كان مقروءًا لحظة دخول
    /// اليوم — إلى نهاية النطاق المعروض في العنوان. الأساس ثابت لا يتحرّك
    /// مع كل صفحة تُقرأ، فلا يبقى شريط المتأخّر صفرًا، ولا تتبدّل حدود
    /// المواقيت تحت يد القارئ. مصدر واحد لبطاقة اليوم ولتوزيعه حتى لا يفترقا.
    private var wardWindow: (base: Int, upper: Int) {
        let base = store.khatmahDayBasePages
        return (base, max(base + 1, store.khatmahTodayRange.upperBound))
    }

    private var todayCard: some View {
        let range = store.khatmahTodayRange
        let startRef = Quran.firstAyah(ofPage: range.lowerBound)
        let surahName = Quran.surah(startRef.surah)?.name ?? ""
        let juz = Quran.juz(of: startRef)
        let window = wardWindow
        let wardTotal = max(1, window.upper - window.base)
        let wardDone = min(wardTotal, max(0, store.khatmahPagesDone - window.base))
        let wardFrac = Double(wardDone) / Double(wardTotal)
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)

        return VStack(alignment: .leading, spacing: 14) {
            // العنوان + شارة الجزء الذهبية
            HStack {
                Text(loc("ورد اليوم"))
                    .font(Theme.display(13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(loc("الجزء %1$@", juz.counterText))
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(Theme.accent(for: "gold"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent(for: "gold").opacity(0.14)))
            }

            // الأرقام الكبيرة المدوّرة لنطاق الصفحات
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(loc("صفحة"))
                    .font(Theme.display(14, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                Text(range.lowerBound.counterText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(percentJewel)
                    .contentTransition(.numericText())
                Text("–")
                    .font(.system(size: 26, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.inkFaint)
                Text(range.upperBound.counterText)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(percentJewel)
                    .contentTransition(.numericText())
            }

            Text(loc("يبدأ من سورة %1$@", surahName))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkSoft)

            // شريط رفيع لتقدّم ورد اليوم
            VStack(alignment: .leading, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.12))
                        Capsule().fill(Theme.gradient(for: "green"))
                            .frame(width: max(6, geo.size.width * wardFrac))
                    }
                }
                .frame(height: 6)
                .animation(Motion.smooth, value: wardFrac)

                Text(loc("قرأت %1$@ من %2$@ في ورد اليوم", wardDone.counterText, wardTotal.counterText))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.top, 2)

            NavigationLink {
                SurahReaderView(surahId: startRef.surah, scrollTo: startRef)
            } label: {
                Label(loc("ابدأ القراءة من موضعك"), systemImage: "book.pages.fill")
                    .font(Theme.display(14, weight: .semibold))
                    .gradientButton(Theme.gradient(for: "green"), glow: Theme.accent)
            }
            .pressable()
            .padding(.top, 2)
        }
        .padding(Theme.Space.xl)
        .background(heroBackground(shape))
    }

    /// خلفية البطاقة البطلة: سطح البطاقة الموحّد (عمق .e2) + غسالة خضراء قطرية
    /// خفيفة (٠٫٠٥) + نجمة ثمانية باهتة في الزاوية (٠٫٠٣) مقصوصة داخل الحواف.
    private func heroBackground(_ shape: RoundedRectangle) -> some View {
        CardSurface(radius: Theme.Radius.xl, elevation: .e2)
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [Theme.accent.opacity(0.05), .clear],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                    EightPointStar()
                        .fill(Theme.accent.opacity(0.03))
                        .frame(width: 150, height: 150)
                        .offset(x: -36, y: 40)
                }
                .clipShape(shape)
                .allowsHitTesting(false)
            }
    }

    private var slots: some View {
        // يُقسَم ورد اليوم كاملًا لا ما تبقّى منه: لو قُسم الباقي لتبدّلت
        // حدود الفجر والظهر مع كل صفحة يسجّلها القارئ.
        let window = wardWindow
        let names = store.khatmahMode.slotNames
        let lower = window.base + 1
        let total = max(1, window.upper - lower + 1)
        let per = max(1, Int((Double(total) / Double(max(1, names.count))).rounded(.up)))
        return VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("توزيع اليوم"))
            SettingsCard {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    let from = lower + i * per
                    let to = min(window.upper, from + per - 1)
                    if from <= window.upper {
                        HStack {
                            Text(name).font(Theme.display(14, weight: .medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(loc("ص %1$@–%2$@", from.counterText, to.counterText))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Theme.inkSoft).monospacedDigit()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        if i < names.count - 1 { SettingsDivider() }
                    }
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                store.khatmahPagesDone += 1
                Haptics.step(enabled: store.hapticsEnabled)
                if store.khatmahPagesDone == Quran.pageCount {
                    Haptics.done(enabled: store.hapticsEnabled)
                }
            } label: {
                Label(loc("قرأت صفحة"), systemImage: "plus")
                    .font(Theme.display(15, weight: .semibold))
                    .gradientButton(Theme.gradient(for: "green"), glow: Theme.accent, radius: Theme.Radius.sm)
            }
            .pressable()

            Button {
                store.khatmahPagesDone = store.khatmahTodayRange.upperBound
                Haptics.done(enabled: store.hapticsEnabled)
            } label: {
                Text(loc("أتممت الورد"))
                    .font(Theme.display(15, weight: .semibold))
                    .softButton(Theme.accent, radius: Theme.Radius.sm)
            }
            .pressable()
        }
    }

    /// بطاقة الإتمام: تحلّ محلّ ورد اليوم والأزرار عند بلوغ ٦٠٤، وتفتح باب
    /// ختمة جديدة حتى لا يكون المخرج الوحيد هو حذف الختمة.
    private var completionCard: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)

        return VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.goldGradient)
            Text(loc("تمّت الختمة — تقبّل الله"))
                .font(Theme.display(19, weight: .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
            Text(loc("ختمتَ المصحف كاملًا. ابدأ ختمة جديدة متى شئت."))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            Button {
                store.startKhatmah(days: store.khatmahTotalDays, mode: store.khatmahMode)
                Haptics.done(enabled: store.hapticsEnabled)
            } label: {
                Text(loc("ابدأ ختمة جديدة"))
                    .font(Theme.display(15, weight: .semibold))
                    .gradientButton(Theme.gradient(for: "green"), glow: Theme.accent)
            }
            .pressable()
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Space.xl)
        .background(heroBackground(shape))
    }

    @State private var confirmEnd = false

    /// «إنهاء التحدي» يمحو الصفحات المقروءة أيضًا ولا يمكن استرجاعها،
    /// فيُستأذن قبله كما في «تصفير كل الإحصائيات».
    private var cancelButton: some View {
        Button(loc("إنهاء التحدي")) { confirmEnd = true }
            .font(Theme.display(13))
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, 4)
            .confirmationDialog(loc("إنهاء التحدي؟"), isPresented: $confirmEnd, titleVisibility: .visible) {
                Button(loc("إنهاء وحذف التقدّم"), role: .destructive) {
                    store.cancelKhatmah()
                    Haptics.tap(enabled: store.hapticsEnabled)
                }
                Button(loc("cancel"), role: .cancel) {}
            } message: {
                Text(loc("سيُحذف تقدّمك في الختمة ولا يمكن استرجاعه."))
            }
    }
}

// MARK: - حلقة الختمة (أخضر ← ذهبي)

/// حلقة تقدّم بهوية الشاشة: قوس بتدرّج زاويّ من الأخضر إلى الذهبي، مسار خافت،
/// ثلاثون علامة (أجزاء المصحف)، وتوهّج يشتدّ قرب الإتمام. مخصّصة لهذه الشاشة
/// لأن التدرّج ثنائي النغمة (أخضر←ذهبي) لا توفّره الحلقة المشتركة.
private struct KhatmahRing: View {
    var progress: Double
    var lineWidth: CGFloat = 13
    var glow: Bool = true
    // يُقرأ لونا الطابع في الأب ويُمرَّران قيمتين: بنية الحلقة قيم بسيطة، فلو قرأت
    // Theme.* ساكنةً في جسمها لتخطّاها SwiftUI عند تبدّل الطابع وبقيت بلونها القديم.
    var accent: Color = Theme.accent
    var gold: Color = Theme.gold

    private var p: Double { max(0.001, min(1, progress)) }

    private var sweep: AngularGradient {
        AngularGradient(colors: [accent, gold, accent],
                        center: .center, angle: .degrees(-90))
    }

    var body: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.16), lineWidth: lineWidth)

            // ثلاثون علامة خافتة حول المسار — أجزاء المصحف
            ForEach(0..<30, id: \.self) { i in
                Capsule()
                    .fill(accent.opacity(0.22))
                    .frame(width: lineWidth * 0.14, height: lineWidth * 0.5)
                    .offset(y: -0.5)
                    .rotationEffect(.degrees(Double(i) / 30 * 360))
            }
            .padding(lineWidth / 2)

            let arc = Circle()
                .trim(from: 0, to: p)
                .stroke(sweep, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if glow {
                arc.blur(radius: 7).opacity(0.25 + 0.5 * p)
            }
            arc.animation(Motion.smooth, value: progress)
        }
    }
}
