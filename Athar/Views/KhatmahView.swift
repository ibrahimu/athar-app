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
                                Text(loc("يوم")).font(Theme.display(10))
                            }
                            .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(dayChipBackground(on))
                            .scaleEffect(on ? 1.03 : 1)
                        }
                        .pressable()
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

    private var planSummary: String {
        let per = Int((Double(Quran.pageCount) / Double(days)).rounded(.up))
        let juz = Double(30) / Double(days)
        let juzText = juz >= 1 ? "\(Int(juz.rounded()).counterText) جزء" : loc("نحو نصف جزء")
        return "\(per.counterText) صفحة تقريبًا كل يوم — \(juzText) يوميًّا"
    }

    // MARK: التحدي النشط

    private var active: some View {
        VStack(spacing: 22) {
            ringSection.appearStagger(0)
            statusLine.appearStagger(1)
            todayCard.appearStagger(2)
            if !store.khatmahMode.slotNames.isEmpty { slots.appearStagger(3) }
            actions.appearStagger(4)
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
                KhatmahRing(progress: progress, lineWidth: 13, glow: true)
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
        Group {
            if d >= 0 {
                Label(d == 0 ? loc("على الخطة تمامًا") : loc("متقدّم بـ%1$@ صفحة — ما شاء الله", d.counterText),
                      systemImage: "checkmark.seal.fill")
                    .foregroundStyle(Theme.accent)
            } else {
                Label(loc("متأخّر بـ%1$@ صفحة — عوّضها على مهل", (-d).counterText),
                      systemImage: "arrow.counterclockwise")
                    .foregroundStyle(Theme.gold)
            }
        }
        .font(Theme.display(13, weight: .semibold))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill((d >= 0 ? Theme.accent : Theme.gold).opacity(0.12)))
    }

    // MARK: ورد اليوم — البطاقة البطلة

    private var todayCard: some View {
        let range = store.khatmahTodayRange
        let startRef = Quran.firstAyah(ofPage: range.lowerBound)
        let surahName = Quran.surah(startRef.surah)?.name ?? ""
        let juz = Quran.juz(of: startRef)
        let wardTotal = max(1, range.count)
        let wardDone = min(wardTotal, max(0, store.khatmahPagesDone - (range.lowerBound - 1)))
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
                    .foregroundStyle(Theme.gold)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Theme.gold.opacity(0.14)))
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
        let range = store.khatmahTodayRange
        let names = store.khatmahMode.slotNames
        let total = range.count
        let per = Int((Double(total) / Double(names.count)).rounded(.up))
        return VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("توزيع اليوم"))
            SettingsCard {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    let from = range.lowerBound + i * per
                    let to = min(range.upperBound, from + per - 1)
                    if from <= range.upperBound {
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

    private var cancelButton: some View {
        Button(loc("إنهاء التحدي")) {
            store.cancelKhatmah()
            Haptics.tap(enabled: store.hapticsEnabled)
        }
        .font(Theme.display(13))
        .foregroundStyle(Theme.inkFaint)
        .padding(.top, 4)
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

    private var p: Double { max(0.001, min(1, progress)) }

    private var sweep: AngularGradient {
        AngularGradient(colors: [Theme.accent, Theme.gold, Theme.accent],
                        center: .center, angle: .degrees(-90))
    }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.accent.opacity(0.16), lineWidth: lineWidth)

            // ثلاثون علامة خافتة حول المسار — أجزاء المصحف
            ForEach(0..<30, id: \.self) { i in
                Capsule()
                    .fill(Theme.accent.opacity(0.22))
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
