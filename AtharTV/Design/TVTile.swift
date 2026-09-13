import SwiftUI

// MARK: - المربّع
//
// الوحدةُ البصرية الوحيدة في التلفاز. قبلها كان كلُّ شيءٍ صفوفَ كلماتٍ مجرَّدة،
// فبدت الشاشةُ ورقةَ نصٍّ لا تطبيقًا: لا شيء يُنظر إليه، ولا شيء يُعرف من ثلاثة
// أمتار قبل أن يُقرأ.
//
// وثلاثةُ أشياء تصنعه:
//   نجمةٌ ثمانيةٌ محفورة — هي هي `EightPointStar` في تطبيق الجوال (نُقلت لأن
//     `Athar/Views/Components.swift` ليست في هدف التلفاز، وهو يترجم أربعةَ عشرَ
//     ملفًّا من `Shared` بقائمة إدراج) — فيُعرف التطبيقُ من مربّعٍ واحد. وهي
//     تُحسّ ولا تُعدّ: معايرتُها أدناه في `Carve`، وقد أُعيدت بعد أن رُئيت لطخةً.
//   تدرّجٌ مرتَّب لا عشوائيّ: كلُّ مربّعٍ يأخذ موضعَه من سلّمٍ واحد بين لون
//     الطابع وذهبِ زخرفته، فالشبكةُ تُقرأ متتابعةً لا مبعثرةَ الألوان.
//   ورمزٌ في الصدر واسمٌ في الأسفل، كلاهما إلى اليمين — والعينُ العربية تنتظر
//     أن يبدأ السطرُ من اليمين، والتوسيطُ يتركها تبحث عن أوّله.
//
// وما يُميّز المربّعَ المركَّزَ عليه حدٌّ بلون الطابع على **الشكل نفسِه** الذي يحمل
// التعبئة — القاعدةُ التي قامت عليها `TVRow` — لا تعبئةٌ أقوى وحدَها: من ثلاثة
// أمتارٍ لا يُفرَّق بين ٠٫٢٦ و٠٫٤٢ من اللون، ويُفرَّق بين حدٍّ ولا حدّ.

