import WidgetKit
import SwiftUI

// MARK: - Timeline

struct KhatmahEntry: TimelineEntry {
    let date: Date
    let active: Bool
    let pagesDone: Int
    let total: Int
    let dayIndex: Int
    let totalDays: Int
    let todayFrom: Int
    let todayTo: Int
    let moment: AtharStyle.Moment
}

struct KhatmahProvider: TimelineProvider {
    private func snapshot(at date: Date) -> KhatmahEntry {
        let s = AtharStore.shared
        let range = s.khatmahActive ? s.khatmahTodayRange : (1...1)
        return KhatmahEntry(
            date: date,
            active: s.khatmahActive,
            pagesDone: s.khatmahPagesDone,
            total: Quran.pageCount,
            dayIndex: s.khatmahDayIndex,
            totalDays: s.khatmahTotalDays,
            todayFrom: range.lowerBound,
            todayTo: range.upperBound,
            moment: .at(date, times: s.prayerTimes(for: date)))
    }

    func placeholder(in context: Context) -> KhatmahEntry {
        KhatmahEntry(date: Date(), active: true, pagesDone: 210, total: 604,
                     dayIndex: 7, totalDays: 30, todayFrom: 205, todayTo: 225, moment: .morning)
    }
    func getSnapshot(in context: Context, completion: @escaping (KhatmahEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : snapshot(at: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<KhatmahEntry>) -> Void) {
        let entry = snapshot(at: Date())
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - View

struct KhatmahWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: KhatmahEntry

    private var fraction: Double {
        entry.total > 0 ? min(1, Double(entry.pagesDone) / Double(entry.total)) : 0
    }
    private var pct: Int { Int((fraction * 100).rounded()) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: fraction) {
                Image(systemName: "book.closed.fill")
            } currentValueLabel: {
                Text("\(pct.counterText)٪")
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("ختمة القرآن").font(.system(size: 11, weight: .semibold)).widgetAccentable()
                if entry.active {
                    Text("\(pct.counterText)٪ · اليوم \(entry.dayIndex.counterText) من \(entry.totalDays.counterText)")
                        .font(.system(size: 13))
                    Text("ورد اليوم: ص \(entry.todayFrom.counterText)–\(entry.todayTo.counterText)")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                } else {
                    Text("ابدأ تحدي الختم").font(.system(size: 13))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

        default: // systemSmall / systemMedium
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(entry.moment.ink.opacity(0.16), lineWidth: 9)
                    let arc = Circle()
                        .trim(from: 0, to: max(0.02, fraction))
                        .stroke(AngularGradient(colors: [entry.moment.tint, entry.moment.tint.opacity(0.55), entry.moment.tint],
                                                center: .center, angle: .degrees(-90)),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    arc.blur(radius: 5).opacity(0.35 + 0.4 * fraction)
                    arc
                    Text("\(pct.counterText)٪")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [entry.moment.ink, entry.moment.tint],
                                                        startPoint: .top, endPoint: .bottom))
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 5) {
                    Text("ختمة القرآن")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(entry.moment.ink)
                    if entry.active {
                        Text("اليوم \(entry.dayIndex.counterText) من \(entry.totalDays.counterText)")
                            .font(.system(size: 12)).foregroundStyle(entry.moment.inkSoft)
                        Text("ورد اليوم: ص \(entry.todayFrom.counterText)–\(entry.todayTo.counterText)")
                            .font(.system(size: 12)).foregroundStyle(entry.moment.tint)
                    } else {
                        Text("ابدأ تحدي الختم وتابع تقدّمك")
                            .font(.system(size: 12)).foregroundStyle(entry.moment.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Widget

struct KhatmahWidget: Widget {
    private let kind = "AtharKhatmahWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: KhatmahProvider()) { entry in
            KhatmahWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.8)
                }
        }
        .configurationDisplayName("ختمة القرآن")
        .description("تقدّمك في الختمة وورد اليوم — على الشاشة الرئيسية أو شاشة القفل.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
