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

/// ثلاث صفحات رأسية: الصلاة القادمة، المسبحة، ذكر اليوم — ولون الخلفية يتبع وقت اليوم.
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
    private var moment: AtharStyle.Moment { .at(now, times: times) }

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

    private let phrases = ["سُبْحَانَ اللهِ", "الْحَمْدُ لِلهِ", "اللهُ أَكْبَرُ", "أَسْتَغْفِرُ اللهَ", "لَا إِلَهَ إِلَّا اللهُ", "سُبْحَانَ اللهِ وَبِحَمْدِهِ"]
    private let target = 33

    private var moment: AtharStyle.Moment { .at(Date(), times: store.prayerTimes()) }

    var body: some View {
        VStack(spacing: 12) {
            Text(phrases[phraseIndex])
                .font(.custom("NotoNaskhArabic-Bold", size: 18))
                .padding(.top, 6)
                .foregroundStyle(moment.ink)
                .lineLimit(1).minimumScaleFactor(0.7)

            // الحلقة كلّها زرّ: نقرة في أي موضع تعدّ، مع نبضة ملموسة.
            Button {
                count += 1
                WKInterfaceDevice.current().play(count % target == 0 ? .success : .click)
                store.tasbihCount += 1
                WatchSyncReceiver.shared.reportTasbih(1)
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
            .accessibilityLabel("عدّ — الحالي \(count)")
            .accessibilityHint("ضغطة مطوّلة للتصفير")

            Button {
                phraseIndex = (phraseIndex + 1) % phrases.count
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
        .padding(.horizontal, 4)
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
    private var moment: AtharStyle.Moment { .at(Date(), times: store.prayerTimes()) }

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
                        Text("يُقال \(String(d.count)) مرّات")
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
