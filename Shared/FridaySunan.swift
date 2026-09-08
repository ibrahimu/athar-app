import Foundation

// MARK: - سنن يوم الجمعة
//
// السنن هنا بيانات لا نصوص: العنوان والوصف من كلامنا، والدليل معرّفٌ يُحلّ متنُه
// من hadith.json عند العرض. فلا يُكتب في هذا الملف حرفٌ من حديث.

struct FridaySunnah: Identifiable, Hashable {
    let id: String
    let title: String
    /// سطرٌ قصير يقول «لِمَ» لا «كيف».
    let detail: String
    let icon: String
    /// معرّف الحديث في hadith.json. يبقى فارغًا لسنّةٍ لم نجد لها في بيانات
    /// التطبيق دليلًا — وترك الموضع خاليًا أصدق من ملئه بما لا نملكه.
    let hadith: String?
}

enum FridaySunan {
    /// المشهور من سننها، مرتَّبةً كما يمرّ بها اليوم: طهورٌ في أوّله، ثم رواحٌ،
    /// ثم قرآنٌ وذكرٌ ودعاءٌ في آخره.
    static let all: [FridaySunnah] = [
        FridaySunnah(id: "ghusl",
                     title: loc("الغسل"),
                     detail: loc("اغتسل قبل رواحك إلى الجمعة"),
                     icon: "drop.fill",
                     hadith: "r1152"),
        FridaySunnah(id: "tib",
                     title: loc("التطيّب والسواك"),
                     detail: loc("تطيَّب واستَكْ قبل خروجك"),
                     icon: "sparkles",
                     hadith: "r1154"),
        // لبس أحسن الثياب سنّةٌ مشهورة، وحديثُها في السنن لا في رياض الصالحين
        // ولا في الأربعين — فبقي موضع الدليل خاليًا ولم يُختلق له عزو.
        FridaySunnah(id: "thawb",
                     title: loc("لبس أحسن الثياب"),
                     detail: loc("ثوبٌ لجمعتك غير ثياب مهنتك"),
                     icon: "tshirt.fill",
                     hadith: nil),
        FridaySunnah(id: "bukur",
                     title: loc("التبكير إلى المسجد"),
                     detail: loc("كلّما بكّرت كان أجرك أوفر"),
                     icon: "figure.walk",
                     hadith: "r1155"),
        // وكذلك قراءة الكهف يوم الجمعة: بيانات التطبيق ليس فيها إلا فضل السورة
        // نفسها (surah_virtues.json)، وهو ما تعرضه الشاشة — لا دليلًا على اليوم.
        FridaySunnah(id: "kahf",
                     title: loc("قراءة سورة الكهف"),
                     detail: loc("سنّة يومك من القرآن — تُحتسب لك إذا أتممتها"),
                     icon: "book.closed.fill",
                     hadith: nil),
        FridaySunnah(id: "salawat",
                     title: loc("الإكثار من الصلاة على النبي ﷺ"),
                     detail: loc("أكثِر من الصلاة عليه ﷺ في يومك"),
                     icon: "heart.fill",
                     hadith: "r1158"),
        FridaySunnah(id: "saah",
                     title: loc("تحرّي ساعة الإجابة"),
                     detail: loc("تحيَّن الدعاء في آخر ساعة من النهار"),
                     icon: "hands.sparkles.fill",
                     hadith: "r1156"),
    ]

    static var count: Int { all.count }

    /// السنّة الوحيدة التي لا تُعلَّم باليد — يعرفها الدفتر اليومي من المصحف.
    static let kahfId = "kahf"

    static func sunnah(id: String) -> FridaySunnah? { all.first { $0.id == id } }
}

// MARK: - حصيلة اليوم

/// ما أُدّي من سنن الجمعة وما بقي — تقرؤها بطاقة «اليوم» وبطاقة المشاركة.
struct FridayProgress: Equatable {
    let done: Int
    let total: Int

    var fraction: Double { total > 0 ? Double(done) / Double(total) : 0 }
    var isComplete: Bool { total > 0 && done >= total }
    /// «3 من 7» — بأرقام غربية كبقيّة أرقام التطبيق.
    var text: String { loc("%1$@ من %2$@", done.counterText, total.counterText) }
}

// MARK: - المخزن

