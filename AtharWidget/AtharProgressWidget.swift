import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ProgressEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let total: Int
    let completedToday: Int
    let dailyGoal: Int
    let moment: AtharStyle.Moment
}

struct ProgressProvider: TimelineProvider {
    private func snapshot(at date: Date) -> ProgressEntry {
        let store = AtharStore.shared
        return ProgressEntry(
            date: date,
            streak: store.displayStreak,
            total: store.totalDhikrCount,
            completedToday: store.completedToday.count,
            dailyGoal: 2, // أذكار الصباح + المساء
            moment: .at(date, times: store.prayerTimes(for: date))
        )
    }

    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), streak: 7, total: 1240, completedToday: 1, dailyGoal: 2, moment: .morning)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProgressEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : snapshot(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProgressEntry>) -> Void) {
        let entry = snapshot(at: Date())
        let refresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }
}

// MARK: - Views

struct ProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ProgressEntry

    private var fraction: Double {
        guard entry.dailyGoal > 0 else { return 0 }
        return min(1, Double(entry.completedToday) / Double(entry.dailyGoal))
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("أثر · \(streakDays(entry.streak))")

        case .accessoryCircular:
            Gauge(value: fraction) {
                Image(systemName: "flame.fill")
            } currentValueLabel: {
                Text(entry.streak.counterText)
            }
            .gaugeStyle(.accessoryCircular)
            .widgetAccentable()

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("أثر اليوم")
                    .font(.system(size: 11, weight: .semibold))
                    .widgetAccentable()
                Text("\(entry.completedToday.counterText) من \(entry.dailyGoal.counterText) أذكار")
                    .font(.system(size: 13))
                Text(streakCaption(entry.streak))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

        default:
            HStack(spacing: 14) {
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
                    Text(entry.streak.counterText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [entry.moment.ink, entry.moment.tint],
                                                        startPoint: .top, endPoint: .bottom))
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 5) {
                    Text("أثرك اليوم")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(entry.moment.ink)
                    Text("\(entry.completedToday.counterText) من \(entry.dailyGoal.counterText) أذكار")
                        .font(.system(size: 12))
                        .foregroundStyle(entry.moment.inkSoft)
                    Text("\(entry.total.counterText) ذكر بإذن الله")
                        .font(.system(size: 12))
                        .foregroundStyle(entry.moment.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

// MARK: - Widget

struct AtharProgressWidget: Widget {
    private let kind = "AtharProgressWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProgressProvider()) { entry in
            ProgressWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.8)
                }
        }
        .configurationDisplayName("أثري")
        .description("تتابعك اليومي ومجموع أذكارك.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}

// MARK: - تمييز العدد للأيام

/// «يوم واحد»، «يومان»، «٣ أيام»، «١١ يومًا» — لا «12 يوم».
private func streakDays(_ n: Int) -> String {
    switch n {
    case 1:      return "يوم واحد"
    case 2:      return "يومان"
    case 3...10: return "\(n.counterText) أيام"
    default:     return "\(n.counterText) يومًا"
    }
}

/// عنوان التتابع في الودجة الكبيرة، بالصفة موافقةً للعدد.
private func streakCaption(_ n: Int) -> String {
    switch n {
    case 0:      return "ابدأ تتابعك اليوم"
    case 1:      return "يوم واحد متتابع"
    case 2:      return "يومان متتابعان"
    case 3...10: return "\(n.counterText) أيام متتابعة"
    default:     return "\(n.counterText) يومًا متتابعًا"
    }
}
