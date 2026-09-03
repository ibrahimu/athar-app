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

struct ZakatResult: Equatable {
    /// مجموع المال الزكوي بعد خصم الديون الحالّة.
    let base: Double
    /// النصاب بقيمة ٨٥ غرام ذهب.
    let nisab: Double
    let reachesNisab: Bool
    /// الواجب: ربع العشر.
    let due: Double
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
        let nisab = goldNisabGrams * i.goldPricePerGram
        let reaches = i.goldPricePerGram > 0 && base >= nisab
        return ZakatResult(base: base, nisab: nisab, reachesNisab: reaches, due: reaches ? base * rate : 0)
    }

    /// الأدلة المعروضة تحت الحاسبة.
    static let evidence: [(text: String, source: String)] = [
        ("وَأَقِيمُوا الصَّلَاةَ وَآتُوا الزَّكَاةَ", "البقرة: ٤٣"),
        ("وفي الرِّقَة ربع العشر.", "رواه البخاري"),
        ("ليس فيما دون خمس أواقٍ صدقة.", "متفق عليه"),
    ]

    static let notes: [String] = [
        "تجب الزكاة إذا بلغ المال النصاب ومضى عليه حَوْلٌ هجري كامل.",
        "النصاب هنا بقيمة ٨٥ غرامًا من الذهب، وهو المعمول به في أكثر الفتاوى المعاصرة.",
        "الديون الحالّة عليك تُخصم، وديونك على الناس المرجوّة تُزكّى.",
        "حُليّ المرأة المستعمَل فيه خلاف؛ والأحوط زكاته إن بلغ النصاب.",
    ]
}
