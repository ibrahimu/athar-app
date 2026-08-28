import WidgetKit
import SwiftUI

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let place: String
    let upcoming: (prayer: Prayer, date: Date)?
    let today: [(prayer: Prayer, date: Date)]
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
                           upcoming: upcoming,
                           today: today?.ordered ?? [])
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

    private func time(_ date: Date) -> String { Self.clock.string(from: date) }

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
            VStack(alignment: .leading, spacing: 6) {
                if let up = entry.upcoming {
                    HStack(spacing: 5) {
                        Image(systemName: up.prayer.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.accent)
                        Text(up.prayer.title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                    }
                    Text(time(up.date))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accent)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(up.date, style: .timer)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                    Spacer(minLength: 0)
                    Text(entry.place)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

        default: // systemMedium
            VStack(spacing: 8) {
                HStack {
                    if let up = entry.upcoming {
                        Image(systemName: up.prayer.icon)
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.accent)
                        Text(up.prayer.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(time(up.date))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                    Spacer()
                    Text(entry.place)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }

                HStack(spacing: 0) {
                    ForEach(entry.today.filter(\.prayer.isPrayer), id: \.prayer) { item in
                        let isNext = entry.upcoming?.prayer == item.prayer
                        VStack(spacing: 3) {
                            Text(item.prayer.title)
                                .font(.system(size: 11, weight: isNext ? .bold : .regular))
                                .foregroundStyle(isNext ? Theme.accent : Theme.inkSoft)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(time(item.date))
                                .font(.system(size: 11, weight: isNext ? .bold : .regular, design: .rounded))
                                .foregroundStyle(isNext ? Theme.accent : Theme.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(isNext ? Theme.accentSoft : .clear)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Widget

struct PrayerWidget: Widget {
    private let kind = "AtharPrayerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
                .containerBackground(for: .widget) { Theme.canvas }
        }
        .configurationDisplayName("أوقات الصلاة")
        .description("الصلاة القادمة والوقت المتبقي لها — على الشاشة الرئيسية أو شاشة القفل.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}
