import SwiftUI

/// الإحصاء الشهري (هجري): الأذكار والصفحات والصلوات في وقتها وجُمَع الكهف — من الدفتر اليومي.
struct StatsView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var year = Occasions.hijriComponents(Date()).year
    @State private var month = Occasions.hijriComponents(Date()).month

    private var tint: Color { Theme.accent(for: "dawn") }
    private var stats: MonthlyStats { store.monthlyStats(year: year, month: month) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                header
                grid
                note
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        .background { AtharBackground(tint: tint, secondary: Theme.gold) }
        .navigationTitle(loc("إحصاء الشهر"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var header: some View {
        HStack {
            // البادئ (يمين الواجهة العربية) هو السابق، والنهائي (يسار) هو التالي — كترتيب التقويم؛ كانا معكوسين فتشير الأسهم إلى الداخل.
            nav("chevron.backward") { shift(-1) }
            Spacer()
            VStack(spacing: 2) {
                Text("\(Occasions.monthName(month)) \(year.counterText)")
                    .font(Theme.display(18, weight: .bold)).foregroundStyle(Theme.ink)
                Text(loc("%1$@ يومًا نشطًا من %2$@", stats.activeDays.counterText, stats.days.counterText))
                    .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            nav("chevron.forward") { shift(1) }
        }
    }

    private func nav(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.snappy) { action() }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 34, height: 34).background(Circle().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "chevron.forward" ? loc("الشهر التالي") : loc("الشهر السابق"))
    }

    private func shift(_ d: Int) {
        var m = month + d, y = year
        if m > 12 { m = 1; y += 1 } else if m < 1 { m = 12; y -= 1 }
        month = m; year = y
    }

    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile("text.book.closed.fill", Theme.accent(for: "sea"), stats.dhikr, loc("ذكرًا وتسبيحة"))
            tile("book.closed.fill", Theme.gold, stats.pages, loc("صفحة من المصحف"))
            tile("checkmark.circle.fill", Theme.accent(for: "green"), stats.prayersOnTime, loc("صلاة في وقتها"))
            tile("sun.max.fill", Theme.accent(for: "dusk"), stats.kahfFridays, loc("جمعة قرأت فيها الكهف"))
            tile("flame.fill", Theme.accent(for: "dawn"), stats.bestDayDhikr, loc("أعلى يوم ذكرًا"))
            tile("calendar", Theme.accent(for: "night"), stats.activeDays, loc("يوم نشط"))
        }
    }

    private func tile(_ icon: String, _ color: Color, _ value: Int, _ label: String) -> some View {
        AtharCard(padding: 14, tint: color) {
            VStack(alignment: .leading, spacing: 6) {
                IconChip(icon: icon, tint: color, size: .sm)
                Text(value.counterText)
                    .font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                    .monospacedDigit().contentTransition(.numericText())
                Text(label).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var note: some View {
        Text(loc("يُحصى ما تفعله داخل التطبيق فقط، ويبقى على جهازك."))
            .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
    }
}
