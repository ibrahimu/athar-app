import WidgetKit
import SwiftUI

// MARK: - مواقيت تبدّل اللوحة

/// كانت ودجات اليوم تُصيَّر مدخلين لا غير — الآن ومنتصفَ الليل — واللوحة تُحسب في
/// المدخل فتلزم ما أدركها عنده: من ركّبها بعد العشاء بقيت زرقاء الليل في ضحاه كلّه،
/// ومن ركّبها ضحًى بقيت خضراء إلى الليل. ولوحةُ AtharStyle.Moment تنقلب عند مطالع
/// الصلوات لا عند منتصف الليل، فيُبَثّ مدخلٌ عند كل مَطلع كما يفعل مدخل الذكر.
private enum PaletteTimeline {
    /// حدود اللحظات ابتداءً من الآن: ما بقي من حدود اليوم، ثم منتصفُ الليل (وعنده
    /// يتبدّل الحديث واسم اليوم)، ثم حدود الغد — فلا تبيت الودجة على لونٍ واحد.
    static func moments(from now: Date) -> [Date] {
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        // الشروق حدٌّ كسائرها وإن لم يكن صلاة: عنده ينقلب الفجرُ صباحًا.
        let edges: [Prayer] = [.fajr, .sunrise, .dhuhr, .asr, .maghrib]
        var ahead: Set<Date> = [midnight]
        for day in [now, midnight] {
            guard let times = AtharStore.shared.prayerTimes(for: day) else { continue }
            for edge in edges { if let d = times[edge] { ahead.insert(d) } }
        }
        return [now] + ahead.filter { $0 > now }.sorted()
    }
}

// MARK: - حديث اليوم

struct HadithEntry: TimelineEntry {
    let date: Date
    let hadith: Hadith?
    let moment: AtharStyle.Moment
}

struct HadithProvider: TimelineProvider {
    private func entry(at date: Date) -> HadithEntry {
        HadithEntry(date: date, hadith: HadithLibrary.daily(for: date),
                    moment: .resolved(at: date, times: AtharStore.shared.prayerTimes(for: date)))
    }
    func placeholder(in context: Context) -> HadithEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (HadithEntry) -> Void) { completion(entry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HadithEntry>) -> Void) {
        // الحديث يتبدّل مع اليوم، واللوحة مع مطالع الصلوات — ومدخلٌ عند كل حدٍّ يكفيهما.
        completion(Timeline(entries: PaletteTimeline.moments(from: Date()).map { entry(at: $0) },
                            policy: .atEnd))
    }
}

struct HadithWidgetView: View {
    let entry: HadithEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let ink = entry.moment.ink
        let soft = entry.moment.inkSoft
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.hadith?.text.prefix(60).description ?? "حديث اليوم")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("حديث اليوم").font(.system(size: 11, weight: .semibold))
                    // متنُ الحديث على القفل شرعيٌّ كمتنه على الشاشة: بخطّ النسخ لا
                    // بخطّ النظام، وإلا خرج تشكيلُه ضعيفًا وفارق جارَه في الحزمة نفسها.
                    Text(entry.hadith?.text ?? "").font(Theme.dhikrFont(fixed: 12)).lineLimit(3)
                }
            case .accessoryCircular:
                ZStack { AccessoryWidgetBackground(); Image(systemName: "quote.opening").font(.system(size: 18, weight: .medium)) }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "quote.opening").font(.system(size: 11, weight: .semibold))
                        Text("حديث اليوم").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(soft)
                    // المربّع الصغير لا يسع خمسة أسطر: ارتفاعه المتاح ١٢٦ نقطة (و١٠٩ على
                    // الشاشات الصغيرة)، ويأخذ منها العنوانُ والفسحاتُ والعزوُ نحو ٤٤. فحدُّ
                    // الأسطر يوافق ما يسعه فعلًا، والخطُّ والتباعد يضيقان له، والعزو يُطوى
                    // عنه — فسطرٌ من الحديث خيرٌ من سطرٍ يقول من رواه.
                    Text(entry.hadith?.text ?? "")
                        .font(Theme.dhikrFont(fixed: family == .systemSmall ? 12 : 15))
                        .foregroundStyle(ink)
                        .lineSpacing(family == .systemSmall ? 1 : 3)
                        .lineLimit(family == .systemSmall ? 4 : (family == .systemMedium ? 5 : 12))
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    if family != .systemSmall {
                        Text(entry.hadith?.citation ?? "")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(soft)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "athar://open/hadith"))
    }
}

