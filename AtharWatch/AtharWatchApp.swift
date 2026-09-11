import SwiftUI
import WatchKit

@main
struct AtharWatchApp: App {
    @StateObject private var store = AtharStore.shared
    init() { WatchSyncReceiver.shared.activate() }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .environment(\.layoutDirection, .rightToLeft)
                // أرقام لاتينية في كل الساعة كبقية التطبيق.
                .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
        }
    }
}

/// ثلاث صفحات رأسية: الصلاة القادمة، المسبحة، ذكر اليوم — ولون الخلفية يتبع «لون الويدجت»
/// الذي اختاره في الهاتف، وإلا فوقتَ اليوم.
struct WatchRootView: View {
    var body: some View {
        // كل صفحة في مكدّسها: خلفية containerBackground لا تُرسم إلا داخل NavigationStack.
        TabView {
            NavigationStack { WatchPrayerPage() }
            NavigationStack { WatchTasbihPage() }
            NavigationStack { WatchDhikrPage() }
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - أدوات مشتركة

private extension View {
    /// أرقام لاتينية في العدّ التنازلي كبقية التطبيق.
    func latinDigits() -> some View { environment(\.locale, Locale(identifier: "ar_SA@numbers=latn")) }
}

/// تمييز العدد لـ«مرة»: مرتين، 3–10 مرات، وما فوقها «مرة».
private func timesText(_ n: Int) -> String {
    switch n {
    case 2: return "مرتين"
    case 3...10: return "\(n) مرات"
    default: return "\(n) مرة"
    }
}

private func clock(_ d: Date, tz: TimeZone) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "ar_SA@numbers=latn")
    f.timeZone = tz
    f.dateFormat = "h:mm"
    return f.string(from: d)
}

// MARK: - الصلاة القادمة

struct WatchPrayerPage: View {
    @EnvironmentObject private var store: AtharStore
    @State private var now = Date()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var times: PrayerTimes? { store.prayerTimes(for: now) }
    private var moment: AtharStyle.Moment { .resolved(at: now, times: times) }

    /// الصلاة القادمة والتي قبلها — لحساب حلقة التقدّم بينهما.
    private var window: (prev: Date, next: Date, prayer: Prayer)? {
        guard let t = times else { return nil }
        let ordered = t.ordered.filter { $0.prayer.isPrayer }
        if let i = ordered.firstIndex(where: { $0.date > now }) {
            let prev = i > 0 ? ordered[i - 1].date : (Calendar.current.date(byAdding: .day, value: -1, to: now).flatMap { store.prayerTimes(for: $0)?[.isha] } ?? ordered[i].date.addingTimeInterval(-5 * 3600))
            return (prev, ordered[i].date, ordered[i].prayer)
        }
        guard let tm = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let f = store.prayerTimes(for: tm)?[.fajr], let isha = t[.isha] else { return nil }
        return (isha, f, .fajr)
    }

