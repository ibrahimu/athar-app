import SwiftUI

/// «ما الجديد» — تُعرض مرة واحدة بعد كل تحديث كبير، لأن الإصدار يضيف أقسامًا
/// كاملة لن يكتشفها المستخدم وحده. تُحفظ نسخة العرض في التفضيلات فلا تعود.
struct WhatsNewView: View {
    @EnvironmentObject private var store: AtharStore
    /// يُغلق من الأب (يُعرض تراكبًا لا ورقة: الأوراق المطلوبة لحظة الإقلاع كانت تُهدم فور ظهورها).
    var onClose: () -> Void = {}

    /// يُرفع مع كل إصدار يستحق العرض.
    static let version = "1.5"

    private struct Item: Identifiable {
        let id: String
        let icon: String
        let accent: String
        let title: String
        let detail: String
        let tab: AppTab?
    }

    private let items: [Item] = [
        .init(id: "athan", icon: "bell.and.waves.left.and.right.fill", accent: "gold", title: "الأذان لا يفوتك",
              detail: "يصلك الأذان في وقته ولو كان جهازك في وضع تركيز — وتُطفئ ذلك متى شئت. وفيه «صلّيتها في وقتها» و«ذكّرني بعد ١٠ دقائق»، ومواعيده مثبّتة على منطقة مكانك لا جهازك.", tab: .prayer),
        .init(id: "friday", icon: "sun.max.fill", accent: "gold", title: "يوم الجمعة في مكان واحد",
              detail: "سبع سنن تُعلّمها كلٌّ بدليلها، وسورة الكهف صفحةً أو آيةً آية، وعدّاد الصلاة على النبي ﷺ، وبطاقات جمعة تُشارك.", tab: .friday),
        .init(id: "khatmah-dua", icon: "hands.sparkles.fill", accent: "gold", title: "دعاء الختمة",
              detail: "مواضع الدعاء في القرآن نفسه تُقرأ إذا ختمت — من خاتمة الناس، ومن بطاقة تمام الختمة، ومن باب المصحف.", tab: .mushaf),
        .init(id: "jump", icon: "arrow.uturn.forward.circle.fill", accent: "sea", title: "الانتقال إلى صفحة أو جزء",
              detail: "اكتب الرقم في بحث المصحف فتنتقل إليه، أو اضغط شريط الموضع في القارئ — بلا تقريبٍ ولا سحب.", tab: .mushaf),
        .init(id: "notes", icon: "square.and.pencil", accent: "dusk", title: "تدبّراتي",
              detail: "ملاحظة خاصة على أي آية، وعلامة خافتة عند رقمها، وصفحة تجمعها كلها.", tab: .mushaf),
        .init(id: "ipad", icon: "ipad.landscape", accent: "sea", title: "المصحف على الآيباد",
              detail: "صفحتان متقابلتان تُقلَّبان معًا كالمصحف حين يُفتح، أو صفحة، أو صفحة مع التفسير.", tab: .mushaf),
        .init(id: "search", icon: "magnifyingglass", accent: "calm", title: "بحث واحد لكل شيء",
              detail: "آية وحديثًا وذكرًا واسمًا وحكمًا وسورة من حقل واحد.", tab: .mushaf),
        .init(id: "icons", icon: "app.badge", accent: "dusk", title: "أيقونة التطبيق بلونك",
              detail: "اثنتا عشرة أيقونة بالرسم نفسه — تتبع طابعك أو تختارها مستقلة، ولون الودجت بيدك.", tab: .settings),
        .init(id: "tasbih-widget", icon: "circle.grid.3x3.fill", accent: "green", title: "مسبحة في الودجة",
              detail: "تعدّ بضغطة من الشاشة الرئيسية وتُصفَّر من مكانها، وودجة للتاريخ الهجري وأخرى للذكر.", tab: .tasbih),
        .init(id: "cards", icon: "photo.on.rectangle.angled", accent: "gold", title: "بطاقات تصمّمها",
              detail: "شكلٌ ولونٌ ونقشٌ وخط — ومنها «لوحة» مؤطَّرة، وملصقٌ شفّاف تضعه فوق صورتك في سناب وإكس.", tab: .phrases),
        .init(id: "khatmah-plan", icon: "calendar.badge.clock", accent: "gold", title: "خطة ختمة بموعد",
              detail: "تختار يوم الختم فيوزّع الورد ويذكّرك به، وتضبط التاريخ الهجري ليوافق تقويم بلدك.", tab: .khatmah),
        .init(id: "siri-watch", icon: "applewatch", accent: "green", title: "سيري والساعة",
              detail: "«سجّل صلاة الظهر» و«أين ختمتي» بلا فتح التطبيق، وعدّ المسبحة بالتاج الرقمي.", tab: nil),
        .init(id: "carplay", icon: "car.fill", accent: "sea", title: "CarPlay — القرآن في الطريق",
              detail: "ما كنت تسمعه، والإذاعة بضغطة، وسورٌ للطريق، وما نزّلته يعمل بلا شبكة. بلا بحثٍ ولا تصفّح.", tab: .recitation),
        .init(id: "fixes", icon: "checkmark.seal.fill", accent: "sea", title: "وإصلاحات كثيرة",
              detail: "المصحف يفتح على الصفحة التي يقولها، والإعدادات لا تُطوى مع تبديل الخط، والتلاوة تقول تعذّرها بدل أن تصمت، ونصوص الودجات لا تنكسر.", tab: nil),
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
                        Text(loc("الجمعة ودعاء الختمة وتدبّراتك، وتنبيهاتٌ لا يفوتك معها الأذان، وإصلاحاتٌ كثيرة."))
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 22)

                    SettingsCard {
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
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
                            if i < items.count - 1 { SettingsDivider() }
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
