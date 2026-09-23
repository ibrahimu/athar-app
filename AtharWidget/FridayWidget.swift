import WidgetKit
import SwiftUI

// MARK: - ودجة الجمعة
//
// ما تصنعه: تُبقي سنن الجمعة في العين طولَ الأسبوع بلا أن تفتح التطبيق. وليس
// فيها من الجديد شيءٌ يُحسب: الحصيلةُ من `fridayProgress` كما في بطاقة «اليوم»،
// وساعةُ الإجابة آخرُ ساعةٍ قبل المغرب كما في شاشة الجمعة، واللوحةُ من
// `AtharStyle.Moment.resolved` كسائر الودجات فتتبع «لون الويدجت» ولباسَ الجمعة.
//
// ووجهان لا وجه: يومَ الجمعة تقول ما بقي من سننها وكم بقي على ساعة الإجابة،
// وسائرَ الأسبوع تقول كم بقي على الجمعة — فلا تصير بلاطةً ميّتةً ستة أيام.

struct FridayEntry: TimelineEntry {
    let date: Date
    /// اليومُ جمعة؟ — بتقويم المكان لا بتقويم الجهاز.
    let isFriday: Bool
    /// كم يومًا إلى الجمعة القادمة (صفرٌ يومَها).
    let daysAway: Int
    /// أُدّي من السنن وكم جملتُها.
    let done: Int
    let total: Int
    /// أوّلُ ساعة الإجابة: المغربُ ناقصَ ساعة. تُترك خاليةً إن لم تُعرف المواقيت.
    let answerHour: Date?
    let maghrib: Date?
    let zone: TimeZone
    let moment: AtharStyle.Moment
}

struct FridayProvider: TimelineProvider {
    func placeholder(in context: Context) -> FridayEntry { makeEntry() }
    func getSnapshot(in context: Context, completion: @escaping (FridayEntry) -> Void) { completion(makeEntry()) }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FridayEntry>) -> Void) {
        let entry = makeEntry()
        // تُعاد عند أوّل ساعة الإجابة (فيتبدّل السطر)، وعند المغرب (فتنقضي الجمعة)،
        // وإلّا فعند منتصف الليل — فتتبدّل «بعد كم يوم» في أوّل يومها لا في ظهره.
        let now = Date()
        var next = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
        for boundary in [entry.answerHour, entry.maghrib].compactMap({ $0 }) where boundary > now {
            next = min(next, boundary.addingTimeInterval(1))
        }
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func makeEntry() -> FridayEntry {
        let store = AtharStore.shared, now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = store.placeTimeZone
        let friday = AtharStore.isFriday(now, calendar: calendar)
        let times = store.prayerTimes(for: now)
        let maghrib = friday ? times?[.maghrib] : nil
        let progress = store.fridayProgress
        return FridayEntry(date: now,
                           isFriday: friday,
                           daysAway: AtharStore.daysUntilFriday(now),
                           done: progress.done, total: progress.total,
                           answerHour: maghrib?.addingTimeInterval(-3600),
                           maghrib: maghrib,
                           zone: store.placeTimeZone,
                           moment: .resolved(at: now, times: times))
    }
}

struct FridayWidgetView: View {
    let entry: FridayEntry
    @Environment(\.widgetFamily) private var family

    /// «بعد 3 أيام» / «غدًا» — تمييزُ العدد من `counterText` كبقيّة أرقام التطبيق.
    private var away: String {
        switch entry.daysAway {
        case 0:  return "اليوم"
        case 1:  return "غدًا"
        default: return "بعد \(entry.daysAway.counterText) أيام"
        }
    }

    /// ما يُقال يوم الجمعة نفسِه: ساعةُ الإجابة إن حانت أو قربت، وإلّا الحصيلة.
    private var fridayLine: String {
        guard let hour = entry.answerHour, let maghrib = entry.maghrib else {
            return "\(entry.done.counterText) من \(entry.total.counterText) من السنن"
        }
        if entry.date >= hour && entry.date < maghrib { return "ساعة الإجابة الآن" }
        return "\(entry.done.counterText) من \(entry.total.counterText) من السنن"
    }

    private var remaining: Int { max(0, entry.total - entry.done) }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.isFriday ? "الجمعة · \(fridayLine)" : "الجمعة \(away)")
            case .accessoryCircular:
                VStack(spacing: 2) {
                    Image(systemName: "calendar.badge.clock")
                    Text(entry.isFriday ? "\(entry.done.counterText)/\(entry.total.counterText)" : away)
                        .font(.system(size: 10, design: .rounded))
                        .minimumScaleFactor(0.6).lineLimit(1)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 1) {
                    Text("سنن الجمعة").font(.system(size: 13, weight: .semibold))
                    Text(entry.isFriday ? fridayLine : "الجمعة \(away)")
                        .font(.system(size: 12)).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 11))
                            .foregroundStyle(entry.moment.tint)
                        Text(entry.isFriday ? "جمعة مباركة" : "سنن الجمعة")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(entry.moment.ink)
                    }

                    if entry.isFriday {
                        Text(fridayLine)
                            .font(.system(size: family == .systemSmall ? 20 : 18, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [entry.moment.tint, entry.moment.tint.opacity(0.68)],
                                                            startPoint: .top, endPoint: .bottom))
                            .minimumScaleFactor(0.55).lineLimit(2)
                        // ما بقي من النهار على ساعة الإجابة — عدّادٌ يمشي من نفسه.
                        if let hour = entry.answerHour, entry.date < hour {
                            Text(hour, style: .timer)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(entry.moment.inkSoft)
                                .monospacedDigit()
                            Text("حتى ساعة الإجابة")
                                .font(.system(size: 11))
                                .foregroundStyle(entry.moment.inkSoft)
                                .lineLimit(1)
                        } else {
                            Text(remaining == 0 ? "أتممت سننها" : "بقي \(remaining.counterText)")
                                .font(.system(size: 11))
                                .foregroundStyle(entry.moment.inkSoft)
                                .lineLimit(1)
                        }
                    } else {
                        Text(away)
                            .font(.system(size: family == .systemSmall ? 24 : 20, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [entry.moment.tint, entry.moment.tint.opacity(0.68)],
                                                            startPoint: .top, endPoint: .bottom))
                            .minimumScaleFactor(0.6).lineLimit(1)
                        Text("الغسل والكهف والصلاة على النبي ﷺ")
                            .font(.system(size: 11))
                            .foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
    }
}

struct FridayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AtharFridayWidget", provider: FridayProvider()) { entry in
            FridayWidgetView(entry: entry)
                .containerBackground(for: .widget) { AtharStyle.Backdrop(moment: entry.moment) }
                .widgetURL(URL(string: "athar://open/friday"))
        }
        .configurationDisplayName("الجمعة")
        .description("سنن الجمعة وحصيلتُها وساعةُ الإجابة، وكم بقي عليها سائرَ الأسبوع.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
