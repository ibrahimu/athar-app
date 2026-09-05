import WidgetKit
import SwiftUI

// MARK: - مضاعفة الصلاة القادمة (واجهة الساعة)

struct PrayerComplicationEntry: TimelineEntry {
    let date: Date
    let prayer: Prayer
    let time: Date
    let previous: Date
    let place: String
    let tz: TimeZone
}

struct PrayerComplicationProvider: TimelineProvider {
    private func entry(at date: Date) -> PrayerComplicationEntry? {
        let store = AtharStore.shared
        guard let t = store.prayerTimes(for: date) else { return nil }
        let ordered = t.ordered.filter { $0.prayer.isPrayer }
        if let i = ordered.firstIndex(where: { $0.date > date }) {
            let prev = i > 0 ? ordered[i - 1].date : ordered[i].date.addingTimeInterval(-5 * 3600)
            return .init(date: date, prayer: ordered[i].prayer, time: ordered[i].date, previous: prev, place: store.placeName, tz: store.placeTimeZone)
        }
        guard let tm = Calendar.current.date(byAdding: .day, value: 1, to: date),
              let f = store.prayerTimes(for: tm)?[.fajr], let isha = t[.isha] else { return nil }
        return .init(date: date, prayer: .fajr, time: f, previous: isha, place: store.placeName, tz: store.placeTimeZone)
    }
    private var fallback: PrayerComplicationEntry {
        .init(date: Date(), prayer: .fajr, time: Date().addingTimeInterval(3600), previous: Date(), place: "", tz: .current)
    }
    func placeholder(in context: Context) -> PrayerComplicationEntry { entry(at: Date()) ?? fallback }
    func getSnapshot(in context: Context, completion: @escaping (PrayerComplicationEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerComplicationEntry>) -> Void) {
        var entries: [PrayerComplicationEntry] = []
        var cursor = Date()
        for _ in 0..<8 {
            guard let e = entry(at: cursor) else { break }
            entries.append(e)
            cursor = e.time.addingTimeInterval(60)
        }
        completion(Timeline(entries: entries.isEmpty ? [fallback] : entries, policy: .atEnd))
    }
}

struct PrayerComplicationView: View {
    let entry: PrayerComplicationEntry
    @Environment(\.widgetFamily) private var family

    private func clock(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = entry.tz
        f.dateFormat = "h:mm"
        return f.string(from: d)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                // مقياس دائري: نصيب ما مضى من الوقت بين الصلاتين
                Gauge(value: entry.date.timeIntervalSince(entry.previous),
                      in: 0...max(1, entry.time.timeIntervalSince(entry.previous))) {
                    Image(systemName: entry.prayer.icon)
                } currentValueLabel: {
                    VStack(spacing: -2) {
                        Image(systemName: entry.prayer.icon).font(.system(size: 11, weight: .semibold))
                        Text(clock(entry.time)).font(.system(size: 11, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
                    }
                }
                .gaugeStyle(.accessoryCircular)
            }
        case .accessoryCorner:
            Text(clock(entry.time))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .widgetLabel {
                    Text("\(entry.prayer.title)")
                }
        case .accessoryInline:
            Text("\(entry.prayer.title) \(clock(entry.time))")
        default: // rectangular
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: entry.prayer.icon).font(.system(size: 11, weight: .semibold))
                    Text(entry.prayer.title).font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text(clock(entry.time)).font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                }
                Text(timerInterval: entry.date...entry.time, countsDown: true)
                    .font(.system(size: 13, weight: .medium, design: .rounded)).monospacedDigit()
                    .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
                if !entry.place.isEmpty {
                    Text(entry.place).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct NextPrayerComplication: Widget {
    private let kind = "AtharWatchNextPrayer"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerComplicationProvider()) { entry in
            PrayerComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("الصلاة القادمة")
        .description("اسم الصلاة القادمة ووقتها والعدّ إليها على واجهة الساعة.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
