import Foundation
import SwiftUI

// MARK: - سِمة القراءة

/// «الوضع الليلي يصير عكس: الكلام أبيض والورق داكن» — بطلب المستخدم.
enum ReadingTheme: String, CaseIterable, Identifiable {
    case paper      // ورق فاتح وحبر داكن
    case sepia      // ورق دافئ يريح في الإضاءة الخافتة
    case night      // ورق أزرق داكن وحبر أبيض

    var id: String { rawValue }
    var title: String { loc("theme_" + rawValue) }
    var shortTitle: String { title }
    var detail: String {
        switch self {
        case .paper: return "حبر داكن على ورق فاتح"
        case .sepia: return "أدفأ للعين في الإضاءة الخافتة"
        case .night: return "حبر أبيض على ورق أزرق داكن"
        }
    }
}

// MARK: - حالة الحفظ لآية

/// صناديق ليتنر: كلما ثبتت الآية ارتفع صندوقها وطال موعد مراجعتها،
/// وإذا تعثّر فيها رجعت إلى الصندوق الأول لتعود سريعًا.
struct MemoryCard: Codable, Hashable {
    var box: Int              // ٠ = جديدة، ثم ١..٥
    var dueDay: Int           // اليوم المطلق للمراجعة القادمة
    var lapses: Int           // كم مرة تعثّر فيها
    var reps: Int             // كم مرة راجعها بنجاح

    static let intervals = [0, 1, 3, 7, 16, 35]   // بالأيام لكل صندوق

    static func new(today: Int) -> MemoryCard {
        MemoryCard(box: 0, dueDay: today, lapses: 0, reps: 0)
    }

    /// نجح في الاسترجاع: ارفع الصندوق وباعد الموعد.
    mutating func passed(today: Int) {
        box = min(box + 1, Self.intervals.count - 1)
        reps += 1
        dueDay = today + Self.intervals[box]
    }

    /// تعثّر: أرجعها للبداية لتتكرر عليه اليوم نفسه.
    mutating func stumbled(today: Int) {
        box = 0
        lapses += 1
        dueDay = today
    }

    var isMemorized: Bool { box >= 3 }
}

// MARK: - المخزن

extension AtharStore {

    private enum MKey {
        static let lastRead      = "athar.mushaf.lastRead"
        static let bookmarks     = "athar.mushaf.bookmarks"
        static let theme         = "athar.mushaf.theme"
        static let fontScale     = "athar.mushaf.fontScale"
        static let cards         = "athar.hifz.cards"
        static let repeatCount   = "athar.hifz.repeatCount"
        static let wirdTarget    = "athar.wird.ayahsPerDay"
        static let wirdDone      = "athar.wird.doneToday"
        static let wirdDay       = "athar.wird.dayStamp"
        static let wirdEnabled   = "athar.wird.enabled"
        static let wirdMinutes   = "athar.wird.reminderMinutes"
        static let highlights    = "athar.mushaf.highlights"
        static let readingMode   = "athar.mushaf.readingMode"
        static let khatmahDays   = "athar.khatmah.totalDays"
        static let khatmahStart  = "athar.khatmah.startDay"
        static let khatmahDone   = "athar.khatmah.pagesDone"
        static let khatmahMode   = "athar.khatmah.mode"
        static let khatmahDayBase   = "athar.khatmah.dayBaseIndex"
        static let khatmahDayBasePg = "athar.khatmah.dayBasePages"
        static let stopMark      = "athar.mushaf.stopMark"
    }

