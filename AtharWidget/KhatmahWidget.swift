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
            moment: .resolved(at: date, times: s.prayerTimes(for: date)))
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

        // المربّع الصغير عمودٌ لا صفّ: كان يمرّ من فرع المستطيل، فتأخذ الحلقةُ ٧٤ نقطة
        // من ١٢٦ ولا يبقى للنصّ إلا خمسون — وكلمة «القرآن» وحدها أوسع منها — فتنكسر
        // الكلماتُ حرفًا حرفًا وتنفصل حروف العربية، ويتمدّد العمود خارج الودجة.
        case .systemSmall:
            VStack(spacing: 8) {
                ring(size: 56, number: 17, line: 7)
                VStack(spacing: 2) {
                    Text("ختمة القرآن")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(entry.moment.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    if entry.active {
                        Text("اليوم \(entry.dayIndex.counterText) من \(entry.totalDays.counterText)")
                            .font(.system(size: 10)).foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        Text("ص \(entry.todayFrom.counterText)–\(entry.todayTo.counterText)")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(entry.moment.tint)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    } else {
                        Text("ابدأ ختمتك")
                            .font(.system(size: 11)).foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.layoutDirection, .rightToLeft)

        default: // systemMedium وما فوقه
            HStack(spacing: 16) {
                ring(size: 74, number: 20, line: 9)

                VStack(alignment: .leading, spacing: 5) {
                    Text("ختمة القرآن")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(entry.moment.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if entry.active {
                        Text("اليوم \(entry.dayIndex.counterText) من \(entry.totalDays.counterText)")
                            .font(.system(size: 12)).foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text("ورد اليوم: ص \(entry.todayFrom.counterText)–\(entry.todayTo.counterText)")
                            .font(.system(size: 12)).foregroundStyle(entry.moment.tint)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    } else {
                        Text("ابدأ تحدي الختم وتابع تقدّمك")
                            .font(.system(size: 12)).foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(2).minimumScaleFactor(0.8)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    /// حلقة التقدّم بمقاسٍ يُمرَّر: المربّع الصغير يضيق عن حلقة المستطيل.
    private func ring(size: CGFloat, number: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle().stroke(entry.moment.ink.opacity(0.16), lineWidth: line)
            let arc = Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(AngularGradient(colors: [entry.moment.tint, entry.moment.tint.opacity(0.55), entry.moment.tint],
                                        center: .center, angle: .degrees(-90)),
                        style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
            arc.blur(radius: 5).opacity(0.35 + 0.4 * fraction)
            arc
            Text("\(pct.counterText)٪")
                .font(.system(size: number, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [entry.moment.ink, entry.moment.tint],
                                                startPoint: .top, endPoint: .bottom))
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(width: size, height: size)
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
                // النقر يفتح الختمة نفسها — من الورد إلى صفحته في خطوة واحدة.
                .widgetURL(URL(string: "athar://open/khatmah"))
        }
        .configurationDisplayName("ختمة القرآن")
        .description("تقدّمك في الختمة وورد اليوم — على الشاشة الرئيسية أو شاشة القفل.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
