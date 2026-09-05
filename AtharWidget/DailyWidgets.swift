import WidgetKit
import SwiftUI

// MARK: - حديث اليوم

struct HadithEntry: TimelineEntry {
    let date: Date
    let hadith: Hadith?
    let moment: AtharStyle.Moment
}

struct HadithProvider: TimelineProvider {
    private func entry(at date: Date) -> HadithEntry {
        HadithEntry(date: date, hadith: HadithLibrary.daily(for: date),
                    moment: .at(date, times: AtharStore.shared.prayerTimes(for: date)))
    }
    func placeholder(in context: Context) -> HadithEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (HadithEntry) -> Void) { completion(entry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HadithEntry>) -> Void) {
        // الحديث يتبدّل مع اليوم: مدخل الآن ومدخل بعد منتصف الليل.
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry(at: now), entry(at: midnight)], policy: .atEnd))
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
                    Text(entry.hadith?.text ?? "").font(.system(size: 12)).lineLimit(3)
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
                    Text(entry.hadith?.text ?? "")
                        .font(.custom("NotoNaskhArabic-Regular", size: family == .systemSmall ? 13 : 15))
                        .foregroundStyle(ink)
                        .lineSpacing(3)
                        .lineLimit(family == .systemSmall ? 5 : (family == .systemMedium ? 5 : 12))
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 0)
                    Text(entry.hadith?.citation ?? "")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(soft)
                        .lineLimit(1)
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
                  moment: .at(date, times: AtharStore.shared.prayerTimes(for: date)))
    }
    func placeholder(in context: Context) -> NameEntry { entry(at: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (NameEntry) -> Void) { completion(entry(at: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NameEntry>) -> Void) {
        let now = Date()
        let midnight = Calendar.current.startOfDay(for: now).addingTimeInterval(86_400)
        completion(Timeline(entries: [entry(at: now), entry(at: midnight)], policy: .atEnd))
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
                        .font(.custom("NotoNaskhArabic-Bold", size: 13))
                        .minimumScaleFactor(0.6).lineLimit(1).padding(4)
                }
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name?.name ?? "").font(.custom("NotoNaskhArabic-Bold", size: 16))
                    Text(entry.name?.meaning ?? "").font(.system(size: 11)).lineLimit(2)
                }
            default:
                VStack(alignment: .leading, spacing: 4) {
                    Text("اسم اليوم").font(.system(size: 12, weight: .semibold)).foregroundStyle(soft)
                    Text(entry.name?.name ?? "")
                        .font(.custom("NotoNaskhArabic-Bold", size: family == .systemSmall ? 30 : 34))
                        .foregroundStyle(ink)
                        .minimumScaleFactor(0.6).lineLimit(1)
                    if family != .systemSmall {
                        Text(entry.name?.meaning ?? "")
                            .font(.custom("NotoNaskhArabic-Regular", size: 14))
                            .foregroundStyle(ink.opacity(0.9))
                            .lineLimit(family == .systemMedium ? 3 : 9)
                            .lineSpacing(2)
                    }
                    Spacer(minLength: 0)
                    if let n = entry.name {
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
                           moment: .at(date, times: store.prayerTimes(for: date)))
    }
    private var fallback: SunnahEntry {
        SunnahEntry(date: Date(), prayer: .fajr, prayerTime: Date(), before: SunanLibrary.before(.fajr), after: [],
                    moment: .at(Date(), times: nil))
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
                        Text("رواتب الصلاة القادمة").font(.system(size: 12, weight: .semibold))
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