struct HadithWidget: Widget {
    private let kind = "AtharHadithWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HadithProvider()) { entry in
            HadithWidgetView(entry: entry)
                .containerBackground(for: .widget) { AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.75) }
        }
        .configurationDisplayName("حديث اليوم")
        .description("حديث من الصحيحين يتجدّد كل يوم — من رياض الصالحين والأربعين النووية.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - اسم اليوم

struct NameEntry: TimelineEntry {
    let date: Date
    let name: DivineName?
    let moment: AtharStyle.Moment
}

struct NameProvider: TimelineProvider {
    private func entry(at date: Date) -> NameEntry {
        NameEntry(date: date, name: NamesLibrary.daily(for: date),
                  moment: .resolved(at: date, times: AtharStore.shared.prayerTimes(for: date)))
    }
    func placeholder(in context: Context) -> NameEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (NameEntry) -> Void) { completion(entry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NameEntry>) -> Void) {
        // اسم اليوم يتبدّل مع اليوم، واللوحة مع مطالع الصلوات — كحديث اليوم سواء.
        completion(Timeline(entries: PaletteTimeline.moments(from: Date()).map { entry(at: $0) },
                            policy: .atEnd))
    }
}

struct NameWidgetView: View {
    let entry: NameEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let ink = entry.moment.ink
        let soft = entry.moment.inkSoft
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.name?.name ?? "الأسماء الحسنى")
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    Text(entry.name?.name ?? "")
                        .font(Theme.naskhFont(fixed: 13, bold: true))
                        .minimumScaleFactor(0.6).lineLimit(1).padding(4)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name?.name ?? "").font(Theme.naskhFont(fixed: 16, bold: true))
                    Text(entry.name?.meaning ?? "").font(.system(size: 11)).lineLimit(2)
                }
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Text("اسم اليوم").font(.system(size: 12, weight: .semibold)).foregroundStyle(soft)
                    // اسمٌ من أسماء الله لا يُقطع في وسطه: أطولها يتجاوز عرض المربّع الصغير
                    // بمعامل ٠٫٦، فيُبدأ به أصغر ويُطلق له التصغير حتى يسعه كاملًا.
                    Text(entry.name?.name ?? "")
                        .font(Theme.naskhFont(fixed: family == .systemSmall ? 26 : 30, bold: true))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(family == .systemSmall ? 0.45 : 0.6).lineLimit(1)
                    if family != .systemSmall {
                        // المستطيل المتوسّط لا يبقى فيه بعد الاسم إلا سطران — وثلاثةٌ تُطلب
                        // فيُبتر أوّلها. فالحدّ يوافق المساحة، والتباعد يُرفع ليتّسع.
                        Text(entry.name?.meaning ?? "")
                            .font(Theme.dhikrFont(fixed: 14))
                            .foregroundStyle(ink.opacity(0.9))
                            .lineLimit(family == .systemMedium ? 2 : 9)
                            .lineSpacing(family == .systemMedium ? 0 : 2)
                    }
                    Spacer(minLength: 0)
                    // سطر المصدر يُطوى عن المتوسّط: مكانُه سطرٌ من الشرح نفسه أولى به.
                    if let n = entry.name, family != .systemMedium {
                        Text(n.source == "السعدي" ? "من كلام الشيخ السعدي" : "شرح موجز")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(soft)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .widgetURL(URL(string: "athar://open/names"))
    }
}

