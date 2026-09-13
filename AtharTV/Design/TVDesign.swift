import SwiftUI

// MARK: - سلّم الشاشة الكبيرة
//
// `Theme.display` و`Theme.scaled` مبنيّان على «الحجم الديناميكي»، ولا وجود له
// على tvOS: `Theme.scaled` تعيد ما أُعطيت كما هو، فـ`Theme.display(17)` تعني
// سبعَ عشرةَ نقطةً حقيقيةً على شاشةِ خمسٍ وستّين بوصة — أي لا شيء يُقرأ.
//
// فكلُّ حجمٍ في هذا الهدف يمرّ من هنا، ولا يُكتب رقمٌ في موضعه. والمقياسُ من
// مسافة النظر: ثلاثةُ أمتار لا ثلاثون سنتيمترًا.
enum TVType {
    /// عنوانُ شاشة — يُقرأ من آخر الغرفة.
    static let hero: CGFloat = 56
    /// عنوانُ بطاقة.
    static let title: CGFloat = 44
    /// نصٌّ عاديّ.
    static let body: CGFloat = 32
    /// سطرُ خدمةٍ تحت العنوان.
    static let caption: CGFloat = 26
    /// أصغرُ ما يُكتب: اسمُ مصدرٍ أو تاريخ.
    static let footnote: CGFloat = 24

    /// الساعةُ والعدّ التنازلي — أكبرُ ما في الشاشة لأنه المقصود بالنظر.
    static let clock: CGFloat = 120
}

/// حوافُّ الأمان في tvOS ليست اصطلاحًا بل ضرورة: حوافُّ التلفاز تُقصّ فعلًا
/// (overscan) على كثيرٍ من الأجهزة، وما وُضع فيها لا يراه صاحبُه.
enum TVSafe {
    static let horizontal: CGFloat = 90
    static let vertical: CGFloat = 60
}

// MARK: - الأرض

/// أرضُ الشاشة: لونُ الطابع وسَحبةُ ضوءٍ في أعلى الجهة الرائدة. ساكنةٌ تمامًا —
/// «لا حركة للزينة» قاعدةُ `Motion` في هذا المشروع، وشاشةٌ تبقى ساعاتٍ أولى
/// بها من غيرها.
struct TVGround<Content: View>: View {
    @ObservedObject private var prefs = TVPrefs.shared
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()
            Theme.accentSheen
                .opacity(0.35)
                .ignoresSafeArea()
            // النقشُ المختار. كان يُرسم في مربّع الإعدادات ولا يصل الأرضَ أصلًا،
            // فبدا الاختيارُ بلا أثر. والطابعُ يُمرَّر قيمةً ليُعاد الرسمُ عند تبديله.
            TVPattern(pattern: prefs.pattern, theme: prefs.theme)
                .ignoresSafeArea()
            content
        }
    }
}

// MARK: - التركيز

/// أثرُ التركيز في هذا التطبيق: تكبيرٌ يسير، وظلٌّ، وحدٌّ رفيع بلون الطابع.
/// لا `.buttonStyle(.card)` ولا لمعانُ tvOS الافتراضي: لمعانُه يُقاتل لوحةَ
/// الورق التي بُني عليها التطبيق كلّه، وعمودٌ من الصفوف يرتفع كلٌّ منها عند
/// التركيز يُدوّخ على مقياس التلفاز.
struct TVFocusable: ViewModifier {
    var focused: Bool
    var radius: CGFloat = 28

    func body(content: Content) -> some View {
        content
            .scaleEffect(focused ? 1.03 : 1)
            .animation(Motion.gentle, value: focused)
    }
}

extension View {
    func tvFocus(_ focused: Bool, radius: CGFloat = 28) -> some View {
        modifier(TVFocusable(focused: focused, radius: radius))
    }
}

// MARK: - زرٌّ بلا زخرفة

