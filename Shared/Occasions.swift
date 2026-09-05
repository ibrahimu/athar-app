import Foundation

// MARK: - مناسبات السنّة في التقويم الهجري
//
// لا يُدرج هنا إلا ما له أصل في الكتاب والسنّة من عبادة مخصوصة أو أيام فاضلة.
// فلا مولد، ولا نصف شعبان، ولا سابع وعشرين رجب — لأنها بلا دليل صحيح.

struct HijriOccasion: Identifiable, Hashable {
    let id: String
    let title: String
    /// الشهر الهجري (١ محرم … ١٢ ذو الحجة)، وصفر يعني «كل شهر».
    let month: Int
    let day: Int
    /// عدد أيام المناسبة (١ ليوم واحد). ورمضان يُكتب ٣٠ وقد يكون الشهر ٢٩،
    /// فتُقصّ النافذة على آخر الشهر في `occasions(on:)` كي لا يقع العيد داخلها.
    let days: Int
    /// ما يُشرع فيها — بأسلوب التطبيق.
    let detail: String
    /// الدليل: نصّ الحديث حين كان لفظه معلومًا، أو إحالته.
    let evidence: String
    let evidenceSource: String
    let icon: String
    let accent: String

    var isMonthly: Bool { month == 0 }
}

enum Occasions {
    static let monthNames = ["محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
                             "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"]

    static func monthName(_ m: Int) -> String { (1...12).contains(m) ? monthNames[m - 1] : "" }