struct NameWidget: Widget {
    private let kind = "AtharNameWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NameProvider()) { entry in
            NameWidgetView(entry: entry)
                .containerBackground(for: .widget) { AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.75) }
        }
        .configurationDisplayName("اسم اليوم")
        .description("اسم من أسماء الله الحسنى كل يوم بشرحه الموجز.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - الراتبة القادمة

struct SunnahEntry: TimelineEntry {
    let date: Date
    let prayer: Prayer
    let prayerTime: Date
    let before: [SunnahPrayer]
    let after: [SunnahPrayer]
    let moment: AtharStyle.Moment
}

struct SunnahProvider: TimelineProvider {
    private func entry(at date: Date) -> SunnahEntry? {
        let store = AtharStore.shared
        // الصلاة القادمة: من مواقيت اليوم، وإن انقضت كلها فمن فجر الغد.
        let tomorrow = date.addingTimeInterval(86_400)
        guard let next = store.prayerTimes(for: date)?.nextPrayer(after: date)
                ?? store.prayerTimes(for: tomorrow)?.nextPrayer(after: date) else { return nil }
        return SunnahEntry(date: date, prayer: next.prayer, prayerTime: next.date,
                           before: SunanLibrary.before(next.prayer), after: SunanLibrary.after(next.prayer),
                           moment: .resolved(at: date, times: store.prayerTimes(for: date)))
    }
    private var fallback: SunnahEntry {
        SunnahEntry(date: Date(), prayer: .fajr, prayerTime: Date(), before: SunanLibrary.before(.fajr), after: [],
                    moment: .resolved(at: Date(), times: nil))
    }
    func placeholder(in context: Context) -> SunnahEntry { entry(at: Date()) ?? fallback }
    func getSnapshot(in context: Context, completion: @escaping (SunnahEntry) -> Void) { completion(placeholder(in: context)) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SunnahEntry>) -> Void) {
        // مدخل لكل صلاة قادمة في الـ٢٤ ساعة: يتبدّل حين يدخل وقت الصلاة.
        var entries: [SunnahEntry] = []
        var cursor = Date()
        for _ in 0..<6 {
            guard let e = entry(at: cursor) else { break }
            entries.append(e)
            cursor = e.prayerTime.addingTimeInterval(60)
        }
        completion(Timeline(entries: entries.isEmpty ? [fallback] : entries, policy: .atEnd))
    }
}

struct SunnahWidgetView: View {
    let entry: SunnahEntry
    @Environment(\.widgetFamily) private var family

    private var line: String {
        let b = entry.before.map { "\($0.rakaat) قبل" }
        let a = entry.after.map { "\($0.rakaat) بعد" }
        let parts = b + a
        return parts.isEmpty ? "لا راتبة" : parts.joined(separator: " · ")
    }

    var body: some View {
        let ink = entry.moment.ink
        let soft = entry.moment.inkSoft
        Group {
            switch family {
            case .accessoryInline:
                Text("\(entry.prayer.title): \(line)")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("رواتب \(entry.prayer.title)").font(.system(size: 11, weight: .semibold))
                    Text(line).font(.system(size: 13, weight: .medium))
                    Text(entry.prayerTime, style: .time).font(.system(size: 11)).monospacedDigit()
                }
            case .accessoryCircular:
                ZStack {
                    AccessoryWidgetBackground()
                    VStack(spacing: 0) {
                        Image(systemName: "rays").font(.system(size: 12, weight: .semibold))
                        Text(entry.before.first?.rakaat ?? entry.after.first?.rakaat ?? "—").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "rays").font(.system(size: 11, weight: .semibold))
                        // العنوان الكامل أعرض من المربّع الصغير فينكسر سطرين ويدفع الحبّات
                        // خارج الودجة — فله في الصغير اسمٌ أقصر، ولا ينكسر في الحالين.
                        Text(family == .systemSmall ? "الرواتب القادمة" : "رواتب الصلاة القادمة")
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1).minimumScaleFactor(0.85)
                    }
                    .foregroundStyle(soft)
                    Text(entry.prayer.title).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(ink)
                    Text(entry.prayerTime, style: .time).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(soft).monospacedDigit()
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        ForEach(entry.before) { s in pill(s, label: "قبل", ink: ink) }
                        ForEach(entry.after) { s in pill(s, label: "بعد", ink: ink) }
                        if entry.before.isEmpty && entry.after.isEmpty {
                            Text("لا راتبة لهذه الصلاة").font(.system(size: 11)).foregroundStyle(soft)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))   // أرقام لاتينية في الوقت كبقية التطبيق
        .widgetURL(URL(string: "athar://open/sunan"))
    }

    private func pill(_ s: SunnahPrayer, label: String, ink: Color) -> some View {
        let strong = s.emphasis == .muakkadah
        return VStack(spacing: 1) {
            Text(s.rakaat).font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label).font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(ink.opacity(strong ? 0.18 : 0.07)))
        .overlay(Capsule().strokeBorder(ink.opacity(strong ? 0 : 0.35), lineWidth: 0.8))
    }
}

struct SunnahWidget: Widget {
    private let kind = "AtharSunnahWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SunnahProvider()) { entry in
            SunnahWidgetView(entry: entry)
                .containerBackground(for: .widget) { AtharStyle.Backdrop(moment: entry.moment, rippleScale: 0.75) }
        }
        .configurationDisplayName("الراتبة القادمة")
        .description("رواتب الصلاة القادمة قبلها وبعدها — ويتبدّل مع كل صلاة.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular, .accessoryCircular])
    }
}