    private var progress: Double {
        guard let w = window else { return 0 }
        let total = w.next.timeIntervalSince(w.prev); guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(w.prev) / total))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let w = window {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.12), lineWidth: 9)
                        Circle().trim(from: 0, to: progress)
                            .stroke(moment.tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .environment(\.layoutDirection, .leftToRight)
                        VStack(spacing: 2) {
                            Image(systemName: w.prayer.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(moment.tint)
                            Text(w.prayer.title)
                                .font(.custom("NotoNaskhArabic-Bold", size: 24))
                                .foregroundStyle(moment.ink)
                            Text(timerInterval: now...w.next, countsDown: true)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(moment.ink.opacity(0.9))
                                .latinDigits()
                            Text(clock(w.next, tz: store.placeTimeZone))
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(moment.inkSoft)
                        }
                    }
                    .frame(width: 146, height: 146)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

                    Text(store.placeName)
                        .font(.custom("NotoNaskhArabic-Regular", size: 13)).foregroundStyle(moment.inkSoft)
                        .padding(.bottom, 10)
                }

                if let t = times {
                    VStack(spacing: 4) {
                        ForEach(Prayer.allCases.filter(\.isPrayer)) { p in
                            let isNext = window?.prayer == p
                            HStack(spacing: 8) {
                                Image(systemName: p.icon)
                                    .font(.system(size: 12))
                                    .foregroundStyle(isNext ? moment.tint : moment.inkSoft)
                                    .frame(width: 18)
                                Text(p.title)
                                    .font(.custom(isNext ? "NotoNaskhArabic-Bold" : "NotoNaskhArabic-Regular", size: 16))
                                    .foregroundStyle(isNext ? moment.ink : moment.inkSoft)
                                Spacer()
                                Text(t[p].map { clock($0, tz: store.placeTimeZone) } ?? "—")
                                    .font(.system(size: 15, weight: isNext ? .bold : .regular, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(isNext ? moment.tint : moment.inkSoft)
                            }
                            .padding(.vertical, 8).padding(.horizontal, 12)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isNext ? Color.white.opacity(0.10) : .clear))
                        }
                    }
                    .padding(.top, 2)
                } else {
                    Text("افتح «أثر» في الآيفون مرة ليصل موقعك إلى الساعة")
                        .font(.system(size: 13)).foregroundStyle(moment.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .containerBackground(LinearGradient(colors: moment.gradient, startPoint: .top, endPoint: .bottom), for: .navigation)
        .onReceive(ticker) { now = $0 }
    }
}

// MARK: - المسبحة

struct WatchTasbihPage: View {
    @EnvironmentObject private var store: AtharStore
    @State private var count = 0
    @State private var phraseIndex = 0
    /// التاج الرقمي مسبحةٌ ثانية: كل عتبة حبّة، والمرساة تحفظ آخر ما عُدّ.
    @State private var crown: Double = 0
    @State private var crownAnchor: Double = 0
    @FocusState private var crownFocused: Bool

    /// عبارات المسبحة نصٌّ شرعيّ: تُستخرج من adhkar.json بمعرّفاتها ولا تُكتب هنا.
    /// وكانت منسوخةً في السويفت فزاغ تشكيلُ إحداها (t02) عن تشكيله في الملف: كسرةٌ
    /// زِيدت على اللام. نسختان من لفظٍ واحد تفترقان ولا بدّ، والمعرّف يردّهما إلى
    /// أصلٍ واحد يُراجَع في موضع واحد.
    private static let phrases: [Dhikr] = {
        // ترتيبها ترتيبُ الصفحة قبل هذا التغيير حرفًا بحرف — لا يُقدَّم ولا يُؤخَّر.
        let ids = ["t01", "t02", "t04", "p01", "t03", "m17"]
        return ids.compactMap { id in AdhkarLibrary.allItems.first { $0.id == id } }
    }()

    /// وحين يعزّ الملف لا يُختلق نصّ: العدّاد يبقى عاملًا واسمُ التطبيق مكان العبارة.
    private var phrase: Dhikr? {
        Self.phrases.isEmpty ? nil : Self.phrases[phraseIndex % Self.phrases.count]
    }

    private let target = 33

    private var moment: AtharStyle.Moment { .resolved(at: Date(), times: store.prayerTimes()) }

