import Foundation

// MARK: - مناسبات السنّة في التقويم الهجري
//
// لا يُدرج هنا إلا ما له أصل في الكتاب والسنّة من عبادة مخصوصة أو أيام فاضلة.
// فلا مولد، ولا نصف شعبان، ولا سابع وعشرين رجب — لأنها بلا دليل صحيح.
//
// والمناسبات بيانات لا نصوص: العنوان والوصف من كلامنا، والدليل معرّفٌ يُحلّ متنُه
// من quran.json وhadith.json عند العرض. وما لم نجد له في بياناتنا مدخلًا بقي لفظُه
// مكتوبًا كما كان — لا يُصحَّح ولا يُخرَّج من عندنا، ومواضعه الثلاثة مؤشَّرة أدناه.

/// مصدرُ الدليل بمعرّفه. كان متنُه مكتوبًا هنا فاختلف رسمُ الآية عن مصحف التطبيق
/// العثماني، وأُقصّت المتون بـ«…» — فصار يُحلّ من بياناته ليكون لفظُه لفظَها بحرفه.
enum OccasionProof: Hashable {
    case ayah(surah: Int, ayah: Int)
    case hadith(id: String)
    /// لفظٌ لا مدخل له في بيانات التطبيق. يبقى كما كُتب: لا يُصحَّح ولا يُخرَّج ولا
    /// يُحذف من عندنا — وإدخالُ روايةٍ إلى hadith.json قرارُ صاحب التطبيق بمصدرٍ يعتمده.
    case unsourced(text: String, source: String)
}

struct HijriOccasion: Identifiable, Hashable {
    let id: String
    let title: String
    /// الشهر الهجري (1 محرم … 12 ذو الحجة)، وصفر يعني «كل شهر».
    let month: Int
    let day: Int
    /// عدد أيام المناسبة (1 ليوم واحد). ورمضان يُكتب 30 وقد يكون الشهر 29،
    /// فتُقصّ النافذة على آخر الشهر في `occasions(on:)` كي لا يقع العيد داخلها.
    let days: Int
    /// ما يُشرع فيها — بأسلوب التطبيق.
    let detail: String
    /// الدليل بمعرّفه لا بمتنه.
    let proof: OccasionProof
    let icon: String
    let accent: String

    var isMonthly: Bool { month == 0 }

    /// متن الدليل كما في مصدره. يُحلّ عند الطلب لا عند بناء `all`: الودجة تبني
    /// المناسبات لتكتب اسم اليوم القادم وحده، فلا يُفكّ لها المصحف ولا كتب الحديث.
    var evidence: String {
        switch proof {
        case .ayah(let s, let a):     return Quran.text(AyahRef(surah: s, ayah: a)) ?? ""
        case .hadith(let id):         return HadithLibrary.hadith(id: id)?.text ?? ""
        case .unsourced(let t, _):    return t
        }
    }

    /// سطر العزو: «سورة البقرة: 185» للآية، وتخريج الكتاب نفسِه للحديث.
    var evidenceSource: String {
        switch proof {
        case .ayah(let s, let a):
            guard let name = Quran.surah(s)?.name else { return "" }
            return "سورة \(name): \(a.counterText)"
        case .hadith(let id):         return HadithLibrary.hadith(id: id)?.citation ?? ""
        case .unsourced(_, let s):    return s
        }
    }
}