extension AtharStore {
    private enum JKey {
        static let sunanPrefix   = "athar.friday.sunan."
        static let salawatPrefix = "athar.friday.salawat."
    }

    /// جمعةُ هذا الأسبوع: يومُها إن كان اليوم جمعة، وإلا الجمعة القادمة — فمن فتح
    /// الشاشة يوم الخميس يستعدّ لجمعةٍ آتية لا يراجع جمعةً مضت. وبهذا تُمحى
    /// القائمة من نفسها مع دخول الأسبوع الجديد بلا مهمّةٍ في الخلفية.
    static func fridayKey(_ date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let ahead = (6 - cal.component(.weekday, from: date) + 7) % 7   // الجمعة = 6
        return dayKey(cal.date(byAdding: .day, value: ahead, to: date) ?? date)
    }

    /// كم يومًا يفصلك عن الجمعة (صفرٌ يوم الجمعة نفسه).
    static func daysUntilFriday(_ date: Date = Date()) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return (6 - cal.component(.weekday, from: date) + 7) % 7
    }

    /// هل أُدّيت هذه السنّة في جمعة هذا الأسبوع؟
    /// والكهف يعرفه الدفتر اليومي وحده: من أتمّها في المصحف فقد أدّاها وإن لم يضع
    /// العلامة بيده — فلا يُسأل عن شيءٍ قد فعله، ولا تُنزع منه قراءةٌ بضغطة.
    func isFridaySunnahDone(_ id: String, on day: Date = Date()) -> Bool {
        if id == FridaySunan.kahfId { return ledger(for: day).kahf }
        return (defaults.stringArray(forKey: JKey.sunanPrefix + Self.fridayKey(day)) ?? []).contains(id)
    }

    func setFridaySunnah(_ done: Bool, id: String, on day: Date = Date()) {
        // الكهف ليس له في هذه القائمة موضعٌ يُكتب: مصدره الدفتر، فلو كُتب هنا
        // لصار للسنّة الواحدة مصدران يختلفان.
        guard id != FridaySunan.kahfId else { return }
        let key = JKey.sunanPrefix + Self.fridayKey(day)
        let isNewWeek = defaults.object(forKey: key) == nil
        var list = defaults.stringArray(forKey: key) ?? []
        if done {
            guard !list.contains(id) else { return }
            list.append(id)
        } else {
            list.removeAll { $0 == id }
        }
        if list.isEmpty { defaults.removeObject(forKey: key) } else { defaults.set(list, forKey: key) }
        // جمعةٌ واحدة تكفي: ما سبقها يُكنس عند أول علامةٍ في الأسبوع الجديد، فلا
        // تتراكم في التفضيلات قائمةٌ عن كل أسبوع مضى.
        if isNewWeek { sweep(JKey.sunanPrefix, keeping: key) }
        objectWillChange.send()
    }

    var fridayProgress: FridayProgress {
        FridayProgress(done: FridaySunan.all.filter { isFridaySunnahDone($0.id) }.count,
                       total: FridaySunan.count)
    }

    // MARK: عدّ الصلاة على النبي ﷺ

    /// عدّ اليوم وحده — مفتاحه يومُه، فيبدأ الغد من صفر بلا تصفيرٍ يدوي.
    var fridaySalawatCount: Int {
        get { defaults.integer(forKey: JKey.salawatPrefix + Self.dayKey(Date())) }
        set {
            let key = JKey.salawatPrefix + Self.dayKey(Date())
            if newValue <= 0 { defaults.removeObject(forKey: key) } else { defaults.set(newValue, forKey: key) }
            objectWillChange.send()
        }
    }

    func addFridaySalawat(_ n: Int = 1) {
        let key = JKey.salawatPrefix + Self.dayKey(Date())
        let isNewDay = defaults.object(forKey: key) == nil
        fridaySalawatCount = max(0, fridaySalawatCount + n)
        if isNewDay { sweep(JKey.salawatPrefix, keeping: key) }
    }

    /// يُبقي مفتاحًا واحدًا من عائلته ويمحو ما سواه.
    private func sweep(_ prefix: String, keeping key: String) {
        for k in defaults.dictionaryRepresentation().keys where k.hasPrefix(prefix) && k != key {
            defaults.removeObject(forKey: k)
        }
    }
}
