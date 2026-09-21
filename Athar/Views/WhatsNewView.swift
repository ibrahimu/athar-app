import SwiftUI

/// «ما الجديد» — تُعرض مرة واحدة بعد كل تحديث كبير، لأن الإصدار يضيف أقسامًا
/// كاملة لن يكتشفها المستخدم وحده. تُحفظ نسخة العرض في التفضيلات فلا تعود.
struct WhatsNewView: View {
    @EnvironmentObject private var store: AtharStore
    /// يُغلق من الأب (يُعرض تراكبًا لا ورقة: الأوراق المطلوبة لحظة الإقلاع كانت تُهدم فور ظهورها).
    var onClose: () -> Void = {}

    /// يُرفع مع كل إصدار يستحق العرض.
    static let version = "1.6"

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
        .init(id: "athan", icon: "bell.and.waves.left.and.right.fill", accent: "gold", title: "الأذان لا يفوتك",
              // «ذكّرني بعد 10 دقائق» تُنقل كما تقرأها في الإشعار نفسه — والإشعار
              // بالأرقام الغربية كما التطبيق كلّه، فلا يُكتب هنا رقمٌ يخالف ما يراه.
              detail: "يصلك الأذان في وقته ولو كان جهازك في وضع تركيز — وتُطفئ ذلك متى شئت. وفيه «صلّيتها في وقتها» و«ذكّرني بعد 10 دقائق»، ومواعيده مثبّتة على منطقة مكانك لا جهازك.", tab: .prayer),
        .init(id: "ramadan", icon: "moon.stars.fill", accent: "green", title: "رمضان مع أثر",
              detail: "إمساكية الشهر وقضاء الصيام ووردك في صفحة واحدة، بتخصيص يتبع هوية التطبيق.", tab: .ramadan),
        .init(id: "readings", icon: "bookmark.fill", accent: "green", title: "لكل قراءة موضعها",
              detail: "احفظ ختماتك ومراجعاتك بأسماء مستقلة، وابحث وتصفّح دون فقدان موضعها.", tab: .mushaf),
        .init(id: "qiyam", icon: "book.pages.fill", accent: "green", title: "مصحف القيام",
              detail: "القرآن كاملًا في 200 لوحة قابلة للتمرير، بخط قابل للتكبير وسطور مضبوطة الهوامش.", tab: .mushaf),
        .init(id: "sunrise", icon: "sunrise.fill", accent: "green", title: "الشروق في الودجات",
              detail: "موعد الشروق في ودجت الصلاة وودجت مستقل للشاشة الرئيسية وشاشة القفل.", tab: .prayer),
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
                        Text(loc("رمضان وقراءاتك المستقلة ومصحف القيام، بتصميم منسجم مع أثر."))
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
