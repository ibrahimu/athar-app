import Foundation

// MARK: - اختلاف المطالع
//
// أم القرى حسابٌ فلكيّ، والهلال يُرى في البلاد ليلةً قبله أو بعده، فيختلف تقويم
// البلد عن الجهاز يومًا أو يومين. يُترك للمستخدم أن يوافق بينهما، ويجري التحويل
// كلّه من هنا: لو تفرّقت المواضع لناقض رأسُ الشاشة شبكةَ التقويم في اليوم نفسه.

enum Hijri {
    /// يومان لا أكثر: ما جاوزهما لم يعد اختلاف مطالع بل تقويمًا آخر.
    static let bounds = -2...2

    static func clamped(_ value: Int) -> Int {
        max(bounds.lowerBound, min(bounds.upperBound, value))
    }

    static let offsetKey = "athar.hijriOffset"

    /// من دفاتر المجموعة رأسًا — الودجة والساعة تقرآن الإزاحة نفسها بلا مخزنٍ يُبنى لها.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AtharStore.appGroup) ?? .standard
    }

    static var offset: Int { clamped(defaults.integer(forKey: offsetKey)) }

    /// أم القرى بمنطقة الجهاز — بلا إزاحة، فهذا هو الأصل الفلكي الذي تُقاس عليه
    /// أطوال الشهور وأيام الأسبوع. ويُحسب في كل نداء لأن المسافر يبدّل منطقته.
    static var calendar: Calendar {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = .current
        return c
    }

    /// اليوم الميلادي مزاحًا بمقدار المطالع — مدخل كل تحويل إلى الهجري.
    static func shifted(_ date: Date) -> Date {
        let o = offset
        guard o != 0 else { return date }
        return Calendar.current.date(byAdding: .day, value: o, to: date) ?? date
    }

    /// عكس الإزاحة — بها يعود اليومُ الهجريّ المعروض إلى موضعه على الرزنامة الميلادية.
    static func unshifted(_ date: Date) -> Date {
        let o = offset
        guard o != 0 else { return date }
        return Calendar.current.date(byAdding: .day, value: -o, to: date) ?? date
    }

    /// المعبر الوحيد من ميلاديّ إلى هجريّ في التطبيق كلّه.
    static func components(_ date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: shifted(date))
    }

    /// ومن هجريّ إلى ميلاديّ — بعكس الإزاحة كي يقع اليوم حيث يراه المستخدم.
    static func date(year: Int, month: Int, day: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day)).map(unshifted)
    }

    /// طول الشهر يُقاس على الأصل الفلكي: الإزاحة تنقل الشهر ولا تطيله،
    /// ولو قِيس على تاريخٍ مزاح لوقع اليوم الأول في الشهر السابق فرجع طولُه.
    static func daysInMonth(year: Int, month: Int) -> Int {
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return 30 }
        return calendar.range(of: .day, in: .month, for: first)?.count ?? 30
    }
}

// تطبيق التلفاز يحمل حساب التقويم ولا يحمل AtharStore: دفاترُه دفاتره، ولا
// مجموعةَ تطبيقاتٍ تجمع تلفازًا بهاتف. فما تحت هذا السطر لبقيّة المنصّات.
#if !os(tvOS)
extension AtharStore {
    /// «اختلاف المطالع»: يومان على الأكثر يوافق بهما المستخدمُ تقويمَ بلده.
    /// تُكتب في دفاتر المجموعة، فتقرأها الودجات والساعة كما يقرأها التطبيق.
    var hijriOffset: Int {
        get { Hijri.clamped(defaults.integer(forKey: Hijri.offsetKey)) }
        set {
            defaults.set(Hijri.clamped(newValue), forKey: Hijri.offsetKey)
            objectWillChange.send()
        }
    }
}
#endif
