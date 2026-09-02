import SwiftUI
import WidgetKit

struct HomeView: View {
    @EnvironmentObject private var store: AtharStore
    var onOpenTab: (AppTab) -> Void

    @State private var now = Date()
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var suggested: DhikrCategory? {
        AdhkarLibrary.category(id: DhikrCategory.suggestedNow(date: now))
    }

    private var dailyDhikr: Dhikr? {
        let pool = AdhkarLibrary.shortItems
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        return pool[day % pool.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: dayTint, secondary: Theme.gold)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header.appearStagger(0)
                        prayerStrip.appearStagger(1)
                        statsRow.appearStagger(2)
                        if let suggested { suggestionCard(suggested).appearStagger(3) }
                        if let dailyDhikr { dailyCard(dailyDhikr).appearStagger(4) }
                        quickGrid.appearStagger(5)
                        sadaqahCard.appearStagger(6)
                        footerNote.appearStagger(7)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .readableWidth()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(loc("أثر")).font(Theme.display(18, weight: .bold)).foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsSheet() } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .onReceive(ticker) { now = $0 }
        .onAppear { WidgetCenter.shared.reloadAllTimelines() }
    }

    // MARK: Header

    /// لون اليوم — يتبدّل مع الصلاة القادمة (فجر كهرماني ← عشاء نيليّ).
    private var dayTint: Color {
        Theme.accent(for: upcomingPrayer?.prayer.accentKey ?? "green")
    }

    private var timeSymbol: String {
        switch Calendar.current.component(.hour, from: now) {
        case 4..<12:  return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<20: return "sunset.fill"
        default:      return "moon.stars.fill"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(greeting)
                .font(Theme.display(28, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Theme.ink, Theme.inkSoft],
                                                startPoint: .top, endPoint: .bottom))
            HStack(spacing: 6) {
                Image(systemName: timeSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(dayTint)
                Text(hijriDate)
                    .font(Theme.display(12.5, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(Theme.surfaceAlt))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 4..<12:  return loc("goodMorning")
        case 12..<17: return loc("goodDay")
        case 17..<21: return loc("goodEvening")
        default:      return loc("goodNight")
        }
    }

    private var hijriDate: String {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar_SA")
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "ar_SA")
        f.dateFormat = "EEEE، d MMMM yyyy"
        return f.string(from: now) + " هـ"
    }

    // MARK: Next prayer

    private var upcomingPrayer: (prayer: Prayer, date: Date)? {
        if let next = store.prayerTimes(for: now)?.next(after: now) { return next }
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let t = store.prayerTimes(for: tomorrow), let fajr = t[.fajr]
        else { return nil }
        return (.fajr, fajr)
    }

    /// نسبة انقضاء الوقت بين الصلاة السابقة والقادمة — تملأ حلقة حيّة.
    private var prayerArc: Double {
        guard let up = upcomingPrayer else { return 0 }
        let next = up.date
        let prev: Date
        if let times = store.prayerTimes(for: now),
           let earlier = Prayer.allCases.filter({ $0.isPrayer })
               .compactMap({ times[$0] }).filter({ $0 <= now }).max() {
            prev = earlier
        } else {
            prev = next.addingTimeInterval(-6 * 3600)
        }
        let total = next.timeIntervalSince(prev)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(prev) / total))
    }

    @ViewBuilder
    private var prayerStrip: some View {
        if let upcoming = upcomingPrayer {
            let pcolor = Theme.accent(for: upcoming.prayer.accentKey)
            Button { onOpenTab(.prayer) } label: {
                AtharCard(padding: 14, elevation: .e2, tint: pcolor) {
                    HStack(spacing: 12) {
                        ZStack {
                            ProgressRing(progress: prayerArc, color: pcolor, lineWidth: 3, gradient: true)
                                .frame(width: 46, height: 46)
                            Image(systemName: upcoming.prayer.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(pcolor)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(upcoming.prayer.title)
                                .font(Theme.display(17, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(store.placeName)
                                .font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(PrayerView.time(upcoming.date, in: store.placeTimeZone))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(LinearGradient(colors: [pcolor, pcolor.opacity(0.7)],
                                                                startPoint: .top, endPoint: .bottom))
                            Text(countdown(to: upcoming.date))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.inkFaint)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .pressable()
        }
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? loc("بعد %1$@ س %2$@ د", h.counterText, m.counterText) : loc("بعد %1$@ د", m.counterText)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: store.displayStreak.counterText,
                     label: loc("statStreak"),
                     icon: "flame.fill",
                     color: Theme.gold)
            statTile(value: store.totalDhikrCount.counterText,
                     label: loc("statTotal"),
                     icon: "infinity",
                     color: Theme.accent)
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .background(
                            Circle().fill(color.opacity(0.2)).frame(width: 26, height: 26).blur(radius: 7)
                        )
                    Text(label).font(Theme.display(12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(color)

                Text(value)
                    .font(Theme.display(30, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)],
                                                    startPoint: .top, endPoint: .bottom))
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: Suggestion

    private func suggestionCard(_ category: DhikrCategory) -> some View {
        let color = Theme.accent(for: category.accent)
        let done = store.completedToday.contains(category.id)
        return NavigationLink {
            DhikrSessionView(category: category)
        } label: {
            AtharCard(padding: 18, elevation: .e2, tint: color) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if done {
                            Label(loc("أتممتها اليوم"), systemImage: "checkmark.seal.fill")
                                .font(Theme.display(12, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .padding(.horizontal, 11).padding(.vertical, 5)
                                .background(Capsule().fill(Theme.gradient(for: "gold")))
                        } else {
                            Text(loc("وقتها الآن"))
                                .font(Theme.display(12, weight: .bold))
                                .foregroundStyle(color)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(color.opacity(0.14)))
                        }
                        Spacer()
                        Image(systemName: done ? "checkmark.seal.fill" : "arrow.forward")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color)
                    }

                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title)
                                .font(Theme.display(23, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(category.subtitle)
                                .font(Theme.display(13))
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: category.icon)
                            .font(.system(size: 30))
                            .foregroundStyle(color)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(color.opacity(0.13)))
                    }
                }
            }
        }
        .pressable()
    }

    // MARK: Daily dhikr

    private func dailyCard(_ dhikr: Dhikr) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("dhikrOfDay"), tint: Theme.gold)
            AtharCard {
                VStack(alignment: .leading, spacing: 12) {
                    // خيط ذهبي علوي — كحاشية المصحف المذهّبة
                    Capsule().fill(Theme.goldGradient)
                        .frame(width: 46, height: 3)
                        .opacity(0.7)

                    Text(dhikr.text)
                        .font(Theme.dhikrFont(size: 20, scale: store.fontScale))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(10)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if dhikr.hasReference {
                        Text(dhikr.reference)
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkFaint)
                    }

                    ShareLink(item: dhikr.text + (dhikr.hasReference ? "\n\n\(dhikr.reference)" : "") + "\n\nمن تطبيق أثر") {
                        Label(loc("انشر الأجر"), systemImage: "square.and.arrow.up")
                            .font(Theme.display(13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(Theme.accent.opacity(0.13)))
                    }
                    .pressable()
                }
            }
        }
    }

    // MARK: Quick grid

    private var quickGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("startNow")) { onOpenTab(.adhkar) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(AdhkarLibrary.categories.prefix(6)) { category in
                    NavigationLink {
                        DhikrSessionView(category: category)
                    } label: {
                        CategoryTile(category: category,
                                     completed: store.completedToday.contains(category.id))
                    }
                    .pressable()
                }
            }
        }
    }

    /// «الصدقة تطفئ الخطيئة كما يطفئ الماء النار» — مدخل سريع لإحسان.
    private var sadaqahCard: some View {
        Link(destination: URL(string: "https://ehsan.sa")!) {
            AtharCard(padding: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Theme.gold.opacity(0.13)))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(loc("صدقة اليوم"))
                            .font(Theme.display(16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("«الصدقة تطفئ الخطيئة كما يطفئ الماء النار»")
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    private var footerNote: some View {
        Text("﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾")
            .font(Theme.dhikrFont(size: 16))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

// MARK: - Tile

struct CategoryTile: View {
    let category: DhikrCategory
    var completed: Bool = false

    var body: some View {
        let color = Theme.accent(for: category.accent)
        return AtharCard(padding: 14, tint: color) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(color.opacity(0.14)))
                    Spacer()
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(color)
                    }
                }
                Text(category.title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text("\(category.items.count.counterText) ذكر")
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