    /// عدد الأيام منذ مرجع ثابت — أساس جدولة المراجعة.
    static func dayNumber(_ date: Date = Date()) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86400)
    }

    // MARK: القراءة

    var lastRead: AyahRef? {
        get {
            guard let d = defaults.data(forKey: MKey.lastRead) else { return nil }
            return try? JSONDecoder().decode(AyahRef.self, from: d)
        }
        set {
            if let v = newValue, let d = try? JSONEncoder().encode(v) {
                defaults.set(d, forKey: MKey.lastRead)
            } else {
                defaults.removeObject(forKey: MKey.lastRead)
            }
            objectWillChange.send()
        }
    }

    var readingTheme: ReadingTheme {
        get { ReadingTheme(rawValue: defaults.string(forKey: MKey.theme) ?? "") ?? .paper }
        set { defaults.set(newValue.rawValue, forKey: MKey.theme); objectWillChange.send() }
    }

    var mushafFontScale: Double {
        get {
            let v = defaults.double(forKey: MKey.fontScale)
            return v == 0 ? 1.0 : max(0.7, min(2.2, v))
        }
        set { defaults.set(max(0.7, min(2.2, newValue)), forKey: MKey.fontScale); objectWillChange.send() }
    }

    // MARK: العلامات

    var bookmarks: [AyahRef] {
        get {
            guard let d = defaults.data(forKey: MKey.bookmarks),
                  let v = try? JSONDecoder().decode([AyahRef].self, from: d) else { return [] }
            return v
        }
        set {
            if let d = try? JSONEncoder().encode(newValue.sorted()) {
                defaults.set(d, forKey: MKey.bookmarks)
            }
            objectWillChange.send()
        }
    }

    func isBookmarked(_ ref: AyahRef) -> Bool { bookmarks.contains(ref) }

    func toggleBookmark(_ ref: AyahRef) {
        var b = bookmarks
        if let i = b.firstIndex(of: ref) { b.remove(at: i) } else { b.append(ref) }
        bookmarks = b
    }

    /// نمط عرض المصحف: صفحة متصلة، أو صفحة داخل إطار، أو آية آية.
    var readingMode: ReadingMode {
        get { ReadingMode(rawValue: defaults.string(forKey: MKey.readingMode) ?? "") ?? .page }
        set { defaults.set(newValue.rawValue, forKey: MKey.readingMode); objectWillChange.send() }
    }

    /// «وقفتُ هنا» — علامة يضعها القارئ بيده ليعود إليها، مستقلة عن
    /// آخر موضع تلقائي؛ فالتصفح لا يضيّع موضع القراءة الحقيقي.
    var stopMark: AyahRef? {
        get {
            guard let d = defaults.data(forKey: MKey.stopMark) else { return nil }
            return try? JSONDecoder().decode(AyahRef.self, from: d)
        }
        set {
            if let v = newValue, let d = try? JSONEncoder().encode(v) {
                defaults.set(d, forKey: MKey.stopMark)
            } else {
                defaults.removeObject(forKey: MKey.stopMark)
            }
            objectWillChange.send()
        }
    }

    // MARK: التظليل

    /// آيات مظلَّلة بلون — كما يُظلّل القارئ في مصحفه الورقي.
    /// المفتاح مرجع الآية، والقيمة اسم اللون.
    var highlights: [String: String] {
        get {
            guard let d = defaults.data(forKey: MKey.highlights),
                  let v = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
            return v
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) { defaults.set(d, forKey: MKey.highlights) }
            objectWillChange.send()
        }
    }

    func highlight(_ ref: AyahRef) -> HighlightColor? {
        highlights[ref.id].flatMap(HighlightColor.init(rawValue:))
    }

    func setHighlight(_ color: HighlightColor?, for ref: AyahRef) {
        var all = highlights
        if let color { all[ref.id] = color.rawValue } else { all.removeValue(forKey: ref.id) }
        highlights = all
    }

    var highlightedRefs: [AyahRef] {
        highlights.keys.compactMap { key in
            let p = key.split(separator: ":")
            guard p.count == 2, let s = Int(p[0]), let a = Int(p[1]) else { return nil }
            return AyahRef(surah: s, ayah: a)
        }.sorted()
    }

    // MARK: الحفظ

    var memoryCards: [String: MemoryCard] {
        get {
            guard let d = defaults.data(forKey: MKey.cards),
                  let v = try? JSONDecoder().decode([String: MemoryCard].self, from: d) else { return [:] }
            return v
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) { defaults.set(d, forKey: MKey.cards) }
            objectWillChange.send()
        }
    }

    func card(for ref: AyahRef) -> MemoryCard? { memoryCards[ref.id] }

    func recordReview(_ ref: AyahRef, passed: Bool) {
        let today = Self.dayNumber()
        var all = memoryCards
        var c = all[ref.id] ?? .new(today: today)
        if passed { c.passed(today: today) } else { c.stumbled(today: today) }
        all[ref.id] = c
        memoryCards = all
    }

    /// إضافةٌ إلى الحفظ ببطاقةٍ جديدة موعدها اليوم — لا «مراجعةً راسبة».
    /// المراجعة الراسبة تستدعي `stumbled` فتُولَد البطاقة بـ `lapses = 1`،
    /// فتزعم شاشة الحفظ «تعثّرت فيها ١ مرة» في آيةٍ لم تُعرَض عليه قط.
    /// الموجودة لا تُمَسّ حتى لا تُمحى مراجعاتها بإضافةٍ مكرّرة.
    func enroll(_ refs: [AyahRef]) {
        let today = Self.dayNumber()
        var all = memoryCards
        for r in refs where all[r.id] == nil { all[r.id] = .new(today: today) }
        memoryCards = all
    }

    func forget(_ ref: AyahRef) {
        var all = memoryCards
        all.removeValue(forKey: ref.id)
        memoryCards = all
    }

    /// الآيات المستحقة للمراجعة اليوم، الأقدم استحقاقًا أولًا.
    var dueForReview: [AyahRef] {
        let today = Self.dayNumber()
        return memoryCards
            .filter { $0.value.dueDay <= today }
            .sorted { ($0.value.dueDay, $0.key) < ($1.value.dueDay, $1.key) }
            .compactMap { key, _ in
                let p = key.split(separator: ":")
                guard p.count == 2, let s = Int(p[0]), let a = Int(p[1]) else { return nil }
                return AyahRef(surah: s, ayah: a)
            }
    }

    var memorizedCount: Int { memoryCards.values.filter(\.isMemorized).count }

    /// كم مرة تتكرر الآية أثناء التلقين قبل الاختبار.
    var hifzRepeatCount: Int {
        get { max(1, defaults.integer(forKey: MKey.repeatCount) == 0 ? 5 : defaults.integer(forKey: MKey.repeatCount)) }
        set { defaults.set(max(1, newValue), forKey: MKey.repeatCount); objectWillChange.send() }
    }

    // MARK: تحدي الختمة

    /// خطة ختمة نشطة؟ صفر أيام = لا خطة.
    var khatmahTotalDays: Int {
        get { defaults.integer(forKey: MKey.khatmahDays) }
        set { defaults.set(max(0, newValue), forKey: MKey.khatmahDays); objectWillChange.send() }
    }

    var khatmahStartDay: Int {
        get { defaults.integer(forKey: MKey.khatmahStart) }
        set { defaults.set(newValue, forKey: MKey.khatmahStart); objectWillChange.send() }
    }

    /// صفحات قُرئت من أول المصحف — الختمة تتقدّم بالترتيب.
    var khatmahPagesDone: Int {
        get { min(Quran.pageCount, defaults.integer(forKey: MKey.khatmahDone)) }
        set { defaults.set(min(Quran.pageCount, max(0, newValue)), forKey: MKey.khatmahDone); objectWillChange.send() }
    }

    var khatmahMode: KhatmahMode {
        get { KhatmahMode(rawValue: defaults.string(forKey: MKey.khatmahMode) ?? "") ?? .open }
        set { defaults.set(newValue.rawValue, forKey: MKey.khatmahMode); objectWillChange.send() }
    }

    var khatmahActive: Bool { khatmahTotalDays > 0 }

    /// القارئ بلغ صفحة: إن كانت الصفحة التي تلي «الصفحة التالية في الختمة» مباشرةً
    /// فقد أُتمَّت تلك الصفحة فتُحتسب. خطوة واحدة فقط ولا قفز، حتى لا يُحتسب
    /// فتحُ سورةٍ بعيدة قراءةً لكل ما قبلها.
    func noteReaderPage(_ page: Int) {
        guard khatmahActive, page == khatmahPagesDone + 2 else { return }
        khatmahPagesDone = page - 1
    }

    func startKhatmah(days: Int, mode: KhatmahMode) {
        khatmahTotalDays = days
        khatmahStartDay = Self.dayNumber()
        khatmahPagesDone = 0
        khatmahMode = mode
        // اليوم الأول يبدأ من الصفر: نثبّت أساسه هنا — في فعل زرّ لا في رسم واجهة.
        defaults.set(1, forKey: MKey.khatmahDayBase)
        defaults.set(0, forKey: MKey.khatmahDayBasePg)
    }

    func cancelKhatmah() {
        khatmahTotalDays = 0
        khatmahPagesDone = 0
        defaults.removeObject(forKey: MKey.khatmahDayBase)
        defaults.removeObject(forKey: MKey.khatmahDayBasePg)
    }

    /// صفحات كل يوم — تقسيم ٦٠٤ على الأيام مع رفع الكسر.
    var khatmahPagesPerDay: Int {
        guard khatmahTotalDays > 0 else { return 0 }
        return Int((Double(Quran.pageCount) / Double(khatmahTotalDays)).rounded(.up))
    }

    /// اليوم الحالي في الخطة (١ فأعلى) — مقيَّد بمدة الخطة حتى لا يُطبع
    /// «اليوم ٤٥ من ٣٠» بعد انقضاء المدة.
    var khatmahDayIndex: Int {
        let d = max(1, Self.dayNumber() - khatmahStartDay + 1)
        return khatmahTotalDays > 0 ? min(d, khatmahTotalDays) : d
    }

    /// مدى صفحات اليوم: من آخر ما قُرئ إلى هدف اليوم.
    var khatmahTodayRange: ClosedRange<Int> {
        let target = min(Quran.pageCount, khatmahDayIndex * khatmahPagesPerDay)
        let from = min(khatmahPagesDone + 1, Quran.pageCount)
        return from...max(from, target)
    }

    /// صفحات كانت مقروءة عند دخول يوم الخطة الحالي — أساس شريط «ورد اليوم».
    /// لا بدّ من أساس ثابت لا يتحرّك مع كل صفحة تُقرأ: لو قِسنا المقروء من
    /// أرضية الخطة لبقي شريط المتأخّر صفرًا مهما قرأ. والقراءة هنا بلا كتابة
    /// لأنها تُستدعى من جسم الواجهة؛ التثبيت في refreshKhatmahDayBase().
    var khatmahDayBasePages: Int {
        guard defaults.integer(forKey: MKey.khatmahDayBase) == khatmahDayIndex else {
            // لم يُثبَّت أساس هذا اليوم بعد — أساسه ما قُرئ حتى الآن، وهو عين
            // ما ستحفظه refreshKhatmahDayBase() عند أول ظهور للشاشة.
            return khatmahPagesDone
        }
        return min(khatmahPagesDone, defaults.integer(forKey: MKey.khatmahDayBasePg))
    }

    /// تثبيت أساس اليوم عند تبدّل يوم الخطة. يُستدعى من ‎.task‎ لا من جسم
    /// الواجهة، فالكتابة في التخزين أثناء الرسم أثر جانبي لا يصحّ.
    func refreshKhatmahDayBase() {
        guard khatmahActive else { return }
        let idx = khatmahDayIndex
        guard defaults.integer(forKey: MKey.khatmahDayBase) != idx else { return }
        defaults.set(idx, forKey: MKey.khatmahDayBase)
        defaults.set(khatmahPagesDone, forKey: MKey.khatmahDayBasePg)
        objectWillChange.send()
    }

    /// موجب = متقدّم على الخطة، سالب = متأخّر، صفر = ضمن نطاق اليوم.
    /// النطاق: متأخّر إن قرأ أقل من ورد الأمس، متقدّم إن تجاوز ورد اليوم.
    /// الحدّان يُقسَمان بالنسبة لا بورد مرفوع الكسر: مع الرفع تتجاوز أرضيةُ
    /// أواخر الأيام الـ٦٠٤ فتنطبق على خط النهاية، فيُقال للملتزم «متأخّر»
    /// في آخر أيام خطته كلها.
    var khatmahDelta: Int {
        guard khatmahTotalDays > 0 else { return 0 }
        let n = khatmahTotalDays
        let floor = Quran.pageCount * (khatmahDayIndex - 1) / n                          // ورد نهاية الأمس
        let ceil = min(Quran.pageCount, (Quran.pageCount * khatmahDayIndex + n - 1) / n) // ورد نهاية اليوم
        if khatmahPagesDone < floor { return khatmahPagesDone - floor }  // متأخّر
        if khatmahPagesDone > ceil { return khatmahPagesDone - ceil }    // متقدّم
        return 0                                                          // على الخطة
    }

    // MARK: الورد اليومي

    var wirdTarget: Int {
        get { max(1, defaults.integer(forKey: MKey.wirdTarget) == 0 ? 10 : defaults.integer(forKey: MKey.wirdTarget)) }
        set { defaults.set(max(1, newValue), forKey: MKey.wirdTarget); objectWillChange.send() }
    }

    var wirdDoneToday: Int {
        get {
            guard defaults.string(forKey: MKey.wirdDay) == Self.dayStamp() else { return 0 }
            return defaults.integer(forKey: MKey.wirdDone)
        }
        set {
            defaults.set(Self.dayStamp(), forKey: MKey.wirdDay)
            defaults.set(newValue, forKey: MKey.wirdDone)
            objectWillChange.send()
        }
    }

    func advanceWird(by n: Int = 1) { wirdDoneToday += n }

    var wirdEnabled: Bool {
        get { defaults.bool(forKey: MKey.wirdEnabled) }
        set { defaults.set(newValue, forKey: MKey.wirdEnabled); objectWillChange.send() }
    }

    var wirdReminderMinutes: Int {
        get { defaults.integer(forKey: MKey.wirdMinutes) == 0 ? 20 * 60 : defaults.integer(forKey: MKey.wirdMinutes) }
        set { defaults.set(newValue, forKey: MKey.wirdMinutes); objectWillChange.send() }
    }
}

