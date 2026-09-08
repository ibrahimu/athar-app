import WidgetKit
import SwiftUI

// MARK: - Timeline

struct DhikrEntry: TimelineEntry {
    let date: Date
    let dhikr: Dhikr
    let categoryTitle: String
    /// معرّف الباب حين يختاره صاحب الودجة — به تفتح على بابه لا على رأس الأذكار.
    let categoryId: String?
    let moment: AtharStyle.Moment

    /// من الودجة إلى موضعها من التطبيق: الباب المختار إن كان، وإلا الأذكار جملةً.
    var url: URL? {
        URL(string: categoryId.map { "athar://open/adhkar/\($0)" } ?? "athar://open/adhkar")
    }
}

struct DhikrProvider: AppIntentTimelineProvider {
    /// Rotation pool: short, self-contained adhkar that read well small.
    /// وفي الباب المختار: قصاره وحدها بميزان المكتبة نفسه — فإن لم يكن فيه قصير عُرض على طوله.
    private func pool(for section: DhikrSectionChoice) -> [Dhikr] {
        guard let category = section.category else {
            let short = AdhkarLibrary.shortItems
            return short.isEmpty ? AdhkarLibrary.allItems : short
        }
        let ids = Set(category.items.map(\.id))
        let short = AdhkarLibrary.shortItems.filter { ids.contains($0.id) }
        return short.isEmpty ? category.items : short
    }

    private func dhikr(at date: Date, section: DhikrSectionChoice) -> Dhikr {
        let items = pool(for: section)
        guard !items.isEmpty else {
            return Dhikr(id: "fallback", text: "سُبْحَانَ اللهِ وَبِحَمْدِهِ",
                         count: 1, reference: "متفق عليه", virtue: "")
        }
        // New dhikr every 30 minutes, stable across widget reloads.
        let slot = Int(date.timeIntervalSince1970 / 1800)
        return items[abs(slot) % items.count]
    }

    private func category(for dhikr: Dhikr) -> String {
        AdhkarLibrary.categories.first { $0.items.contains(where: { $0.id == dhikr.id }) }?.title ?? "أثر"
    }

    private func entry(at date: Date, section: DhikrSectionChoice) -> DhikrEntry {
        let d = dhikr(at: date, section: section)
        return DhikrEntry(date: date, dhikr: d,
                          categoryTitle: section.category?.title ?? category(for: d),
                          categoryId: section.category?.id,
                          moment: .resolved(at: date, times: AtharStore.shared.prayerTimes(for: date)))
    }

    func placeholder(in context: Context) -> DhikrEntry {
        entry(at: Date(), section: .auto)
    }

    func snapshot(for configuration: DhikrWidgetIntent, in context: Context) async -> DhikrEntry {
        entry(at: Date(), section: configuration.section)
    }

    func timeline(for configuration: DhikrWidgetIntent, in context: Context) async -> Timeline<DhikrEntry> {
        let now = Date()
        // Twelve half-hour slots — six hours of content per refresh.
        let entries = (0..<12).map { entry(at: now.addingTimeInterval(Double($0) * 1800), section: configuration.section) }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Views

struct DhikrWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DhikrEntry

    /// صدر الذكر للسطر المفرد: ما قبل أوّل فاصلةٍ عربية، وإلا أوّل ما يسع سطرًا
    /// بحدّ كلمة. النصّ لا يُعدَّل — يُقتطع أوّله فقط، ولا يُضاف إليه حرف.
    static func inlineHead(_ text: String) -> String {
        if let comma = text.firstIndex(of: "،") {
            let head = String(text[text.startIndex..<comma])
            if head.count >= 8 { return head }
        }
        guard text.count > 34 else { return text }
        let cut = text.index(text.startIndex, offsetBy: 34)
        if let space = text[text.startIndex..<cut].lastIndex(of: " ") {
            return String(text[text.startIndex..<space])
        }
        return String(text[text.startIndex..<cut])
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            // سطرٌ واحد يفرضه النظام: الذكر كاملًا يُبتر في وسطه بـ«…»، فيُدفع إليه
            // صدرُه إلى أوّل فاصلة — جملةٌ تامّة تُقرأ خيرٌ من نصف جملة مقطوعة.
            Text(DhikrWidgetView.inlineHead(entry.dhikr.text))

        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
                    Text(loc("ذِكر")).font(.system(size: 11, weight: .semibold))
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
        AppIntentConfiguration(kind: kind, intent: DhikrWidgetIntent.self, provider: DhikrProvider()) { entry in
            DhikrWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.75)
                }
                // إلى الباب المختار حين يُختار، وإلا فإلى الأذكار جملةً كما كانت.
                .widgetURL(entry.url)
        }
        .configurationDisplayName("ذِكر")
        .description("ذكر يتجدّد على مدار اليوم — من الأبواب كلّها أو من بابٍ تختاره.")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
    }
}
