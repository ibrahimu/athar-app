import SwiftUI
import WatchKit

@main
struct AtharWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchRootView() }
    }
}

private enum WatchStyle {
    static let accent = Color(red: 0.31, green: 0.75, blue: 0.56)   // أخضر أثر
    static let gold   = Color(red: 0.85, green: 0.71, blue: 0.37)
    static let ink    = Color.white
    static let inkSoft = Color.white.opacity(0.62)
}

struct WatchRootView: View {
    var body: some View {
        TabView {
            WatchPrayerView()
            WatchTasbihView()
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - أوقات الصلاة

struct WatchPrayerView: View {
    private let store = AtharStore.shared
    @State private var now = Date()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var times: PrayerTimes? { store.prayerTimes(for: now) }
    private var upcoming: (prayer: Prayer, date: Date)? {
        if let n = times?.next(after: now) { return n }
        guard let tm = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let t = store.prayerTimes(for: tm), let f = t[.fajr] else { return nil }
        return (.fajr, f)
    }

    private func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "h:mm"
        f.timeZone = store.placeTimeZone
        return f.string(from: d)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let up = upcoming {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("الصلاة القادمة")
                            .font(.system(size: 12)).foregroundStyle(WatchStyle.inkSoft)
                        HStack {
                            Image(systemName: up.prayer.icon).foregroundStyle(WatchStyle.gold)
                            Text(up.prayer.title)
                                .font(.system(size: 22, weight: .bold)).foregroundStyle(WatchStyle.ink)
                            Spacer()
                            Text(time(up.date))
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundStyle(WatchStyle.gold)
                        }
                        Text(up.date, style: .relative)
                            .font(.system(size: 12, design: .rounded)).foregroundStyle(WatchStyle.inkSoft)
                    }
                    .padding(.bottom, 4)
                }

                if let t = times {
                    ForEach(Prayer.allCases.filter { $0.isPrayer }, id: \.self) { p in
                        if let d = t[p] {
                            let isNext = upcoming?.prayer == p
                            HStack {
                                Image(systemName: p.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(isNext ? WatchStyle.gold : WatchStyle.inkSoft)
                                    .frame(width: 20)
                                Text(p.title)
                                    .font(.system(size: 15, weight: isNext ? .bold : .regular))
                                    .foregroundStyle(isNext ? WatchStyle.ink : WatchStyle.inkSoft)
                                Spacer()
                                Text(time(d))
                                    .font(.system(size: 15, weight: isNext ? .bold : .regular, design: .rounded))
                                    .foregroundStyle(isNext ? WatchStyle.gold : WatchStyle.inkSoft)
                            }
                            .padding(.vertical, 3)
                            Divider().overlay(Color.white.opacity(0.08))
                        }
                    }
                    Text(store.placeName)
                        .font(.system(size: 11)).foregroundStyle(WatchStyle.inkSoft)
                        .frame(maxWidth: .infinity).padding(.top, 2)
                } else {
                    Text("افتح التطبيق في الآيفون لضبط موقعك")
                        .font(.system(size: 13)).foregroundStyle(WatchStyle.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 4)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .navigationTitle("الصلاة")
        .onReceive(ticker) { now = $0 }
    }
}

// MARK: - المسبحة

struct WatchTasbihView: View {
    @State private var count = 0
    private let phrase = "سُبْحَانَ اللهِ وَبِحَمْدِهِ"

    var body: some View {
        VStack(spacing: 8) {
            Text(phrase)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(WatchStyle.ink)
                .multilineTextAlignment(.center)
            Text("\(count)")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(WatchStyle.accent)
                .contentTransition(.numericText())
            HStack(spacing: 8) {
                Button {
                    count = 0
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .frame(width: 44)
                .tint(.gray)

                Button {
                    count += 1
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text("سبّح").frame(maxWidth: .infinity)
                }
                .tint(WatchStyle.accent)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 6)
        .navigationTitle("المسبحة")
        .environment(\.layoutDirection, .rightToLeft)
    }
}