/// نجمةٌ ثمانية — منقولةٌ حرفًا بحرف من `Athar/Views/Components.swift`.
struct TVStar: Shape {
    var innerRatio: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2
        let r = R * innerRatio
        var p = Path()
        for i in 0..<16 {
            let radius = i.isMultiple(of: 2) ? R : r
            let angle = (.pi / 8) * CGFloat(i) - .pi / 2
            let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

enum TVTint {
    /// درجاتُ السلّم: أربعَ عشرةَ درجةً بين لون الطابع وذهبه، أي خمسةَ عشرَ موضعًا
    /// — عددُ القرّاء. وهي درجةٌ ثابتة لا تُقسَم على عدد المربّعات: ثلاثةُ
    /// مربّعاتٍ تصعد ثلاثَ درجاتٍ فتبقى أسرةً واحدةً من اللون، وخمسةَ عشرَ تبلغ
    /// الذهب. ولو قُسم السلّمُ على الثلاثة لصارت ثلاثةَ ألوانٍ لثلاثة أشياءٍ
    /// هي في الحقيقة شيءٌ واحد.
    static let rungs = 14

    /// سلّمُ التدرّج: من لون الطابع إلى ذهب زخرفته، بترتيب الشبكة لا بعشوائها.
    ///
    /// كان بين `accent` و`accent2`، وهما في الوضع الداكن لونٌ واحدٌ يكاد:
    /// في الرمليّ `D3A263` و`E0B472`، فرقُهما ثلاثةَ عشرَ من مئتين وخمسين، ثمّ
    /// يُضرب في شفافية التعبئة (٠٫٢٦) فيبقى منه ثلاثة — وخمسةَ عشرَ مربّعًا بينهما
    /// خمسةَ عشرَ ظلًّا من البنّيّ نفسِه، رُئيت على الشاشة فلم يُعرف لها أوّلٌ من
    /// آخر. والذهبُ (`ornament`) هو اللونُ الثاني الوحيد في كلّ طابع: في الأخضر
    /// يمشي السلّمُ من الأخضر إلى الذهب فيُرى، وفي الرمليّ والعسليّ حيث الذهبُ هو
    /// الطابعُ نفسُه تبقى الشبكةُ لونًا واحدًا — وهذا صحيح، فالطابعُ ذهبيّ.
    ///
    /// والشبكةُ التي تزيد على درجات السلّم تُضغط عليه، فلا يخرج المزجُ عن طرفَيه.
    static func graded(_ index: Int, of count: Int) -> Color {
        guard count > 1, index > 0 else { return Theme.accent }
        let t = Double(index) / Double(max(count - 1, rungs))
        // بالقيم الداكنة مباشرةً: `AtharTVApp` تفرض الوضعَ الداكن، ولونٌ ديناميكيٌّ
        // يُفكّ إلى `UIColor` قد يُفكّ على سِمة النظام لا سِمة التطبيق.
        return Self.mix(Theme.current.accent.dark, Theme.current.ornament.dark, by: t)
    }

    /// مزجٌ خطّي بين لونين بصيغتهما السداسية. `Color.mix(with:by:)` من iOS 18،
    /// والهدف 17.
    private static func mix(_ a: UInt32, _ b: UInt32, by t: Double) -> Color {
        let k = min(max(t, 0), 1)
        func ch(_ shift: UInt32) -> Double {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return (x + (y - x) * k) / 255
        }
        return Color(.sRGB, red: ch(16), green: ch(8), blue: ch(0), opacity: 1)
    }
}

// MARK: - المربّع نفسه

struct TVTile: View {
    let title: String
    var subtitle: String? = nil
    /// رمزُ SF في صدر المربّع. يُعرف من ثلاثة أمتار قبل أن يُقرأ الاسم.
    var symbol: String? = nil
    /// رقمٌ في نجمةٍ بدل الرمز — **للسورة**: النجمةُ الثمانية حول رقم السورة هي
    /// اصطلاحُ المصاحف. وليس للقارئ: كان كلُّ قارئٍ يحمل رقمَ موضعه في القائمة،
    /// ولا أحدَ يختار «القارئ السابع» — الرقمُ هناك أثاثُ مبرمِج لا خبرٌ لمن يختار.
    var number: Int? = nil
    /// المختارُ الآن — علامةُ صحٍّ في صدر المربّع، كما يعلّم الهاتفُ قارئَه المختار
    /// في قائمته. وهذا هو الخبرُ الذي يُريده من يقف أمام خمسةَ عشرَ اسمًا.
    var chosen: Bool = false
    var tint: Color = Theme.accent
    var focused: Bool = false
    var playing: Bool = false
    /// نسبةُ الضلعين. المربّعُ هو الأصل، والعريضُ لخيارٍ واحدٍ كبير.
    var aspect: CGFloat = 1

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ورقٌ مصمت أوّلًا: كانت التعبئةُ شفّافةً فبان نقشُ الأرض من خلال المربّع
            // نجيماتٍ صغيرةً بين الحروف — والبطاقةُ في الهاتف سطحٌ مصمتٌ فوق الورق
            // المنقوش لا زجاجٌ عليه. ثمّ التدرّج: من لون المربّع إلى سطحه، فلا
            // يصير المربّعُ لطخةَ لون. و`topTrailing` هنا أعلى اليمين فعلًا — نقاطُ
            // التدرّج لا تنعكس مع الاتجاه العربيّ (قيست على الشاشة)، بخلاف
            // المحاذاة والإزاحة.
            shape
                .fill(Theme.surface)
                .overlay(
                    shape.fill(
                        LinearGradient(colors: [tint.opacity(focused ? 0.36 : 0.26),
                                                tint.opacity(focused ? 0.12 : 0.07)],
                                       startPoint: .topTrailing, endPoint: .bottomLeading)
                    )
                )
                .overlay(carved)
                .overlay(shape.strokeBorder(Theme.accent.opacity(focused ? 0.85 : 0), lineWidth: 3))

            VStack(alignment: .leading, spacing: 0) {
                head
                Spacer(minLength: 0)
                Text(title)
                    .font(Theme.display(TVType.title, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    // مربّعُ الاسم وحده يحجز سطرين ولو شغل واحدًا: في شبكة القرّاء
                    // «علي جابر» سطرٌ و«عبدالباسط عبدالصمد» سطران، فإن أُلصق
                    // الاسمان بالقاع تفاوت أوّلُ سطرٍ بينهما ولم يُقرأ الصفُّ
                    // صفًّا. أمّا ما تحته سطرُ خدمة فيرسو الاسمُ عليه.
                    .lineLimit(2, reservesSpace: subtitle == nil)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.display(TVType.footnote, weight: .regular))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(TVMetric.tilePad)
        }
        .aspectRatio(aspect, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous))
        .tvFocus(focused, radius: TVMetric.tileRadius)
    }

    /// النجمةُ المحفورة، ومركزُها قلبُ الرمز: فالرمزُ يجلس في صدرها كما يجلس
    /// الرمزُ في نجمة «اختر سورة لتبدأ» في الهاتف، والقارئُ المختار تصير علامتُه
    /// ميداليةً. وتُقاس على المربّع لا على رقمٍ ثابت: المربّعُ العريض في المجلس
    /// نجمتُه أكبر من نجمة مربّع الشبكة كما بطاقةُ الهاتف البطلة.
    ///
    /// والحشوُ السالب لا الإزاحة: `offset` ينعكس في الاتجاه العربيّ فدفع النجمةَ
    /// خارج الزاوية بدل أن يُدخلها. والمحاذاةُ صريحةٌ داخل `GeometryReader` لأن
    /// موضعَ محتواه الافتراضيّ ليس ممّا يُوثَق به مع انعكاس الاتجاه.
    private var carved: some View {
        GeometryReader { g in
            let star = min(g.size.width, g.size.height) * Carve.size
            ZStack(alignment: .topLeading) {
                TVStar(innerRatio: Carve.innerRatio)
                    .fill(tint.opacity(focused ? Carve.opacityFocused : Carve.opacity))
                    .frame(width: star, height: star)
                    .padding(.top, Carve.heart - star / 2)
                    .padding(.leading, Carve.heart - star / 2)
            }
            .frame(width: g.size.width, height: g.size.height, alignment: .topLeading)
        }
    }

    /// صدرُ المربّع: علامتُه إلى اليمين في قلب النجمة، وحالُه إلى اليسار.
    @ViewBuilder private var head: some View {
        HStack(spacing: 12) {
            if let number {
                medallion(number)
            } else if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: TVMetric.tileGlyph, weight: .light))
                    .foregroundStyle(tint)
                    .frame(width: TVMetric.tileGlyph, height: TVMetric.tileGlyph)
            } else if chosen {
                check
            }
            Spacer(minLength: 0)
            if playing {
                Image(systemName: "waveform")
                    .font(.system(size: TVType.caption, weight: .semibold))
                    .foregroundStyle(tint)
            }
            // مربّعٌ له علامةٌ وهو المختار: الصحُّ إلى جانب الحال، لا بدلَ العلامة.
            if chosen, number != nil || symbol != nil {
                check
            }
        }
    }

    private var check: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: TVMetric.tileGlyph, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: TVMetric.tileGlyph, height: TVMetric.tileGlyph)
    }

    /// ميداليةُ رقم السورة، على مثال `SurahMedallion` في الهاتف: نجمةٌ مزدوجةُ
    /// الحدّ خفيفةُ التعبئة والرقمُ بلون الطابع — لا نجمةٌ مصمتةٌ تصرخ في الزاوية.
    private func medallion(_ number: Int) -> some View {
        ZStack {
            TVStar().fill(tint.opacity(0.12))
            TVStar().stroke(tint, lineWidth: 3)
            TVStar(innerRatio: 0.72).stroke(tint.opacity(0.35), lineWidth: 1.5)
                .padding(7)
            Text(number.counterText)
                .font(Theme.display(TVType.footnote, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: TVMetric.tileMedal, height: TVMetric.tileMedal)
    }
}

/// معايرةُ النجمة المحفورة. تُحسّ ولا تُعدّ — القاعدةُ نفسُها التي تُرسم بها نقوشُ
/// خلفية الهاتف (`GeometryMotif`: سقفُ الشفافية ٠٫٠٥، والنجمةُ أكبر من البطاقة
/// وتفيض عن زاويتها).
///
/// وما كان قبلها: نجمةٌ قطرُها ٢٦٠ نقطةً في مربّعٍ ضلعُه ٢٩٣، مدفوعةٌ بإزاحةٍ
/// معكوسةٍ حتى صار مركزُها على حافّة المربّع فلم يبقَ منها إلا ربعُها الأسفل —
/// شكلٌ لا يُعرف أنه نجمة — وبتسعةٍ بالمئة من اللون فوق تعبئةٍ لونُها هو، فقيس
/// فرقُها عن أرضها ثلاثةَ عشرَ من مئتين وخمسين: حدٌّ يُرى ويُعدّ، وقال صاحبُه إنها
/// «لطخة» خلف النصّ. والمقصودُ سبعةٌ ونحوُها: أدنى ما يثبت على الشاشة ولا يزيد.
private enum Carve {
    /// قطرُ النجمة نسبةً إلى أقصر ضلعَي المربّع. أصغرُ من الضلع لا أكبر: ما فاض
    /// عن الزاوية يُقصّ، وما بقي يجب أن يُرى نجمةً بأطرافها لا قطعةً منها.
    static let size: CGFloat = 0.78
    /// مركزُ النجمة من زاوية المربّع — هو مركزُ الرمز نفسُه: حشوُ المربّع ونصفُ
    /// الرمز. فالرمزُ في قلبها، وثلاثةُ أرباعها في المربّع وربعُها خارجَه.
    static let heart: CGFloat = TVMetric.tilePad + TVMetric.tileGlyph / 2
    /// أطرافٌ أهدأ من نجمة الرقم (٠٫٦٢): نجمةُ الخلفية لا تُشير إلى شيء.
    static let innerRatio: CGFloat = 0.68
    /// بلون المربّع نفسِه فوق تعبئته: حفرٌ في المادّة لا طلاءٌ عليها. و٠٫٠٥ من
    /// لونٍ أعلى أرضِه بنحو ١٣٠ درجةً تزيد ستًّا ونصفًا — الفرقُ المقصود. وقيست
    /// ٠٫٠٥٥ فأعطت تسعًا: يُرى الحدّ.
    static let opacity: Double = 0.05
    /// والمركَّزُ عليه أرضُه أقوى، فيُرفع بقدر ما يبقى الفرقُ فرقًا لا أكثر.
    static let opacityFocused: Double = 0.065
}

/// مقاساتُ المربّع. لا رقمَ في موضعه — tvOS بلا «حجمٍ ديناميكي»، فما كُتب رقمًا
/// بقي رقمًا على شاشةِ خمسٍ وستّين بوصة.
enum TVMetric {
    static let tileRadius: CGFloat = 28
    static let tilePad: CGFloat = 30
    static let tileGlyph: CGFloat = 46
    /// ميداليةُ رقم السورة أكبر من الرمز: الرقمُ في جوفها يجب أن يبلغ حجمَ الحاشية.
    static let tileMedal: CGFloat = 64
    static let gridGap: CGFloat = 26
}
