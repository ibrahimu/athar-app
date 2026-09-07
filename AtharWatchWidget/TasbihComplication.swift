import WidgetKit
import SwiftUI

// MARK: - مضاعفة عدّاد المسبحة اليومي (واجهة الساعة)

struct TasbihComplicationEntry: TimelineEntry {
    let date: Date
    let count: Int
    let goal: Int
}

struct TasbihComplicationProvider: TimelineProvider {
    private func entry(at date: Date) -> TasbihComplicationEntry {
        let store = AtharStore.shared
        // هدف اليوم يتبع هدف الجولة الذي اختاره صاحبها: ثلاثٌ وثلاثون ثلاثًا كتسبيح دبر الصلاة.
        return .init(date: date, count: store.ledger(for: date).dhikr, goal: max(1, store.tasbihTarget * 3))
    }
    private var fallback: TasbihComplicationEntry {
        .init(date: Date(), count: 0, goal: 99)
    }
    func placeholder(in context: Context) -> TasbihComplicationEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (TasbihComplicationEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TasbihComplicationEntry>) -> Void) {
        var entries = [entry(at: Date())]
        // العدّ لا يتحرّك بالوقت بل بالتسبيح — تجديدُه على WatchSyncReceiver متى هدأت اليد.
        // ولا ينتظر الجدولُ إلا منتصف الليل: دفترٌ جديد وعدٌّ من الصفر.
        if let midnight = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 0),
                                                   matchingPolicy: .nextTime) {
            entries.append(.init(date: midnight, count: 0, goal: entries[0].goal))
        }
        completion(Timeline(entries: entries.isEmpty ? [fallback] : entries, policy: .atEnd))
    }
}

struct TasbihComplicationView: View {
    let entry: TasbihComplicationEntry
    @Environment(\.widgetFamily) private var family

    /// الأرقام غربية دائمًا: counterText يبنيها بمعزل عن لغة الجهاز.
    private var counted: String { entry.count.counterText }
    private var progress: Double { min(1, Double(entry.count) / Double(max(1, entry.goal))) }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("المسبحة \(counted)")
        default: // circular
            ZStack {
                AccessoryWidgetBackground()
                // مقياس دائري: نصيب ما سُبّح اليوم من هدفه
                Gauge(value: progress, in: 0...1) {
                    Image(systemName: "circle.hexagongrid.fill")
                } currentValueLabel: {
                    VStack(spacing: -2) {
                        Image(systemName: "circle.hexagongrid.fill").font(.system(size: 10, weight: .semibold))
                        Text(counted).font(.system(size: 13, weight: .bold, design: .rounded)).minimumScaleFactor(0.6)
                    }
                }
                .gaugeStyle(.accessoryCircular)
            }
            .accessibilityLabel("تسبيح اليوم")
            .accessibilityValue("\(counted) من \(entry.goal.counterText)")
        }
    }
}

struct TasbihComplication: Widget {
    /// المفتاح نفسه الذي يُنعش به تطبيق الساعة الجدولَ بعد العدّ.
    private let kind = "AtharWatchTasbih"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TasbihComplicationProvider()) { entry in
            TasbihComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("عدّاد المسبحة")
        .description("ما سُبّح اليوم ونصيبه من هدفه على واجهة الساعة.")
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}
