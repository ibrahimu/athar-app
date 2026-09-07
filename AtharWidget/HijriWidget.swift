import WidgetKit
import SwiftUI

// MARK: - التقويم الهجري
//
// تاريخ اليوم بأم القرى، وأقربُ ما ينتظره المسلم من مواسم الطاعة —
// ليُدرك العشرَ وعرفةَ وعاشوراء قبل أن تمرّ به لا بعدها.

struct HijriEntry: TimelineEntry {
    let date: Date
    let day: Int
    let month: Int
    let year: Int
    /// اسم اليوم بالعربية — «الجمعة» تُذكّر بسورة الكهف كما يذكّر الرقم بالصيام.
    let weekday: String
    let occasion: HijriOccasion?
    /// ما بقي للمناسبة بالأيام، وصفرٌ فما دونه: هي جارية الآن.
    let remaining: Int
    let moment: AtharStyle.Moment
}

struct HijriProvider: TimelineProvider {
    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.dateFormat = "EEEE"
        return f
    }()

    private func entry(at date: Date) -> HijriEntry {
        let c = Occasions.hijriComponents(date)
        let next = Occasions.upcoming(from: date, limit: 1).first
        return HijriEntry(date: date,
                          day: c.day, month: c.month, year: c.year,
                          weekday: Self.weekdayFormatter.string(from: date),
                          occasion: next?.occasion,
                          remaining: next.map { Occasions.daysUntil($0.start, from: date) } ?? 0,
                          moment: .resolved(at: date, times: AtharStore.shared.prayerTimes(for: date)))
    }

    func placeholder(in context: Context) -> HijriEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (HijriEntry) -> Void) { completion(entry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HijriEntry>) -> Void) {
        // التاريخ يتبدّل مع اليوم: مدخل الآن ومدخل بعد منتصف الليل.
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry(at: now), entry(at: midnight)], policy: .atEnd))
    }
}

// MARK: - View

struct HijriWidgetView: View {
    let entry: HijriEntry
    @Environment(\.widgetFamily) private var family

    private var monthName: String { Occasions.monthName(entry.month) }
    /// «1447» لا «1,447» — السنة تاريخٌ لا عدد معدود.
    private var fullDate: String {
        loc("%1$@ %2$@ %3$@ هـ", entry.day.counterText, monthName, String(entry.year))
    }
    private var when: String { whenText(entry.remaining) }

    var body: some View {
        let ink = entry.moment.ink
        let soft = entry.moment.inkSoft
        Group {
            switch family {
            case .accessoryInline:
                if let o = entry.occasion {
                    Text(loc("%1$@ %2$@ · %3$@", entry.day.counterText, monthName, o.title))
                } else {
                    Text(fullDate)
                }

            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(fullDate)
                        .font(.system(size: 13, weight: .semibold))
                        .widgetAccentable()
                    if let o = entry.occasion {
                        Text(o.title).font(.system(size: 12)).lineLimit(1)
                        Text(when).font(.system(size: 11)).foregroundStyle(.secondary)
                    } else {
                        Text(entry.weekday).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

            default:
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                        Text(entry.weekday).font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(soft)

                    Text(entry.day.counterText)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [ink, entry.moment.tint],
                                                        startPoint: .top, endPoint: .bottom))
                        .lineLimit(1).minimumScaleFactor(0.7)

                    Text(loc("%1$@ %2$@ هـ", monthName, String(entry.year)))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ink)
                        .lineLimit(1).minimumScaleFactor(0.7)

                    Spacer(minLength: 4)

                    if let o = entry.occasion {
                        HStack(spacing: 7) {
                            Image(systemName: o.icon)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(entry.moment.tint)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(o.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(ink)
                                    .lineLimit(1).minimumScaleFactor(0.7)
                                Text(when)
                                    .font(.system(size: 10))
                                    .foregroundStyle(soft)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "athar://open/calendar"))
    }
}

/// «جارية الآن»، «غدًا»، «بعد يومين»، «بعد 5 أيام» — كما في «اليوم» سواءً بسواء.
private func whenText(_ days: Int) -> String {
    switch days {
    case ...0:   return loc("جارية الآن")
    case 1:      return loc("غدًا")
    case 2:      return loc("بعد يومين")
    case 3...10: return loc("بعد %1$@ أيام", days.counterText)
    default:     return loc("بعد %1$@ يومًا", days.counterText)
    }
}

// MARK: - Widget

struct HijriWidget: Widget {
    private let kind = "AtharHijriWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HijriProvider()) { entry in
            HijriWidgetView(entry: entry)
                .containerBackground(for: .widget) { AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.7) }
        }
        .configurationDisplayName("التقويم الهجري")
        .description("تاريخ اليوم بتقويم أم القرى، والمناسبة القادمة وكم بقي لها.")
        .supportedFamilies([.systemSmall, .accessoryInline, .accessoryRectangular])
    }
}
