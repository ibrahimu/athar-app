import WidgetKit
import SwiftUI

// MARK: - ودجة الشروق
//
// على نسق إخوتها لا على نسقٍ خاصّ: اللوحةُ من `AtharStyle.Moment.resolved` — وهي
// النقطةُ الواحدة التي تمرّ بها كلُّ الودجات وشاشةُ القفل، فتحترم «لون الويدجت»
// الذي يختاره المستخدم (ثابتًا أو بلحظة اليوم أو بطابع التطبيق). كانت مثبَّتةً على
// لون «الفجر» ونصوصُها بلا ألوان اللوحة، فبدت غريبةً عن أخواتها على الشاشة نفسها.

struct SunriseEntry: TimelineEntry {
    let date: Date
    let sunrise: Date?
    let place: String
    let zone: TimeZone
    let moment: AtharStyle.Moment
}

struct SunriseProvider: TimelineProvider {
    func placeholder(in context: Context) -> SunriseEntry { makeEntry() }
    func getSnapshot(in context: Context, completion: @escaping (SunriseEntry) -> Void) { completion(makeEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SunriseEntry>) -> Void) {
        let entry = makeEntry()
        // يُعاد الحساب بعد الشروق بثانية (فيتحوّل إلى شروق الغد)، وإلا كل ساعة.
        completion(Timeline(entries: [entry],
                            policy: .after(entry.sunrise?.addingTimeInterval(1) ?? Date().addingTimeInterval(3600))))
    }

    private func makeEntry() -> SunriseEntry {
        let store = AtharStore.shared, now = Date()
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = store.placeTimeZone
        let today = store.prayerTimes(for: now)
        var sunrise = today?[.sunrise]
        if sunrise == nil || sunrise! <= now, let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) {
            sunrise = store.prayerTimes(for: tomorrow)?[.sunrise]
        }
        return SunriseEntry(date: now, sunrise: sunrise, place: store.placeName, zone: store.placeTimeZone,
                            moment: .resolved(at: now, times: today))
    }
}

struct SunriseWidgetView: View {
    let entry: SunriseEntry
    @Environment(\.widgetFamily) private var family

    private var time: String {
        guard let sunrise = entry.sunrise else { return "غير متاح" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = entry.zone
        f.dateFormat = "h:mm a"
        return f.string(from: sunrise)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text("الشروق \(time)")
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: "sunrise.fill")
                    Text(time).font(.system(size: 10, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                }
            default:
                // الترتيب والأحجام والألوان كما في ودجة الصلاة الصغيرة سواءً بسواء.
                VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 3) {
                    HStack(spacing: 5) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(entry.moment.tint)
                        Text("الشروق القادم")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(entry.moment.ink)
                    }
                    Text(time)
                        .font(.system(size: family == .systemSmall ? 27 : 20, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [entry.moment.tint, entry.moment.tint.opacity(0.68)],
                                                        startPoint: .top, endPoint: .bottom))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if let sunrise = entry.sunrise {
                        Text(sunrise, style: .timer)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(entry.moment.inkSoft)
                            .monospacedDigit()
                    }
                    if family == .systemSmall {
                        Text(entry.place)
                            .font(.system(size: 11))
                            .foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
    }
}

struct SunriseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AtharSunriseWidget", provider: SunriseProvider()) { entry in
            SunriseWidgetView(entry: entry)
                .containerBackground(for: .widget) { AtharStyle.Backdrop(moment: entry.moment) }
                .widgetURL(URL(string: "athar://open/prayer"))
        }
        .configurationDisplayName("موعد الشروق")
        .description("الشروق القادم والوقت المتبقي له حسب مدينتك.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
