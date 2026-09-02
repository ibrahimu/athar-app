import WidgetKit
import SwiftUI

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let place: String
    let zone: TimeZone
    let upcoming: (prayer: Prayer, date: Date)?
    let today: [(prayer: Prayer, date: Date)]
    let moment: AtharStyle.Moment
}

struct PrayerProvider: TimelineProvider {

    private func entry(at date: Date, store: AtharStore) -> PrayerEntry {
        let today = store.prayerTimes(for: date)
        var upcoming = today?.next(after: date)
        if upcoming == nil,
           let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date),
           let t = store.prayerTimes(for: tomorrow), let fajr = t[.fajr] {
            upcoming = (.fajr, fajr)
        }
        return PrayerEntry(date: date,
                           place: store.placeName,
                           zone: store.placeTimeZone,
                           upcoming: upcoming,
                           today: today?.ordered ?? [],
                           moment: .at(date, times: today))
    }

    func placeholder(in context: Context) -> PrayerEntry {
        entry(at: Date(), store: AtharStore.shared)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(entry(at: Date(), store: AtharStore.shared))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let store = AtharStore.shared
        let now = Date()
        let first = entry(at: now, store: store)

        // Refresh exactly when the next prayer enters, so the widget flips over on time.
        var entries = [first]
        if let upcoming = first.upcoming {
            entries.append(entry(at: upcoming.date.addingTimeInterval(1), store: store))
        }
        let reload = first.upcoming?.date.addingTimeInterval(2) ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: entries, policy: .after(reload)))
    }
}

// MARK: - Views

struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "h:mm a"
        return f
    }()

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "h:mm a"
        f.timeZone = entry.zone
        return f.string(from: date)
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            if let up = entry.upcoming {
                Text("\(up.prayer.title) \(time(up.date))")
            } else {
                Text("أوقات الصلاة")
            }

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.upcoming?.prayer.icon ?? "moon.stars.fill")
                        .font(.system(size: 12, weight: .semibold))
                    if let up = entry.upcoming {
                        Text(up.date, style: .timer)
                            .font(.system(size: 10, weight: .medium))
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                    }
                }
                .padding(2)
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                if let up = entry.upcoming {
                    HStack(spacing: 4) {
                        Image(systemName: up.prayer.icon).font(.system(size: 11))
                        Text(up.prayer.title).font(.system(size: 13, weight: .semibold))
                        Spacer()
                    }
                    .widgetAccentable()
                    Text(time(up.date)).font(.system(size: 15, weight: .bold))
                    Text(up.date, style: .relative)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("أوقات الصلاة").font(.system(size: 13, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

        case .systemSmall:
            ZStack {
                if let up = entry.upcoming {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 5) {
                            Image(systemName: up.prayer.icon)
                                .font(.system(size: 12, weight: .medium))
                            Text(up.prayer.title)
                                .font(.system(size: 17, weight: .bold))
                        }
                        .foregroundStyle(entry.moment.ink)

                        Text(time(up.date))
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [entry.moment.tint, entry.moment.tint.opacity(0.68)],
                                                            startPoint: .top, endPoint: .bottom))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                            .padding(.top, 1)

                        Text(up.date, style: .timer)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(entry.moment.inkSoft)
                            .monospacedDigit()

                        Spacer(minLength: 0)

                        DayArc(entry: entry).frame(height: 22)

                        Text(entry.place)
                            .font(.system(size: 10))
                            .foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(1)
                            .padding(.top, 5)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)

        default: // systemMedium
            VStack(spacing: 9) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    if let up = entry.upcoming {
                        Image(systemName: up.prayer.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(entry.moment.tint)
                        Text(up.prayer.title)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(entry.moment.ink)
                        Text(time(up.date))
                            .font(.system(size: 19, weight: .semibold, design: .rounded))
                            .foregroundStyle(entry.moment.tint)
                        Text(up.date, style: .timer)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(entry.moment.inkSoft)
                            .monospacedDigit()
                    }
                    Spacer()
                    Text(entry.place)
                        .font(.system(size: 11))
                        .foregroundStyle(entry.moment.inkSoft)
                        .lineLimit(1)
                }

                DayArc(entry: entry).frame(height: 26)

                HStack(spacing: 5) {
                    ForEach(entry.today.filter(\.prayer.isPrayer), id: \.prayer) { item in
                        let isNext = entry.upcoming?.prayer == item.prayer
                        VStack(spacing: 3) {
                            Text(item.prayer.title)
                                .font(.system(size: 10, weight: isNext ? .bold : .regular))
                                .foregroundStyle(isNext ? entry.moment.tint : entry.moment.inkSoft)
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Text(time(item.date))
                                .font(.system(size: 11, weight: isNext ? .bold : .medium, design: .rounded))
                                .foregroundStyle(isNext ? entry.moment.ink : entry.moment.inkSoft)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isNext ? entry.moment.tint.opacity(0.16) : .clear)
                        )
                    }
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

/// قوس اليوم: خط الأوقات من الفجر إلى العشاء مع موضعك الآن عليه.
private struct DayArc: View {
    let entry: PrayerEntry

    private var fraction: Double {
        let pts = entry.today.filter(\.prayer.isPrayer)
        guard let first = pts.first?.date, let last = pts.last?.date, last > first else { return 0 }
        return min(1, max(0, entry.date.timeIntervalSince(first) / last.timeIntervalSince(first)))
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack(alignment: .leading) {
                Capsule().fill(entry.moment.ink.opacity(0.13)).frame(height: 3)
                Capsule().fill(entry.moment.tint.opacity(0.85))
                    .frame(width: max(3, w * fraction), height: 3)

                // نقاط الصلوات على الخط
                ForEach(Array(entry.today.filter(\.prayer.isPrayer).enumerated()), id: \.element.prayer) { i, item in
                    let pts = entry.today.filter(\.prayer.isPrayer)
                    let f = pts.count > 1 ? Double(i) / Double(pts.count - 1) : 0
                    let passed = item.date <= entry.date
                    Circle()
                        .fill(passed ? entry.moment.tint : entry.moment.ink.opacity(0.28))
                        .frame(width: 5, height: 5)
                        .position(x: w * f, y: h / 2)
                }

                // موضع الآن
                Circle()
                    .fill(entry.moment.ink)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(entry.moment.tint, lineWidth: 2))
                    .position(x: w * fraction, y: h / 2)
            }
            .frame(height: h)
        }
    }
}

// MARK: - Widget

struct PrayerWidget: Widget {
    private let kind = "AtharPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
                .containerBackground(for: .widget) { AtharStyle.Backdrop(moment: entry.moment) }
        }
        .configurationDisplayName("أوقات الصلاة")
        .description("الصلاة القادمة والوقت المتبقي لها — على الشاشة الرئيسية أو شاشة القفل.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}