/// ألوان التظليل — هادئة تكفي لتمييز الآية دون أن تطغى على النص.
enum HighlightColor: String, CaseIterable, Identifiable {
    case amber, green, sky, rose, violet

    var id: String { rawValue }
    var title: String {
        switch self {
        case .amber:  return "كهرماني"
        case .green:  return "أخضر"
        case .sky:    return "سماوي"
        case .rose:   return "وردي"
        case .violet: return "بنفسجي"
        }
    }

    /// شفافية منخفضة عمدًا: التظليل يميّز ولا يحجب.
    func color(dark: Bool) -> Color {
        let hex: UInt32
        switch self {
        case .amber:  hex = dark ? 0xE0B06A : 0xF2C46B
        case .green:  hex = dark ? 0x6FD3A6 : 0x86D9B0
        case .sky:    hex = dark ? 0x7FB6E0 : 0x9AC9EC
        case .rose:   hex = dark ? 0xE39BB4 : 0xF0AEC4
        case .violet: hex = dark ? 0xB4A7E8 : 0xC4B8F0
        }
        return Color(hex: hex).opacity(dark ? 0.26 : 0.42)
    }
}


/// أنماط عرض المصحف الثلاثة.
enum ReadingMode: String, CaseIterable, Identifiable {
    case page    // نص متصل كصفحة المصحف المطبوع
    case framed  // الصفحة نفسها داخل إطار مزخرف كالمصحف المطبوع
    case ayah    // كل آية في سطرها، أوضح للقراءة والتدبّر

