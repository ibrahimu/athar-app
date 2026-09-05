import SwiftUI

/// «ما الجديد» — تُعرض مرة واحدة بعد كل تحديث كبير، لأن الإصدار يضيف أقسامًا
/// كاملة لن يكتشفها المستخدم وحده. تُحفظ نسخة العرض في التفضيلات فلا تعود.
struct WhatsNewView: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    /// يُرفع مع كل إصدار يستحق العرض.
    static let version = "1.2"

    private struct Item: Identifiable {
        let id: String
        let icon: String
        let accent: String
        let title: String
        let detail: String
        let tab: AppTab?
    }

    private let items: [Item] = [
        .init(id: "tafsir", icon: "text.book.closed.fill", accent: "sea", title: "التفسير لكل آية",
              detail: "السعدي والجلالين — انقر أي آية في المصحف ثم «التفسير».", tab: .mushaf),
        .init(id: "hadith", icon: "quote.opening", accent: "sea", title: "الحديث",
              detail: "رياض الصالحين والأربعون النووية، وحديث اليوم في الرئيسية.", tab: .hadith),
        .init(id: "names", icon: "sparkle", accent: "dusk", title: "الأسماء الحسنى",
              detail: "التسعة والتسعون بشرح موجز من كلام الشيخ السعدي.", tab: .names),
        .init(id: "ahkam", icon: "list.bullet.clipboard.fill", accent: "green", title: "الأحكام العملية",
              detail: "الطهارة والصلاة والصيام والجنازة والاستخارة بدليلها.", tab: .ahkam),
        .init(id: "sunan", icon: "rays", accent: "dawn", title: "السنن الرواتب",
              detail: "يومك مع الرواتب والوتر والضحى على خطّ زمني.", tab: .sunan),
        .init(id: "tools", icon: "wrench.and.screwdriver.fill", accent: "calm", title: "أدوات",
              detail: "الزكاة، التقويم الهجري، سجل الصلاة، وتنبيه قبل الأذان والإقامة.", tab: .calendar),
        .init(id: "custom", icon: "slider.horizontal.3", accent: "gold", title: "رتّبه على كيفك",
              detail: "أي قسم يصلح تبويبًا في الشريط، وبطاقات «اليوم» تُرتَّب وتُخفى.", tab: .settings),
    ]

    var onOpen: ((AppTab) -> Void)? = nil

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 8) {
                        IconChip(icon: "sparkles", tint: Theme.gold, size: .lg)
                        Text(loc("جديد أثر %1$@", Self.version))
                            .font(Theme.display(24, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(loc("سبعة أقسام جديدة، وكلها من مصادر أهل السنّة وبلا إنترنت."))
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 22)

                    SettingsCard {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            Button {
                                dismiss()
                                if let tab = item.tab { onOpen?(tab) }
                            } label: {
                                SettingsRow(icon: item.icon, tint: Theme.accent(for: item.accent),
                                            title: item.title, subtitle: item.detail) {
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.inkFaint)
                                }
                            }
                            .buttonStyle(.plain)
                            .appearStagger(i)
                            if i < items.count - 1 { SettingsDivider() }
                        }
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(loc("ابدأ"))
                            .font(Theme.display(16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .gradientButton(Theme.goldGradient, glow: Theme.gold)
                    }
                    .pressable()
                    .padding(.top, 4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
        }
    }
}
