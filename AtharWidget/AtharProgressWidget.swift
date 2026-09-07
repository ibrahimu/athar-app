import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ProgressEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let total: Int
    let completedToday: Int
    let dailyGoal: Int
    let tasbihCount: Int
    let tasbihTarget: Int
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
            tasbihCount: store.tasbihCount,
            tasbihTarget: store.tasbihTarget,
            moment: .resolved(at: date, times: store.prayerTimes(for: date))
        )
    }

    func placeholder(in context: Context) -> ProgressEntry {
        ProgressEntry(date: Date(), streak: 7, total: 1240, completedToday: 1, dailyGoal: 2,
                      tasbihCount: 19, tasbihTarget: 33, moment: .morning)
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

    /// ما مضى من الشوط الجاري — الرقم الذي تعرضه شاشة المسبحة نفسها.
    private var roundCount: Int { entry.tasbihCount % max(1, entry.tasbihTarget) }

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(loc("أثر · %1$@", streakDays(entry.streak)))

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
                Text(loc("أثر اليوم"))
                    .font(.system(size: 11, weight: .semibold))
                    .widgetAccentable()
                Text(loc("%1$@ من %2$@ أذكار", entry.completedToday.counterText, entry.dailyGoal.counterText))
                    .font(.system(size: 13))
                Text(streakCaption(entry.streak))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .rightToLeft)

        case .systemSmall:
            // المربّع الصغير ضيّق عن عمودين، فالحلقة وعنوانها صفٌّ، والمسبحة تحتهما بعرضها.
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    streakRing(size: 52, numberSize: 19)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("أثرك اليوم"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(entry.moment.ink)
                            .lineLimit(1).minimumScaleFactor(0.8)
                        Text(loc("%1$@ من %2$@ أذكار", entry.completedToday.counterText, entry.dailyGoal.counterText))
                            .font(.system(size: 10))
                            .foregroundStyle(entry.moment.inkSoft)
                            .lineLimit(2).minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: 0)
                tasbihButton {
                    HStack(spacing: 7) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(entry.moment.tint)
                        Text(loc("سبّح"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(entry.moment.ink)
                        Spacer(minLength: 0)
                        Text(roundCount.counterText)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.moment.tint)
                            .contentTransition(.numericText())
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(tasbihShell)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)

        default:
            HStack(spacing: 14) {
                streakRing(size: 74, numberSize: 24)

                VStack(alignment: .leading, spacing: 5) {
                    Text(loc("أثرك اليوم"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(entry.moment.ink)
                    Text(loc("%1$@ من %2$@ أذكار", entry.completedToday.counterText, entry.dailyGoal.counterText))
                        .font(.system(size: 12))
                        .foregroundStyle(entry.moment.inkSoft)
                    Text(loc("%1$@ ذكر بإذن الله", entry.total.counterText))
                        .font(.system(size: 12))
                        .foregroundStyle(entry.moment.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                tasbihButton {
                    VStack(spacing: 3) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(entry.moment.tint)
                        Text(roundCount.counterText)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(entry.moment.ink)
                            .contentTransition(.numericText())
                            .lineLimit(1).minimumScaleFactor(0.6)
                        Text(loc("سبّح"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(entry.moment.inkSoft)
                    }
                    .frame(width: 74, height: 74)
                    .background(tasbihShell)
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
        }
    }

    // MARK: أجزاء

    /// حلقة التتابع: القوس يمتلئ بأذكار اليوم، والرقم في وسطه أيام التتابع.
    private func streakRing(size: CGFloat, numberSize: CGFloat) -> some View {
        ZStack {
            Circle().stroke(entry.moment.ink.opacity(0.16), lineWidth: size > 60 ? 9 : 7)
            let arc = Circle()
                .trim(from: 0, to: max(0.02, fraction))
                .stroke(AngularGradient(colors: [entry.moment.tint, entry.moment.tint.opacity(0.55), entry.moment.tint],
                                        center: .center, angle: .degrees(-90)),
                        style: StrokeStyle(lineWidth: size > 60 ? 9 : 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            arc.blur(radius: 5).opacity(0.35 + 0.4 * fraction)
            arc
            Text(entry.streak.counterText)
                .font(.system(size: numberSize, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [entry.moment.ink, entry.moment.tint],
                                                startPoint: .top, endPoint: .bottom))
                .lineLimit(1).minimumScaleFactor(0.6)
                .padding(.horizontal, 4)
        }
        .frame(width: size, height: size)
        // رقمٌ عارٍ في حلقة: لولا هذا لقرأه الصوتُ «7» لا يدري السامعُ سبعةَ ماذا.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loc("تتابعك"))
        .accessibilityValue(streakCaption(entry.streak))
    }

    /// قِشرة المسبحة: تستطيل كبسولةً في الصفّ وتستدير في المربّع — حدٌّ خافت من لون
    /// اللحظة يُفرد الزرّ عمّا حوله فيُعرف أنه يُضغط.
    private var tasbihShell: some View {
        ZStack {
            Capsule().fill(entry.moment.ink.opacity(0.10))
            Capsule().strokeBorder(entry.moment.tint.opacity(0.38), lineWidth: 0.9)
        }
    }

    /// المسبحة في مكانها: النيّة تُنفَّذ في العملية نفسها فلا يُفتح التطبيق ولا يُقطع الذكر.
    private func tasbihButton<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        Button(intent: TasbihTapIntent(), label: label)
            .buttonStyle(.plain)
            .accessibilityLabel(loc("سبّح"))
            .accessibilityValue(loc("%1$@ من %2$@", roundCount.counterText, entry.tasbihTarget.counterText))
            .accessibilityHint(loc("اضغط مرّتين للعدّ"))
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
                // ما حول زرّ المسبحة يفتح المسبحة نفسها — موضع العدّ الذي تعرضه الودجة.
                .widgetURL(URL(string: "athar://open/tasbih"))
        }
        .configurationDisplayName("أثري")
        .description("تتابعك اليومي ومجموع أذكارك، ومسبحةٌ تعدّ من مكانها.")
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
    case 1:      return loc("يوم واحد")
    case 2:      return loc("يومان")
    case 3...10: return loc("%1$@ أيام", n.counterText)
    default:     return loc("%1$@ يومًا", n.counterText)
    }
}

/// عنوان التتابع في الودجة الكبيرة، بالصفة موافقةً للعدد.
private func streakCaption(_ n: Int) -> String {
    switch n {
    case 0:      return loc("ابدأ تتابعك اليوم")
    case 1:      return loc("يوم واحد متتابع")
    case 2:      return loc("يومان متتابعان")
    case 3...10: return loc("%1$@ أيام متتابعة", n.counterText)
    default:     return loc("%1$@ يومًا متتابعًا", n.counterText)
    }
}
