import Foundation

// MARK: - خطة الختمة بموعد

// الختمة بالمدة تسأل «في كم يومًا تختم؟»، وهذه تسأل «متى تريد أن تختم؟» —
// وبين السؤالين فرقٌ في النفس: من نوى الختم مع آخر رمضان لا يعدّ الأيام بل
// ينظر إلى الهلال. فيُقسَم ما بقي — لا المصحف كله — على ما بقي من أيام،
// ويُعاد القسم كل صباح من موضعه الحقيقي لا من أرضية الخطة، فلا تُكتب أيامه
// الماضية من جديد ولا يُطالَب بما فات مرّتين.

extension AtharStore {

    private enum PKey {
        static let target       = "athar.khatmah.plan.targetDay"
        static let anchorDay    = "athar.khatmah.plan.anchorDay"
        static let anchorPages  = "athar.khatmah.plan.anchorPages"
        static let dayStamp     = "athar.khatmah.plan.dayStamp"
        static let dayBase      = "athar.khatmah.plan.dayBasePages"
        static let reminder     = "athar.khatmah.plan.reminder"
        static let reminderMins = "athar.khatmah.plan.reminderMinutes"
    }

    // MARK: الموعد

    /// يوم الختم المنشود بالعدّ المطلق للأيام — صفر يعني بلا موعد.
    private var khatmahTargetDay: Int { defaults.integer(forKey: PKey.target) }

    private var khatmahAnchorDay: Int { defaults.integer(forKey: PKey.anchorDay) }

    private var khatmahAnchorPages: Int {
        min(Quran.pageCount, max(0, defaults.integer(forKey: PKey.anchorPages)))
    }

    /// خطةٌ بموعدٍ قائمة؟ الخطة تتبع ختمتها: ختمةٌ جديدة تبدأ بعد مرساها تُسقطها
    /// من نفسها، فلا يُقاس تقدّم اليوم على مرسى ختمةٍ انقضت ولا يُقال للمبتدئ
    /// «متأخّر ٣٠٠ صفحة» في أول يومه.
    var khatmahPlanActive: Bool {
        khatmahActive && khatmahTargetDay > 0 && khatmahAnchorDay >= khatmahStartDay
    }

