import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ProgressEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let total: Int
    let completedToday: Int
    let dailyGoal: Int
}

struct ProgressProvider: TimelineProvider {
    private func snapshot(at date: Date) -> ProgressEntry {
        let store = AtharStore.shared
        return ProgressEntry(
            date: date,
            streak: store.displayStreak,
            total: store.totalDhikrCount,
            completedToday: store.completedToday.count,
            dailyGoal: 2 // أذكار الصباح + المساء
        )
    }

    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), streak: 7, total: 1240, completedToday: 1, dailyGoal: 2)
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
            Text("أثر · \(entry.streak.counterText) يوم")

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
                Text("\(entry.streak.counterText) يوم متتابع")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

        default:
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Theme.accent.opacity(0.18), lineWidth: 9)
                    Circle()
                        .trim(from: 0, to: max(0.02, fraction))
                        .stroke(Theme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(entry.streak.counterText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }
                .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 5) {
                    Text("أثرك اليوم")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("\(entry.completedToday.counterText) من \(entry.dailyGoal.counterText) أذكار")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSoft)
                    Text("\(entry.total.counterText) ذكر بإذن الله")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
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
                .containerBackground(for: .widget) { Theme.canvas }
        }
        .configurationDisplayName("أثري")
        .description("تتابعك اليومي ومجموع أذكارك.")
        .supportedFamilies([
            .systemSmall, .systemMedium,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}
