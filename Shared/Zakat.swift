import Foundation

// MARK: - حاسبة الزكاة

/// مدخلات الزكاة — كلها بعملة المستخدم، والأسعار يدخلها بنفسه فلا اتصال بأي جهة.
struct ZakatInput: Equatable {
    var cash: Double = 0            // النقد في اليد والحسابات
    var goldGrams: Double = 0       // الذهب بالغرام
    var silverGrams: Double = 0     // الفضة بالغرام
    var tradeGoods: Double = 0      // عروض التجارة بسعر بيعها اليوم
    var receivables: Double = 0     // ديون لك مرجوّة السداد
    var debtsDue: Double = 0        // ديون عليك حالّة
    var goldPricePerGram: Double = 0
    var silverPricePerGram: Double = 0
}

/// المعدن الذي حُسب به النصاب — يُذكر للمستخدم كي يعرف على أيّ أساس حُسب.
enum NisabMetal { case gold, silver, none }

struct ZakatResult: Equatable {
    /// مجموع المال الزكوي بعد خصم الديون الحالّة.
    let base: Double
    /// قيمة النصاب المعتمَد (الأدنى من نصابَي الذهب والفضة مما أدخل المستخدم سعره).
    let nisab: Double
    let reachesNisab: Bool
    /// الواجب: ربع العشر.
    let due: Double
    /// هل عُرف النصاب أصلًا؟ بلا سعرٍ لا يصحّ أن يُقال «لا زكاة عليك».
    var nisabKnown: Bool = true
    var nisabMetal: NisabMetal = .gold
}

enum Zakat {
    /// نصاب الذهب عشرون مثقالًا ≈ ٨٥ غرامًا، ونصاب الفضة مئتا درهم ≈ ٥٩٥ غرامًا.
    static let goldNisabGrams = 85.0
    static let silverNisabGrams = 595.0
    static let rate = 0.025

    static func compute(_ i: ZakatInput) -> ZakatResult {
        let assets = i.cash + i.goldGrams * i.goldPricePerGram + i.silverGrams * i.silverPricePerGram
                   + i.tradeGoods + i.receivables
        let base = max(0, assets - i.debtsDue)
        // نصابان لا واحد: نصاب الذهب (٨٥غ) ونصاب الفضة (٥٩٥غ). والفقهاء المعاصرون
        // على تقدير نصاب النقد بالأحظّ للفقراء، وهو الأدنى قيمةً منهما — فمن بلغ ماله
        // أحدهما وجبت عليه. فإن لم يُدخل المستخدم إلا سعرًا واحدًا حُسب به وحده.
        let goldNisab = goldNisabGrams * i.goldPricePerGram
        let silverNisab = silverNisabGrams * i.silverPricePerGram
        let candidates = [goldNisab, silverNisab].filter { $0 > 0 }
        guard let nisab = candidates.min() else {
            // بلا سعرٍ لا يُعرف النصاب، فلا يُقال «لا زكاة عليك» — تُترك النتيجة معلّقة.
            return ZakatResult(base: base, nisab: 0, reachesNisab: false, due: 0, nisabKnown: false,
                               nisabMetal: .none)
        }
        let metal: NisabMetal = (silverNisab > 0 && silverNisab <= goldNisab) || goldNisab == 0 ? .silver : .gold
        let reaches = base >= nisab
        return ZakatResult(base: base, nisab: nisab, reachesNisab: reaches,
                           due: reaches ? base * rate : 0, nisabKnown: true, nisabMetal: metal)
    }

    /// الأدلة المعروضة تحت الحاسبة.
    static let evidence: [(text: String, source: String)] = [
        ("وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ", "البقرة: ٤٣"),
        ("وفي الرِّقَة ربع العشر.", "رواه البخاري"),
        ("ليس فيما دون خمس أواقٍ صدقة.", "متفق عليه"),
    ]

    static let notes: [String] = [
        "تجب الزكاة إذا بلغ المال النصاب ومضى عليه حَوْلٌ هجري كامل.",
        "النصاب: ٨٥ غرامًا ذهبًا أو ٥٩٥ غرامًا فضة. ويُحسب هنا بالأدنى قيمةً منهما مما أدخلتَ سعره، وهو الأحظّ للفقراء.",
        "الديون الحالّة عليك تُخصم، وديونك على الناس المرجوّة تُزكّى.",
        "حُليّ المرأة المستعمَل فيه خلاف بين أهل العلم؛ والأحوط زكاته إن بلغ النصاب.",
        "هذه الحاسبة تُعينك على التقدير، وليست فتوى؛ فإن أشكل عليك أمرٌ فاسأل أهل العلم.",
    ]
}