    /// مدخلٌ واحد للعدّ مهما جاء — من الإبهام أو من التاج — فلا يفترق سلوكهما.
    private func bump(_ n: Int) {
        guard n > 0 else { return }
        let before = count
        count += n
        // نبضة عند كل حبّة، وأخرى مميّزة عند تمام الجولة ولو قفز التاج عدّة حبّات.
        let finished = (count / target) != (before / target)
        WKInterfaceDevice.current().play(finished ? .success : .click)
        store.tasbihCount += n
        // ودفتر اليوم يعرف تسبيح الساعة، وإلا بقيت مضاعفة العدّ اليومي صفرًا.
        store.noteDhikr(n)
        WatchSyncReceiver.shared.reportTasbih(n)
        // النقر يخطف التركيز إلى الزرّ، فنردّه ليبقى التاج عادًّا بعده.
        crownFocused = true
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(phrase?.text ?? "أثر")
                .font(.custom("NotoNaskhArabic-Bold", size: 18))
                .padding(.top, 6)
                .foregroundStyle(moment.ink)
                .lineLimit(1).minimumScaleFactor(0.7)

            // الحلقة كلّها زرّ: نقرة في أي موضع تعدّ، مع نبضة ملموسة.
            Button {
                bump(1)
            } label: {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 10)
                    Circle().trim(from: 0, to: Double(count % target) / Double(target))
                        .stroke(moment.tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .environment(\.layoutDirection, .leftToRight)
                        .animation(.snappy, value: count)
                    VStack(spacing: 0) {
                        Text("\(count)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(moment.ink)
                            .contentTransition(.numericText())
                            .monospacedDigit()
                        Text("من \(String(target)) · جولة \(String(count / target + 1))")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(moment.inkSoft)
                    }
                }
                .frame(width: 132, height: 132)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.8).onEnded { _ in
                count = 0
                WKInterfaceDevice.current().play(.retry)
            })
            .accessibilityLabel("عدّ — الحالي \(String(count))")
            .accessibilityHint("انقر أو أدر التاج الرقمي لتعدّ، وضغطة مطوّلة للتصفير")

            // ولا يُعرض «ذكر آخر» على قائمةٍ لا ثاني فيها — زرٌّ لا ينقل شيئًا.
            if Self.phrases.count > 1 {
                Button {
                    phraseIndex = (phraseIndex + 1) % Self.phrases.count
                    count = 0
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 10, weight: .semibold))
                        Text("ذكر آخر").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(moment.tint)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        // بلا تركيز لا يصل التاج إلى الصفحة أصلًا؛ ونطلبه أول ظهورها.
        .focusable()
        .focused($crownFocused)
        // عتبةٌ لكل حبّة، ونبضة النظام مطفأة لأننا نضرب نبضتنا في bump.
        .digitalCrownRotation($crown, from: 0, through: 10_000, by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: false)
        .onChange(of: crown) { _, value in
            let steps = Int((value - crownAnchor).rounded())
            // إرجاع التاج لا يمحو ذكرًا قيل، ولا يُعاد عدّه حين يعود للأمام.
            guard steps > 0 else { return }
            crownAnchor = value
            bump(steps)
            // ولا ينفد التاج: قرب سقفه يعود إلى مبدئه بلا أثرٍ في العدّ.
            if value > 9_900 { crown = 0; crownAnchor = 0 }
        }
        .onAppear { crownFocused = true }
        .containerBackground(LinearGradient(colors: moment.gradient, startPoint: .top, endPoint: .bottom), for: .navigation)
    }
}

// MARK: - ذكر اليوم

struct WatchDhikrPage: View {
    @EnvironmentObject private var store: AtharStore
    @State private var offset = 0

    private var pool: [Dhikr] { AdhkarLibrary.shortItems.isEmpty ? AdhkarLibrary.allItems : AdhkarLibrary.shortItems }
    private var dhikr: Dhikr? {
        guard !pool.isEmpty else { return nil }
        let slot = Int(Date().timeIntervalSince1970 / 1800) + offset
        return pool[abs(slot) % pool.count]
    }
    private var moment: AtharStyle.Moment { .resolved(at: Date(), times: store.prayerTimes()) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let d = dhikr {
                    Text(d.text)
                        .font(.custom("NotoNaskhArabic-Regular", size: 17))
                        .padding(.top, 10)
                        .foregroundStyle(moment.ink)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                    if !d.reference.isEmpty {
                        Text(d.reference)
                            .font(.custom("NotoNaskhArabic-Regular", size: 12)).foregroundStyle(moment.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    if d.count > 1 {
                        Text("يُقال \(timesText(d.count))")
                            .font(.custom("NotoNaskhArabic-Medium", size: 12))
                            .foregroundStyle(moment.tint)
                    }
                    Button {
                        offset += 1
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("ذكر آخر").font(.system(size: 12, weight: .semibold)).foregroundStyle(moment.tint)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("لا أذكار محمّلة").foregroundStyle(moment.inkSoft)
                }
            }
        }
        .containerBackground(LinearGradient(colors: moment.gradient, startPoint: .top, endPoint: .bottom), for: .navigation)
    }
}