    static let all: [HijriOccasion] = [
        .init(id: "muharram", title: "بداية السنة الهجرية", month: 1, day: 1, days: 1,
              detail: "محرم شهرٌ حرام، وصيامه من أفضل الصيام بعد رمضان. وليس لأول السنة عبادة مخصوصة.",
              evidence: "أفضل الصيام بعد رمضان شهر الله المحرم.", evidenceSource: "رواه مسلم",
              icon: "moon.fill", accent: "night"),
        .init(id: "ashura", title: "تاسوعاء وعاشوراء", month: 1, day: 9, days: 2,
              detail: "يُستحب صيام العاشر من محرم، ويُصام التاسع معه مخالفةً لليهود.",
              evidence: "صيام يوم عاشوراء أحتسب على الله أن يكفّر السنة التي قبله.", evidenceSource: "رواه مسلم",
              icon: "sun.max.fill", accent: "gold"),
        .init(id: "ramadan", title: "شهر رمضان", month: 9, day: 1, days: 30,
              detail: "شهر الصيام والقيام والقرآن والصدقة — فُرض صيامه على كل مسلم بالغ قادر.",
              evidence: "شَهْرُ رَمَضَانَ الَّذِي أُنزِلَ فِيهِ الْقُرْآنُ… فَمَن شَهِدَ مِنكُمُ الشَّهْرَ فَلْيَصُمْهُ", evidenceSource: "البقرة: ١٨٥",
              icon: "moon.stars.fill", accent: "green"),
        .init(id: "lastTen", title: "العشر الأواخر من رمضان", month: 9, day: 21, days: 10,
              detail: "أفضل ليالي السنة، وفيها ليلة القدر — تُلتمس في الوتر منها، ويُسنّ الاعتكاف والاجتهاد في القيام.",
              evidence: "تحرّوا ليلة القدر في الوتر من العشر الأواخر من رمضان.", evidenceSource: "رواه البخاري",
              icon: "sparkles", accent: "dusk"),
        .init(id: "fitr", title: "عيد الفطر", month: 10, day: 1, days: 1,
              detail: "تُخرج زكاة الفطر قبل صلاة العيد، وتُصلّى صلاة العيد جماعة، ويحرم صيام يوم العيد.",
              evidence: "فرض رسول الله ﷺ زكاة الفطر… وأمر بها أن تُؤدّى قبل خروج الناس إلى الصلاة.", evidenceSource: "متفق عليه",
              icon: "gift.fill", accent: "dawn"),
        .init(id: "shawwal6", title: "ست من شوال", month: 10, day: 2, days: 28,
              detail: "صيام ستة أيام من شوال بعد رمضان — متتابعة أو متفرقة — يعدل صيام السنة كلها.",
              evidence: "من صام رمضان ثم أتبعه ستًّا من شوال كان كصيام الدهر.", evidenceSource: "رواه مسلم",
              icon: "6.circle.fill", accent: "sea"),
        .init(id: "dhulhijjah10", title: "عشر ذي الحجة", month: 12, day: 1, days: 9,
              detail: "أفضل أيام الدنيا: يُكثَر فيها من الذكر والتكبير والصيام والصدقة.",
              evidence: "ما من أيام العمل الصالح فيهن أحبّ إلى الله من هذه الأيام العشر.", evidenceSource: "رواه أبو داود والترمذي وابن ماجه، وأصله في البخاري",
              icon: "10.circle.fill", accent: "gold"),
        .init(id: "arafah", title: "يوم عرفة", month: 12, day: 9, days: 1,
              detail: "يُستحب صيامه لغير الحاج، ويُكثَر فيه من الدعاء والتهليل.",
              evidence: "صيام يوم عرفة أحتسب على الله أن يكفّر السنة التي قبله والسنة التي بعده.", evidenceSource: "رواه مسلم",
              icon: "mountain.2.fill", accent: "maghrib"),
        .init(id: "adha", title: "عيد الأضحى", month: 12, day: 10, days: 1,
              detail: "صلاة العيد ثم الأضحية لمن قدر عليها، ويحرم صيامه.",
              evidence: "نهى النبي ﷺ عن صوم يومين: يوم الفطر ويوم النحر.", evidenceSource: "متفق عليه",
              icon: "gift.fill", accent: "dawn"),
        .init(id: "tashreeq", title: "أيام التشريق", month: 12, day: 11, days: 3,
              detail: "أيام أكل وشرب وذكر لله؛ لا يُصام فيها إلا لمتمتّع أو قارن لم يجد الهدي.",
              evidence: "أيام التشريق أيام أكل وشرب وذكر لله.", evidenceSource: "رواه مسلم",
              icon: "flame.fill", accent: "asr"),
        .init(id: "whiteDays", title: "الأيام البيض", month: 0, day: 13, days: 3,
              detail: "صيام الثالث عشر والرابع عشر والخامس عشر من كل شهر هجري.",
              evidence: "أوصاني خليلي ﷺ بثلاث: صيام ثلاثة أيام من كل شهر، وركعتي الضحى، وأن أوتر قبل أن أنام.", evidenceSource: "متفق عليه",
              icon: "circle.lefthalf.filled", accent: "calm"),
    ]

    private static var hijri: Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = .current
        return c
    }

    /// مكوّنات اليوم الهجري (سنة، شهر، يوم).
    static func hijriComponents(_ date: Date) -> (year: Int, month: Int, day: Int) {
        let c = hijri.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 1, c.month ?? 1, c.day ?? 1)
    }

    static func date(year: Int, month: Int, day: Int) -> Date? {
        hijri.date(from: DateComponents(year: year, month: month, day: day))
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        guard let d = date(year: year, month: month, day: 1) else { return 30 }
        return hijri.range(of: .day, in: .month, for: d)?.count ?? 30
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
                    // تُتخطّى الأيام البيض في ذي الحجة (١٣ منه من أيام التشريق).
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
            // ١٣ ذي الحجة من أيام التشريق ولا تُصام، فلا تُعرض فيها الأيام البيض.
            if o.id == "whiteDays", m == 12 { return false }
            return d >= o.day && d < o.day + windowDays(o, year: y, month: m)
        }
    }

    /// طول نافذة المناسبة في شهرٍ بعينه: لا تتجاوز آخر أيامه (رمضان قد يكون ٢٩ يومًا،
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
