import SwiftUI

/// «ما الجديد» — تُعرض مرة واحدة بعد كل تحديث كبير، لأن الإصدار يضيف أقسامًا
/// كاملة لن يكتشفها المستخدم وحده. تُحفظ نسخة العرض في التفضيلات فلا تعود.
struct WhatsNewView: View {
    @EnvironmentObject private var store: AtharStore
    /// يُغلق من الأب (يُعرض تراكبًا لا ورقة: الأوراق المطلوبة لحظة الإقلاع كانت تُهدم فور ظهورها).
    var onClose: () -> Void = {}

    /// يُرفع مع كل إصدار يستحق العرض.
    static let version = "1.7"

    struct Item: Identifiable {
        let id: String
        let icon: String
        let accent: String
        let title: String
        let detail: String
        let tab: AppTab?
    }

    /// نصوصُ البطاقات ساكنةٌ ومكشوفةٌ للاختبار: أرقامُها غربيةٌ كأرقام التطبيق كلّه،
    /// وهذا شرطٌ يُحرَس لا يُتذكَّر — الرقم الهنديّ هنا يخالف ما يقرؤه المستخدم في
    /// الإشعار نفسه وفي كل عدّادٍ في التطبيق.
    static let items: [Item] = [
        .init(id: "travel", icon: "airplane", accent: "sea", title: "وضع السفر",
              detail: "ركعتان في الرباعية، ويمكنك جمع الظهر مع العصر والمغرب مع العشاء — فيصلك أذان واحد للصلاتين بدل اثنين. تشغّله بيدك، ويعرض عليك حين تتغيّر منطقتك الزمنية.", tab: .prayer),
        .init(id: "fridayColor", icon: "sparkles", accent: "gold", title: "لون خاص ليوم الجمعة",
              detail: "اختر لونًا يلبسه أثر يوم الجمعة وحده، ويرجع لونك بعده — ومعه الودجات والساعة.", tab: .settings),
        .init(id: "fridayWidget", icon: "calendar.badge.clock", accent: "gold", title: "ودجت الجمعة",
              detail: "سنن الجمعة وحصيلتها وساعة الإجابة، وكم بقي على الجمعة سائر الأسبوع. وتذكيراتها صارت ثلاثة في مواضعها من النهار.", tab: .friday),
        .init(id: "wide", icon: "rectangle.split.2x1.fill", accent: "green", title: "الشاشات العريضة",
              detail: "على الآيباد: شاشة اليوم والصلاة وفهرسا السور والأذكار في عمودين بدل عمود واحد يترك نصف الشاشة فارغًا.", tab: .home),
        .init(id: "updates", icon: "arrow.down.circle.fill", accent: "dusk", title: "لا تبقى على نسخة قديمة",
              detail: "يسألك أثر عن التحديث في الخلفية أيضًا، فيبلغك أن فيه جديدًا ولو لم تفتحه.", tab: nil),
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
                        Text(loc("وضع السفر، ولون الجمعة، وودجتها — والشاشات العريضة في عمودين."))
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 22)

                    SettingsCard {
                        ForEach(Array(Self.items.enumerated()), id: \.element.id) { i, item in
                            Button {
                                onClose()
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
                            if i < Self.items.count - 1 { SettingsDivider() }
                        }
                    }

                    Button {
                        onClose()
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
