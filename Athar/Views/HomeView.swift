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
                AtharBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        prayerStrip
                        statsRow
                        if let suggested { suggestionCard(suggested) }
                        if let dailyDhikr { dailyCard(dailyDhikr) }
                        quickGrid
                        sadaqahCard
                        footerNote
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .readableWidth()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("أثر").font(Theme.display(18, weight: .bold)).foregroundStyle(Theme.ink)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting)
                .font(Theme.display(28, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(hijriDate)
                .font(Theme.display(14, weight: .regular))
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 4..<12:  return "صباح الخير"
        case 12..<17: return "طاب يومك"
        case 17..<21: return "مساء الخير"
        default:      return "طابت ليلتك"
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

    @ViewBuilder
    private var prayerStrip: some View {
        if let upcoming = upcomingPrayer {
            Button { onOpenTab(.prayer) } label: {
                AtharCard(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: upcoming.prayer.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Theme.accentSoft))

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
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.accent)
                            Text(countdown(to: upcoming.date))
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.inkFaint)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? "بعد \(h) س \(m) د" : "بعد \(m) د"
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: store.displayStreak.counterText,
                     label: "يوم متتابع",
                     icon: "flame.fill",
                     color: Theme.gold)
            statTile(value: store.totalDhikrCount.counterText,
                     label: "ذكر بإذن الله",
                     icon: "infinity",
                     color: Theme.accent)
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                    Text(label).font(Theme.display(12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(color)

                Text(value)
                    .font(Theme.display(28, weight: .bold))
                    .foregroundStyle(Theme.ink)
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
            AtharCard(padding: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(done ? "أتممتها اليوم" : "وقتها الآن")
                            .font(Theme.display(12, weight: .bold))
                            .foregroundStyle(color)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Capsule().fill(color.opacity(0.14)))
                        Spacer()
                        Image(systemName: done ? "checkmark.seal.fill" : "arrow.left")
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
        .buttonStyle(.plain)
    }

    // MARK: Daily dhikr

    private func dailyCard(_ dhikr: Dhikr) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "ذكر اليوم")
            AtharCard {
                VStack(alignment: .leading, spacing: 12) {
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
                        Label("انشر الأجر", systemImage: "square.and.arrow.up")
                            .font(Theme.display(13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    // MARK: Quick grid

    private var quickGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "ابدأ الآن") { onOpenTab(.adhkar) }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(AdhkarLibrary.categories.prefix(6)) { category in
                    NavigationLink {
                        DhikrSessionView(category: category)
                    } label: {
                        CategoryTile(category: category,
                                     completed: store.completedToday.contains(category.id))
                    }
                    .buttonStyle(.plain)
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
                        Text("صدقة اليوم")
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
        .buttonStyle(.plain)
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
        return AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(color)
                    Spacer()
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
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