/// tvOS يرسم لأزراره بطاقةً بيضاء ترتفع عند التركيز، ولا يكفي
/// `.buttonStyle(.plain)` ولا `.focusEffectDisabled()` لإزالتها: النمطُ نفسه
/// هو الذي يرسمها. فيُستبدل بنمطٍ لا يرسم شيئًا ويترك العنوان كما هو —
/// وأثرُ التركيز يُرسم بيدنا بـ`tvFocus`، بحدٍّ بلون الطابع وتعبئةٍ خفيفة.
/// والبيضاءُ لم تكن مسألةَ ذوق: لوحةُ التطبيق ورقٌ وحبر، والبطاقةُ البيضاء
/// تُقاتلها فتبدو الشاشةُ حشوًا لا تصميمًا.
struct TVBare: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    /// زرٌّ عارٍ ومركَّزٌ بأثرنا نحن: يُستعمل في كل أزرار التلفاز بلا استثناء.
    func tvButton(_ focused: Bool, radius: CGFloat = 28) -> some View {
        buttonStyle(TVBare())
            .focusEffectDisabled()
            .tvFocus(focused, radius: radius)
    }
}

// MARK: - هيكلُ الشاشة

/// عنوانٌ في الصدر، وزرُّ رجوعٍ **ظاهر** إلى يساره، والمحتوى تحتهما.
///
/// كان الرجوعُ على زرِّ القائمة في المِرقاب وحده — يعرفه من يعرفه، ومن لا يعرفه
/// يظنّ نفسه محبوسًا. فصار له زرٌّ يُرى ويُركَّز عليه كسائر الأزرار، وبقي زرُّ
/// المِرقاب يعمل معه لا بدلًا منه.
///
/// وكلُّ شاشةٍ تمرّ من هنا، فتتّفق العناوينُ والحوافُّ والمسافات. وهذا هو معنى
/// «المستوى واحد»: لا شاشةَ تُصمَّم على حدة.
struct TVScreen<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    /// nil للشاشة الجذر: لا رجوعَ من أوّل الطريق.
    var onBack: (() -> Void)? = nil
    var backFocused: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        TVGround {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(Theme.display(TVType.hero, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        if let subtitle {
                            Text(subtitle)
                                .font(Theme.display(TVType.caption, weight: .regular))
                                .foregroundStyle(Theme.inkFaint)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)
                    if let onBack {
                        Button(action: onBack) {
                            HStack(spacing: 10) {
                                Text(loc("رجوع"))
                                    .font(Theme.display(TVType.caption, weight: .medium))
                                // في العربية يُشار إلى الوراء بسهمٍ إلى اليمين.
                                Image(systemName: "chevron.right")
                                    .font(.system(size: TVType.caption, weight: .semibold))
                            }
                            .foregroundStyle(backFocused ? Theme.ink : Theme.inkFaint)
                            .padding(.horizontal, 26)
                            .frame(height: 62)
                            .background(Capsule().fill(Theme.accent.opacity(backFocused ? 0.18 : 0.06)))
                        }
                        .tvButton(backFocused, radius: 31)
                    }
                }
                .padding(.bottom, 34)

                content
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TVSafe.horizontal)
            .padding(.vertical, TVSafe.vertical)
        }
    }
}

// MARK: - الصفّ

/// صفٌّ واحد لكلّ قوائم التطبيق: رمزٌ ثمّ اسمٌ ثمّ تفصيلٌ خفيف، وكلُّه إلى اليمين.
///
/// والتعبئةُ والحدُّ يُرسمان على **شكلٍ واحد** لا على شكلين: كان الحدُّ يُوضع على
/// حدود الزرّ الخارجية والتعبئةُ على الشكل الداخلي، فيظهران مستطيلين متزحزحين —
/// حافّةٌ خلف حافّة. وهذا ما بدا «سيّئًا وغيرَ مرتّب» على الشاشة.
struct TVRow: View {
    let title: String
    var detail: String? = nil
    /// رمزُ SF إلى يمين الاسم. يُعرف من ثلاثة أمتار قبل أن تُقرأ الكلمة.
    var symbol: String? = nil
    var focused: Bool = false
    var height: CGFloat = 92
    var radius: CGFloat = 22

    var body: some View {
        HStack(spacing: 20) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: TVType.caption, weight: .medium))
                    .foregroundStyle(focused ? Theme.accent : Theme.inkFaint)
                    .frame(width: 42)
            }
            Text(title)
                .font(Theme.display(TVType.title, weight: focused ? .bold : .regular))
                .foregroundStyle(focused ? Theme.ink : Theme.inkSoft)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
            Spacer(minLength: 14)
            if let detail {
                Text(detail)
                    .font(Theme.display(TVType.footnote, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Theme.accent.opacity(focused ? 0.16 : 0))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(focused ? 0.85 : 0), lineWidth: 3)
                )
        )
        .tvFocus(focused, radius: radius)
    }
}
