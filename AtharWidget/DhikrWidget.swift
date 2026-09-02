import WidgetKit
import SwiftUI

// MARK: - Timeline

struct DhikrEntry: TimelineEntry {
    let date: Date
    let dhikr: Dhikr
    let categoryTitle: String
    let moment: AtharStyle.Moment
}

struct DhikrProvider: TimelineProvider {
    /// Rotation pool: short, self-contained adhkar that read well small.
    private var pool: [Dhikr] {
        let short = AdhkarLibrary.shortItems
        return short.isEmpty ? AdhkarLibrary.allItems : short
    }

    private func dhikr(at date: Date) -> Dhikr {
        guard !pool.isEmpty else {
            return Dhikr(id: "fallback", text: "سُبْحَانَ اللهِ وَبِحَمْدِهِ",
                         count: 1, reference: "متفق عليه", virtue: "")
        }
        // New dhikr every 30 minutes, stable across widget reloads.
        let slot = Int(date.timeIntervalSince1970 / 1800)
        return pool[abs(slot) % pool.count]
    }

    private func category(for dhikr: Dhikr) -> String {
        AdhkarLibrary.categories.first { $0.items.contains(where: { $0.id == dhikr.id }) }?.title ?? "أثر"
    }

    func placeholder(in context: Context) -> DhikrEntry {
        let d = dhikr(at: Date())
        return DhikrEntry(date: Date(), dhikr: d, categoryTitle: category(for: d),
                          moment: .at(Date(), times: AtharStore.shared.prayerTimes()))
    }

    func getSnapshot(in context: Context, completion: @escaping (DhikrEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DhikrEntry>) -> Void) {
        var entries: [DhikrEntry] = []
        let now = Date()
        // Twelve half-hour slots — six hours of content per refresh.
        for offset in 0..<12 {
            let date = now.addingTimeInterval(Double(offset) * 1800)
            let d = dhikr(at: date)
            entries.append(DhikrEntry(date: date, dhikr: d, categoryTitle: category(for: d),
                                      moment: .at(date, times: AtharStore.shared.prayerTimes(for: date))))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Views

struct DhikrWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DhikrEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.dhikr.text)

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
                    Text("ذِكر").font(.system(size: 11, weight: .semibold))
                }
            }

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.categoryTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .widgetAccentable()
                Text(entry.dhikr.text)
                    .font(.system(size: 13))
                    .lineLimit(3)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

        case .systemSmall:
            homeCard(textSize: 15, lines: 5, showFooter: false)

        case .systemLarge:
            homeCard(textSize: 24, lines: 10, showFooter: true)

        default: // systemMedium
            homeCard(textSize: 19, lines: 5, showFooter: true)
        }
    }

    private func homeCard(textSize: CGFloat, lines: Int, showFooter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Circle()
                    .fill(entry.moment.tint)
                    .frame(width: 5, height: 5)
                Text(entry.categoryTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(entry.moment.tint)
                Spacer()
            }

            Text(entry.dhikr.text)
                .font(.system(size: textSize))
                .foregroundStyle(entry.moment.ink)
                .lineSpacing(7)
                .lineLimit(lines)
                .minimumScaleFactor(0.55)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

            if showFooter, entry.dhikr.hasReference {
                Text(entry.dhikr.reference)
                    .font(.system(size: 9))
                    .foregroundStyle(entry.moment.inkSoft)
                    .lineLimit(1)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Widget

struct DhikrWidget: Widget {
    private let kind = "AtharDhikrWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DhikrProvider()) { entry in
            DhikrWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.75)
                }
        }
        .configurationDisplayName("ذِكر")
        .description("ذكر يتجدّد على مدار اليوم — على الشاشة الرئيسية أو شاشة القفل.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}