    /// تاريخ الختم المنشود. يُشتقّ إزاحةً عن يوم المستخدم لا من طابعٍ بالثواني:
    /// الطابع المحسوب من منتصف ليل غرينتش يقع قبل منتصف ليل صاحبه غربَ خطّه
    /// فيرتدّ التاريخ يومًا كاملًا إلى الوراء.
    var khatmahTargetDate: Date? {
        guard khatmahTargetDay > 0 else { return nil }
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: khatmahTargetDay - Self.dayNumber(),
                        to: cal.startOfDay(for: Date()))
    }

    /// يضع الموعد ويرسي الخطة على موضعه اليوم. المرسى لا يُمَسّ بعدها: تبديل
    /// الهدف يغيّر ما بقي من الطريق ولا يعيد كتابة ما قُطع منه.
    func setKhatmahTarget(_ date: Date) {
        let today = Self.dayNumber()
        defaults.set(max(today, Self.dayNumber(date)), forKey: PKey.target)
        defaults.set(today, forKey: PKey.anchorDay)
        defaults.set(khatmahPagesDone, forKey: PKey.anchorPages)
        // أساس اليوم يُثبَّت مع الموعد نفسه، وإلا بقي نصيب اليوم يتقلّص مع كل
        // صفحة يقرؤها حتى ينتهي إلى صفر قبل أن يبلغ آخره.
        defaults.set(today, forKey: PKey.dayStamp)
        defaults.set(khatmahPagesDone, forKey: PKey.dayBase)
        objectWillChange.send()
    }

    func clearKhatmahTarget() {
        for key in [PKey.target, PKey.anchorDay, PKey.anchorPages, PKey.dayStamp, PKey.dayBase] {
            defaults.removeObject(forKey: key)
        }
        objectWillChange.send()
    }

    /// الأيام الباقية حتى الموعد ويومُه منها — فيوم الختم آخرها لا الذي يليه.
    var khatmahPlanDaysLeft: Int { max(1, khatmahTargetDay - Self.dayNumber() + 1) }

    /// مضى الموعد ولم تتمّ الختمة — يُقال له صراحةً بدل «بقي اليوم فقط» كل يوم.
    var khatmahPlanOverdue: Bool { khatmahPlanActive && khatmahTargetDay < Self.dayNumber() }

    // MARK: نصيب اليوم

    /// صفحات كانت مقروءة عند دخول اليوم — أساس نصيبه وشريطه. لا بدّ من أساس
    /// ثابت: لو قِسنا من موضعه المتحرّك لتقلّص نصيب اليوم كلما قرأ صفحة. والقراءة
    /// هنا بلا كتابة لأنها تُستدعى من جسم الواجهة؛ التثبيت في refreshKhatmahPlanDayBase().
    var khatmahPlanDayBasePages: Int {
        guard defaults.integer(forKey: PKey.dayStamp) == Self.dayNumber() else { return khatmahPagesDone }
        return min(khatmahPagesDone, defaults.integer(forKey: PKey.dayBase))
    }

    /// تثبيت أساس اليوم عند تبدّل اليوم. يُستدعى من ‎.task‎ لا من جسم الواجهة،
    /// فالكتابة في التخزين أثناء الرسم أثر جانبي يعيد الرسم بلا نهاية.
    func refreshKhatmahPlanDayBase() {
        guard khatmahPlanActive else { return }
        let today = Self.dayNumber()
        guard defaults.integer(forKey: PKey.dayStamp) != today else { return }
        defaults.set(today, forKey: PKey.dayStamp)
        defaults.set(khatmahPagesDone, forKey: PKey.dayBase)
        objectWillChange.send()
    }

    /// ما كان ينبغي أن يبلغه عند فجر يومٍ ما لو سار على خطّه المستقيم من المرسى
    /// إلى الموعد — أرضيةُ الحساب لا حكمٌ عليه.
    private func khatmahPlanExpected(onDay day: Int) -> Int {
        let span = max(1, khatmahTargetDay - khatmahAnchorDay + 1)
        let gone = min(span, max(0, day - khatmahAnchorDay))
        let total = max(0, Quran.pageCount - khatmahAnchorPages)
        return khatmahAnchorPages + total * gone / span
    }

    /// نصيب يومٍ من الصفحات: يومُه من موضعه الحقيقي، وما بعده من موضعه المرتقب
    /// لو سار على خطّه — فالتذكير يُكتب قبل أوانه ولا سبيل إلى علم ما سيقرأ.
    func khatmahPlanShare(daysFromNow n: Int = 0) -> Int {
        guard khatmahPlanActive else { return 0 }
        let day = Self.dayNumber() + n
        guard day <= khatmahTargetDay else { return 0 }
        let read = n == 0 ? khatmahPlanDayBasePages : khatmahPlanExpected(onDay: day)
        let remaining = max(0, Quran.pageCount - read)
        guard remaining > 0 else { return 0 }
        let left = max(1, khatmahTargetDay - day + 1)
        return min(remaining, (remaining + left - 1) / left)
    }

    var khatmahPlanShareToday: Int { khatmahPlanShare() }

    /// نطاق صفحات اليوم بحسب الموعد: من موضعه الآن إلى آخر نصيب يومه.
    var khatmahPlanTodayRange: ClosedRange<Int> {
        let base = khatmahPlanDayBasePages
        let upper = min(Quran.pageCount, base + khatmahPlanShareToday)
        let from = min(khatmahPagesDone + 1, Quran.pageCount)
        return from...max(from, upper)
    }

    /// موجب = متقدّم على موعده، سالب = متأخّر، صفر = في نطاق يومه. الحدّان
    /// أرضيةُ الأمس وسقف اليوم كما في تحدّي المدة، حتى لا يتبدّل الحكم بين
    /// الشاشتين على قارئٍ واحد لم يتحرّك من مكانه.
    var khatmahPlanDelta: Int {
        guard khatmahPlanActive else { return 0 }
        let today = Self.dayNumber()
        let floorPages = khatmahPlanExpected(onDay: today)
        let ceilPages = min(Quran.pageCount, khatmahPlanExpected(onDay: today + 1))
        if khatmahPagesDone < floorPages { return khatmahPagesDone - floorPages }
        if khatmahPagesDone > ceilPages { return khatmahPagesDone - ceilPages }
        return 0
    }

    // MARK: التذكير

    var khatmahReminder: Bool {
        get { defaults.bool(forKey: PKey.reminder) }
        set { defaults.set(newValue, forKey: PKey.reminder); objectWillChange.send() }
    }

    /// دقائق من منتصف الليل — الافتراض ٢٠:٣٠: بعد العشاء وقبل أن يثقل النعاس.
    var khatmahReminderMinutes: Int {
        get {
            // الصفر دقيقةٌ صحيحة (منتصف الليل) لا «لا قيمة» — كان يرتدّ إلى ٨:٣٠ م.
            return (defaults.object(forKey: PKey.reminderMins) as? Int) ?? (20 * 60 + 30)
        }
        set { defaults.set(newValue, forKey: PKey.reminderMins); objectWillChange.send() }
    }

    // MARK: صياغات مشتركة

    /// تمييز العدد: صفحة واحدة، صفحتان، ثم جمع القلّة (٣–١٠)، ثم المفرد المنصوب.
    static func pagesText(_ n: Int) -> String {
        switch n {
        case 1:      return loc("صفحة واحدة")
        case 2:      return loc("صفحتان")
        case 3...10: return loc("%1$@ صفحات", n.counterText)
        default:     return loc("%1$@ صفحة", n.counterText)
        }
    }

    /// «بقي يومان» و«بقيت 5 أيام» و«بقي 21 يومًا» — العدد يقود صيغته وفعله.
    static func daysLeftText(_ n: Int) -> String {
        switch n {
        case ...1:   return loc("بقي اليوم وحده")
        case 2:      return loc("بقي يومان")
        case 3...10: return loc("بقيت %1$@ أيام", n.counterText)
        default:     return loc("بقي %1$@ يومًا", n.counterText)
        }
    }

    /// التاريخ الهجري بأرقام لاتينية كبقية أرقام التطبيق — «٠» الهندية تُقرأ
    /// نقطةً عند العرض فتلتبس بعلامة لا برقم.
    /// تاريخ الختم كما يراه صاحبه في تقويم التطبيق: بإزاحة المطالع، وإلا خالف الموعدُ
    /// المعروضُ في البطاقة شبكةَ التقويم في الشاشة المجاورة بيومٍ أو يومين.
    static func khatmahDateText(_ raw: Date) -> String {
        let date = Hijri.shifted(raw)
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.locale = Locale(identifier: "ar_SA@numbers=latn")
        let f = DateFormatter()
        f.calendar = cal
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: date) + " هـ"
    }

    /// آخر يوم من رمضان — لمن جعل ختمته مع الشهر. يتخطّى رمضان المنقضي إلى القادم،
    /// وطولُ الشهر من أم القرى لا من ثلاثين مفترضة.
    static func ramadanLastDay(from now: Date = Date()) -> Date? {
        let today = Calendar.current.startOfDay(for: now)
        let (year, _, _) = Occasions.hijriComponents(now)
        for y in [year, year + 1] {
            let last = Occasions.daysInMonth(year: y, month: 9)
            if let date = Occasions.date(year: y, month: 9, day: last), date > today { return date }
        }
        return nil
    }

    // MARK: جواب «أين ختمتي»

    /// جملة واحدة يقولها «سيري» ولا تتكرّر صياغتها في مكانين: السورة والصفحة
    /// والنسبة، ثم نصيب اليوم لمن له موعد. الصفحة هي القادمة لا الأخيرة —
    /// السائل يسأل عن موضع قدمه لا عن أثرها.
    func khatmahPositionPhrase() -> String {
        guard khatmahActive else {
            guard let last = stopMark ?? lastRead else {
                return loc("لم تبدأ ختمة بعد — ابدأها من قسم الختمة.")
            }
            return loc("آخر ما قرأت سورة %1$@، الصفحة %2$@.",
                       Quran.surah(last.surah)?.name ?? "", Quran.page(of: last).counterText)
        }
        guard khatmahPagesDone < Quran.pageCount else {
            return loc("تمّت ختمتك كاملة — تقبّل الله.")
        }
        let page = khatmahPagesDone + 1
        let ref = Quran.firstAyah(ofPage: page)
        let percent = Int((Double(khatmahPagesDone) / Double(Quran.pageCount) * 100).rounded())
        var phrase = loc("أنت في سورة %1$@، الصفحة %2$@ — أتممت %3$@٪ من ختمتك.",
                         Quran.surah(ref.surah)?.name ?? "", page.counterText, percent.counterText)
        let share = khatmahPlanShareToday
        if share > 0 { phrase += " " + loc("ووردك اليوم %1$@.", Self.pagesText(share)) }
        return phrase
    }
}