enum Occasions {
    static let monthNames = ["محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
                             "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]

    static func monthName(_ m: Int) -> String { (1...12).contains(m) ? monthNames[m - 1] : "" }

    /// المعرّفات مأخوذة من quran.json وhadith.json؛ وما بقي متنُه مكتوبًا هنا
    /// (`unsourced`) فليس له في بيانات التطبيق مدخل، وموضعه دون ذلك في التعليق.
    static let all: [HijriOccasion] = [
        // r1246 لا r1167: المتنان واحد وتخريجهما واحد، ورقم 1246 واقعٌ في باب الصيام
        // من رياض الصالحين، فيقع القارئ من الكتاب على بابه لا على باب قيام الليل.
        .init(id: "muharram", title: "بداية السنة الهجرية", month: 1, day: 1, days: 1,
              detail: "محرم شهرٌ حرام، وصيامه من أفضل الصيام بعد رمضان. وليس لأول السنة عبادة مخصوصة.",
              proof: .hadith(id: "r1246"),
              icon: "moon.fill", accent: "night"),
        // لفظ أبي قتادة عند مسلم «يكفر السنة الماضية». وكان المكتوب هنا «أحتسب على الله
        // أن يكفّر السنة التي قبله» — روايةٌ أخرى للحديث نفسه ليست في بيانات التطبيق.
        .init(id: "ashura", title: "تاسوعاء وعاشوراء", month: 1, day: 9, days: 2,
              detail: "يُستحب صيام العاشر من محرم، ويُصام التاسع معه مخالفةً لليهود.",
              proof: .hadith(id: "r1252"),
              icon: "sun.max.fill", accent: "gold"),
        // الآية تُعرض تامّةً من المصحف: كانت مكتوبةً هنا مقصوصةً بـ«…» وبرسمٍ إملائي
        // يخالف عثمانيَّ quran.json (ٱلَّذِىٓ وٱلْقُرْءَانُ) — فصارت تُحلّ بمعرّفها.
        .init(id: "ramadan", title: "شهر رمضان", month: 9, day: 1, days: 30,
              detail: "شهر الصيام والقيام والقرآن والصدقة — فُرض صيامه على كل مسلم بالغ قادر.",
              proof: .ayah(surah: 2, ayah: 185),
              icon: "moon.stars.fill", accent: "green"),
        // r1192 هو لفظ «في الوتر» بعينه، وهو ما يعد به الوصف؛ وضميرُ «وعنها» في أوّله
        // لعائشة رضي الله عنها كما في سياق الكتاب — ولم يُبدَّل بغيره كي لا يُبدَّل المتن.
        .init(id: "lastTen", title: "العشر الأواخر من رمضان", month: 9, day: 21, days: 10,
              detail: "أفضل ليالي السنة، وفيها ليلة القدر — تُلتمس في الوتر منها، ويُسنّ الاعتكاف والاجتهاد في القيام.",
              proof: .hadith(id: "r1192"),
              icon: "sparkles", accent: "dusk"),
        // حديث زكاة الفطر ليس في رياض الصالحين ولا في الأربعين، فليس له معرّف يُحال
        // عليه. يبقى لفظه وعزوه كما كُتبا حتى يُدخل صاحبُ التطبيق روايةً بمصدرٍ يعتمده.
        .init(id: "fitr", title: "عيد الفطر", month: 10, day: 1, days: 1,
              detail: "تُخرج زكاة الفطر قبل صلاة العيد، وتُصلّى صلاة العيد جماعة، ويحرم صيام يوم العيد.",
              proof: .unsourced(text: "فرض رسول الله ﷺ زكاة الفطر… وأمر بها أن تُؤدّى قبل خروج الناس إلى الصلاة.",
                                source: "متفق عليه"),
              icon: "gift.fill", accent: "dawn"),
        .init(id: "shawwal6", title: "ست من شوال", month: 10, day: 2, days: 28,
              detail: "صيام ستة أيام من شوال بعد رمضان — متتابعة أو متفرقة — يعدل صيام السنة كلها.",
              proof: .hadith(id: "r1254"),
              icon: "6.circle.fill", accent: "sea"),
        // r1249 لفظ البخاري بتمامه، وفيه سؤالهم عن الجهاد وجوابه ﷺ. وكان العزو المكتوب
        // هنا يجمع أبا داود والترمذي وابن ماجه — والتخريج الآن من الكتاب نفسه لا منّا.
        .init(id: "dhulhijjah10", title: "عشر ذي الحجة", month: 12, day: 1, days: 9,
              detail: "أفضل أيام الدنيا: يُكثَر فيها من الذكر والتكبير والصيام والصدقة.",
              proof: .hadith(id: "r1249"),
              icon: "10.circle.fill", accent: "gold"),
        // وعرفة كعاشوراء: لفظ مسلم «يكفر السنة الماضية والباقية» من رواية أبي قتادة.
        .init(id: "arafah", title: "يوم عرفة", month: 12, day: 9, days: 1,
              detail: "يُستحب صيامه لغير الحاج، ويُكثَر فيه من الدعاء والتهليل.",
              proof: .hadith(id: "r1250"),
              icon: "mountain.2.fill", accent: "maghrib"),
        // وكذلك النهي عن صوم العيدين: لا مدخل له في بيانات التطبيق — يبقى كما كُتب.
        .init(id: "adha", title: "عيد الأضحى", month: 12, day: 10, days: 1,
              detail: "صلاة العيد ثم الأضحية لمن قدر عليها، ويحرم صيامه.",
              proof: .unsourced(text: "نهى النبي ﷺ عن صوم يومين: يوم الفطر ويوم النحر.",
                                source: "متفق عليه"),
              icon: "gift.fill", accent: "dawn"),
        // وحديث أيام التشريق ثالثُها: ليس في الكتابين، فلم يُختلق له معرّف ولا تخريج.
        .init(id: "tashreeq", title: "أيام التشريق", month: 12, day: 11, days: 3,
              detail: "أيام أكل وشرب وذكر لله؛ لا يُصام فيها إلا لمتمتّع أو قارن لم يجد الهدي.",
              proof: .unsourced(text: "أيام التشريق أيام أكل وشرب وذكر لله.",
                                source: "رواه مسلم"),
              icon: "flame.fill", accent: "asr"),
        // r1258 لا r1139: المتن واحد، ونصّ r1139 يُذيَّل بكلام النووي في وقت الإيتار
        // وفيه علامة اقتباس زائدة — فيُقرأ على البطاقة كأنّه من الحديث وليس منه.
        .init(id: "whiteDays", title: "الأيام البيض", month: 0, day: 13, days: 3,
              detail: "صيام الثالث عشر والرابع عشر والخامس عشر من كل شهر هجري.",
              proof: .hadith(id: "r1258"),
              icon: "circle.lefthalf.filled", accent: "calm"),
    ]

    /// الأصل الفلكي بلا إزاحة — لحساب أوائل الأيام والمسافات بينها.
    private static var hijri: Calendar { Hijri.calendar }

    /// مكوّنات اليوم الهجري (سنة، شهر، يوم)، بعد ضبط المطالع — فتقع الأيام البيض
    /// وعاشوراء وعرفة على ما يوافق تقويم بلد المستخدم لا على الحساب وحده.
    static func hijriComponents(_ date: Date) -> (year: Int, month: Int, day: Int) {
        let c = Hijri.components(date)
        return (c.year ?? 1, c.month ?? 1, c.day ?? 1)
    }

    static func date(year: Int, month: Int, day: Int) -> Date? {
        Hijri.date(year: year, month: month, day: day)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        Hijri.daysInMonth(year: year, month: month)
    }

    /// بداية المناسبة القادمة (أو الجارية) لكل مناسبة، مرتّبةً زمنيًا.
    static func upcoming(from date: Date, limit: Int = 6) -> [(occasion: HijriOccasion, start: Date, end: Date)] {
        let today = hijri.startOfDay(for: date)
        let (y, m, _) = hijriComponents(date)
        var out: [(HijriOccasion, Date, Date)] = []
        for o in all {
            var candidates: [Date] = []
            if o.isMonthly {
                for offset in 0...3 {
                    var mm = m + offset, yy = y
                    if mm > 12 { mm -= 12; yy += 1 }
                    // تُتخطّى الأيام البيض في ذي الحجة (13 منه من أيام التشريق).
                    if o.id == "whiteDays", mm == 12 { continue }
                    if let d = self.date(year: yy, month: mm, day: o.day) { candidates.append(d) }
                }
            } else {
                for yy in [y, y + 1] {
                    if let d = self.date(year: yy, month: o.month, day: o.day) { candidates.append(d) }
                }
            }
            for start in candidates {
                let (sy, sm, _) = hijriComponents(start)
                let end = hijri.date(byAdding: .day, value: windowDays(o, year: sy, month: sm), to: start) ?? start
                // جارية (اليوم داخل مداها) أو قادمة.
                if end > today { out.append((o, start, end)); break }
            }
        }
        return out.sorted { $0.1 < $1.1 }.prefix(limit).map { ($0.0, $0.1, $0.2) }
    }

    /// المناسبات التي يقع فيها هذا اليوم.
    static func occasions(on date: Date) -> [HijriOccasion] {
        let (y, m, d) = hijriComponents(date)
        return all.filter { o in
            guard o.isMonthly || o.month == m else { return false }
            // 13 ذي الحجة من أيام التشريق ولا تُصام، فلا تُعرض فيها الأيام البيض.
            if o.id == "whiteDays", m == 12 { return false }
            return d >= o.day && d < o.day + windowDays(o, year: y, month: m)
        }
    }

    /// طول نافذة المناسبة في شهرٍ بعينه: لا تتجاوز آخر أيامه (رمضان قد يكون 29 يومًا،
    /// فلولا القصّ لظهر «شهر رمضان — جارية الآن» يوم عيد الفطر).
    /// وأيام التشريق تُخرِج «الأيام البيض» من ذي الحجة لأنها أيام أكلٍ وشربٍ لا صيام.
    static func windowDays(_ o: HijriOccasion, year: Int, month: Int) -> Int {
        let monthLength = daysInMonth(year: year, month: o.isMonthly ? month : o.month)
        return max(1, min(o.days, monthLength - o.day + 1))
    }

    /// عدد الأيام من اليوم حتى التاريخ (صفر لليوم).
    static func daysUntil(_ target: Date, from date: Date = Date()) -> Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: target)).day ?? 0
    }
}
