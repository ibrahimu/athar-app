import WidgetKit
import SwiftUI

// MARK: - مضاعفة الذكر (واجهة الساعة)

struct DhikrComplicationEntry: TimelineEntry {
    let date: Date
    let text: String
    let reference: String
}

struct DhikrComplicationProvider: TimelineProvider {
    private func entry(at date: Date) -> DhikrComplicationEntry? {
        guard let d = WatchWidgetAdhkar.at(date) else { return nil }
        return .init(date: date, text: d.text, reference: d.reference)
    }
    /// لا نخترع ذكرًا حين يعزّ الملف — اسم التطبيق وحده أصدق من نصٍّ مكتوبٍ هنا.
    private var fallback: DhikrComplicationEntry {
        .init(date: Date(), text: "أثر", reference: "")
    }
    func placeholder(in context: Context) -> DhikrComplicationEntry { entry(at: Date()) ?? fallback }
    func getSnapshot(in context: Context, completion: @escaping (DhikrComplicationEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DhikrComplicationEntry>) -> Void) {
        var entries: [DhikrComplicationEntry] = []
        var cursor = Date()
        for _ in 0..<8 {
            guard let e = entry(at: cursor) else { break }
            entries.append(e)
            cursor = WatchWidgetAdhkar.nextSlot(after: cursor)
        }
        completion(Timeline(entries: entries.isEmpty ? [fallback] : entries, policy: .atEnd))
    }
}

struct DhikrComplicationView: View {
    let entry: DhikrComplicationEntry
    @Environment(\.widgetFamily) private var family

    /// صدر الذكر للسطر المفرد — يُقتطع أوّله ولا يُزاد عليه حرف.
    static func inlineHead(_ text: String) -> String {
        if let comma = text.firstIndex(of: "،") {
            let head = String(text[text.startIndex..<comma])
            if head.count >= 6 { return head }
        }
        guard text.count > 22 else { return text }
        let cut = text.index(text.startIndex, offsetBy: 22)
        if let space = text[text.startIndex..<cut].lastIndex(of: " ") {
            return String(text[text.startIndex..<space])
        }
        return String(text[text.startIndex..<cut])
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            // السطر المفرد يفرضه النظام بخطّه ومقاسه — لا يقبل نسخًا ولا تنسيقًا،
            // ولا يسع إلا خُمس الذكر، فكان يُبتر في وسط الدعاء. فيُدفع إليه صدرُه
            // إلى أوّل فاصلة: جملةٌ تامّة أولى من نصفٍ مقطوع بـ«…».
            Text(Self.inlineHead(entry.text))
        default: // rectangular
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.text)
                    .font(WatchNaskh.font(13))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
                if !entry.reference.isEmpty {
                    Text(entry.reference)
                        .font(WatchNaskh.font(10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
}

struct DhikrComplication: Widget {
    private let kind = "AtharWatchDhikr"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DhikrComplicationProvider()) { entry in
            DhikrComplicationView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("ذكر")
        .description("ذكرٌ يتجدّد كل نصف ساعة على واجهة الساعة.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}