    var id: String { rawValue }

    var title: String {
        switch self {
        case .page:   return loc("modePage")
        case .framed: return loc("modeFramed")
        case .ayah:   return loc("modeAyah")
        }
    }

    var icon: String {
        switch self {
        case .page:   return "book.pages.fill"
        case .framed: return "rectangle.portrait.inset.filled"
        case .ayah:   return "list.bullet"
        }
    }
}


/// كيف يوزّع القارئ ورد يومه — عرض إرشادي داخل الشاشة.
enum KhatmahMode: String, CaseIterable, Identifiable {
    case open, prayers, morningEvening

    var id: String { rawValue }
    var title: String {
        switch self {
        case .open:           return "مفتوح"
        case .prayers:        return "مع الصلوات"
        case .morningEvening: return "صباح ومساء"
        }
    }
    var detail: String {
        switch self {
        case .open:           return "اقرأ وردك متى تيسّر لك"
        case .prayers:        return "قسّم الورد على الصلوات الخمس"
        case .morningEvening: return "نصف بعد الفجر ونصف بعد المغرب"
        }
    }
    var slotNames: [String] {
        switch self {
        case .open:           return []
        case .prayers:        return ["الفجر", "الظهر", "العصر", "المغرب", "العشاء"]
        case .morningEvening: return ["الصباح", "المساء"]
        }
    }
}
