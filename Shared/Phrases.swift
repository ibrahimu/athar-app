import Foundation

// MARK: - «عبارات»: نصوص جاهزة للنسخ والمشاركة في الحالات والقصص

/// أصناف العبارات. المفاتيح اللونية من لوحة Theme.accent(for:) الرسمية.
enum PhraseCategory: String, CaseIterable, Identifiable {
    case friday, morning, evening, dua, ayat, hadith, greetings, occasions, condolence, recovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .friday:     return "الجمعة"
        case .morning:    return "الصباح"
        case .evening:    return "المساء"
        case .dua:        return "أدعية"
        case .ayat:       return "آيات"
        case .hadith:     return "أحاديث"
        case .greetings:  return "تهانٍ"
        case .occasions:  return "مناسبات"
        case .condolence: return "مواساة"
        case .recovery:   return "شفاء"
        }
    }

    var icon: String {
        switch self {
        case .friday:     return "sparkles"
        case .morning:    return "sunrise.fill"
        case .evening:    return "moon.stars.fill"
        case .dua:        return "hands.sparkles.fill"
        case .ayat:       return "book.closed.fill"
        case .hadith:     return "text.quote"
        case .greetings:  return "gift.fill"
        case .occasions:  return "party.popper.fill"
        case .condolence: return "heart.fill"
        case .recovery:   return "cross.case.fill"
        }
    }

    var accentKey: String {
        switch self {
        case .friday:     return "gold"
        case .morning:    return "dawn"
        case .evening:    return "dusk"
        case .dua:        return "green"
        case .ayat:       return "sea"
        case .hadith:     return "asr"
        case .greetings:  return "calm"
        case .occasions:  return "gold"
        case .condolence: return "night"
        case .recovery:   return "success"
        }
    }
}

/// مصدر العبارة: النصوص الشرعية لا تُكتب هنا بل تُحلّ من بياناتها عند العرض،
/// فلا يختلف لفظها عمّا في المصحف وكتب الحديث وحصن المسلم بحرف.
enum PhraseSource: Hashable {
    case ayah(surah: Int, ayah: Int)
    case hadith(id: String)
    case dhikr(id: String)
    /// عبارة عادية (تهنئة أو مواساة) — ليست نصًّا شرعيًّا.
    case text(String)
}

struct Phrase: Identifiable, Hashable {
    let id: String
    let category: PhraseCategory
    /// المرجع بمعرّفه — هو المصدر، والنصّ والعزو أدناه محلولان منه مرّةً عند البناء.
    let source: PhraseSource
    /// اللفظ كما في مصدره؛ فارغ إن غاب المصدر من الحزمة (الساعة مثلًا).
    let text: String
    /// سطر العزو: «سورة X: N» أو تخريج الحديث أو مرجع الذكر. فارغ للعبارات العادية.
    let attribution: String

    /// يُحلّ النصّ والعزو هنا عند بناء المكتبة لا عند العرض: البحث في أذكار الحصن
    /// خطّي، وكان يتكرّر لكل بطاقة في كل رسمة.
    init(id: String, category: PhraseCategory, source: PhraseSource) {
        self.id = id
        self.category = category
        self.source = source
        self.text = Self.resolveText(source)
        self.attribution = Self.resolveAttribution(source)
    }

    /// نصّ شرعي يُعرض بخط النسخ لا بخط الواجهة.
    var isSacred: Bool {
        if case .text = source { return false }
        return true
    }

    private static func resolveText(_ source: PhraseSource) -> String {
        switch source {
        case .ayah(let s, let a): return Quran.text(AyahRef(surah: s, ayah: a)) ?? ""
        case .hadith(let id):     return HadithLibrary.hadith(id: id)?.text ?? ""
        case .dhikr(let id):      return AdhkarLibrary.allItems.first(where: { $0.id == id })?.text ?? ""
        case .text(let t):        return t
        }
    }

    private static func resolveAttribution(_ source: PhraseSource) -> String {
        switch source {
        case .ayah(let s, let a):
            guard let name = Quran.surah(s)?.name else { return "" }
            return "سورة \(name): \(a.counterText)"
        case .hadith(let id):
            return HadithLibrary.hadith(id: id)?.citation ?? ""
        case .dhikr(let id):
            guard let d = AdhkarLibrary.allItems.first(where: { $0.id == id }) else { return "" }
            return d.hasReference ? d.reference : "حصن المسلم"
        case .text:
            return ""
        }
    }

    /// ما يُنسخ ويُشارك: النص، وتحته العزو في سطر مستقل إن وُجد.
    var shareText: String {
        let a = attribution
        return a.isEmpty ? text : "\(text)\n\(a)"
    }

    var isAvailable: Bool { !text.isEmpty }

    /// عبارة يكتبها المستخدم بنفسه في مصمّم البطاقة — عامة، لا تُنسب إلى مصدر.
    static func custom(_ text: String, category: PhraseCategory = .greetings, id: String = "custom") -> Phrase {
        Phrase(id: id, category: category, source: .text(text))
    }
}

enum PhraseLibrary {

    /// الصنف الأنسب للحظة: الجمعة يومَها، وإلا الصباح قبل الظهر والمساء بعده.
    static func defaultCategory(date: Date = Date(), calendar: Calendar = .current) -> PhraseCategory {
        if calendar.component(.weekday, from: date) == 6 { return .friday }
        let hour = calendar.component(.hour, from: date)
        return (4..<12).contains(hour) ? .morning : .evening
    }

    static func phrases(in category: PhraseCategory?) -> [Phrase] {
        let pool = category.map { c in all.filter { $0.category == c } } ?? all
        return pool.filter(\.isAvailable)
    }

    private static func ayah(_ s: Int, _ a: Int, _ c: PhraseCategory) -> Phrase {
        Phrase(id: "a\(s)-\(a)", category: c, source: .ayah(surah: s, ayah: a))
    }
    private static func hadith(_ id: String, _ c: PhraseCategory) -> Phrase {
        Phrase(id: "h-\(id)", category: c, source: .hadith(id: id))
    }
    private static func dhikr(_ id: String, _ c: PhraseCategory) -> Phrase {
        Phrase(id: "d-\(id)", category: c, source: .dhikr(id: id))
    }
    private static func plain(_ n: Int, _ t: String, _ c: PhraseCategory) -> Phrase {
        Phrase(id: "t-\(n)", category: c, source: .text(t))
    }

    /// المعرّفات مأخوذة من quran.json وhadith.json وadhkar.json؛ العبارات المكتوبة هنا
    /// تهانٍ ومواساة عادية فقط، لا لفظ دعاء أو حديث.
    static let all: [Phrase] = [
        // الجمعة
        ayah(62, 9, .friday),
        hadith("r1147", .friday),          // خير يوم طلعت عليه الشمس
        hadith("r1397", .friday),          // من صلّى عليّ صلاة
        // r1045 لا r130: نصّ r130 يبدأ بترقيم النووي «الرابع عشر: عنه…» فيضيع الراوي على بطاقة مستقلة.
        hadith("r1045", .friday),          // الجمعة إلى الجمعة كفّارة
        dhikr("sl02", .friday),            // اللهم صلّ وسلّم على نبيّنا محمد
        ayah(18, 10, .friday),
        plain(1, "جمعة مباركة، تقبّل الله منا ومنكم صالح الأعمال", .friday),
        plain(2, "جمعة طيّبة، أكثروا فيها من الصلاة على النبي ﷺ", .friday),

        // الصباح
        dhikr("m06", .morning),
        dhikr("m09", .morning),
        dhikr("m13", .morning),
        dhikr("m14", .morning),
        dhikr("m15", .morning),
        dhikr("m20", .morning),
        dhikr("w01", .morning),
        hadith("r1451", .morning),         // من قال حين يصبح وحين يمسي

        // المساء
        dhikr("e06", .evening),
        dhikr("e09", .evening),
        dhikr("e10", .evening),
        dhikr("e13", .evening),
        dhikr("e15", .evening),
        dhikr("e17", .evening),
        dhikr("s01", .evening),
        dhikr("s09", .evening),

        // أدعية
        ayah(2, 201, .dua),
        ayah(3, 8, .dua),
        ayah(7, 23, .dua),
        ayah(14, 40, .dua),
        ayah(14, 41, .dua),
        ayah(25, 74, .dua),
        ayah(3, 38, .dua),
        dhikr("d01", .dua),
        dhikr("d03", .dua),
        dhikr("d05", .dua),
        dhikr("d06", .dua),
        dhikr("i02", .dua),
        dhikr("i03", .dua),
        dhikr("p10", .dua),
        dhikr("tr05", .dua),

        // آيات
        ayah(2, 286, .ayat),
        ayah(94, 6, .ayat),
        ayah(65, 3, .ayat),
        ayah(21, 87, .ayat),
        ayah(9, 129, .ayat),
        ayah(40, 60, .ayat),
        ayah(2, 186, .ayat),
        ayah(13, 28, .ayat),
        ayah(2, 152, .ayat),
        ayah(39, 53, .ayat),
        ayah(2, 45, .ayat),

        // أحاديث
        hadith("r1408", .hadith),          // كلمتان خفيفتان على اللسان
        hadith("r27", .hadith),            // عجبًا لأمر المؤمن
        hadith("r1428", .hadith),          // أقرب ما يكون العبد من ربه
        hadith("r236", .hadith),           // لا يؤمن أحدكم حتى يحب لأخيه
        hadith("r227", .hadith),           // من لا يرحم الناس
        hadith("r222", .hadith),           // المؤمن للمؤمن كالبنيان
        hadith("r1381", .hadith),          // من سلك طريقًا يلتمس فيه علمًا
        hadith("r48", .hadith),            // لا تغضب
        hadith("r636", .hadith),           // يسّروا ولا تعسّروا
        hadith("r1435", .hadith),          // أنا عند ظنّ عبدي بي
        // r1053 لا r123: نصّ r123 يبدأ بـ«السابع: عنه…» بلا راوٍ مسمّى.
        hadith("r1053", .hadith),          // من غدا إلى المسجد أو راح
        dhikr("t05", .hadith),

        // تهانٍ (عبارات عادية)
        plain(10, "كل عام وأنتم بخير", .greetings),
        plain(11, "رمضان مبارك، أعاده الله علينا وعليكم باليمن والبركات", .greetings),
        plain(12, "عيدكم مبارك، وتقبّل الله منا ومنكم", .greetings),
        plain(13, "مبارك زواجكم، جعله الله زواجًا مباركًا وحياة سعيدة", .greetings),
        plain(14, "مبارك ما رزقتم، جعله الله من الصالحين", .greetings),
        plain(15, "مبارك النجاح، وفّقكم الله لما يحب ويرضى", .greetings),
        plain(16, "حجّ مبرور، تقبّل الله حجّكم وردّكم سالمين", .greetings),
        plain(17, "عمرة مقبولة، تقبّل الله طاعتكم", .greetings),

        // مناسبات (عبارات عامة): العيدان ورمضان، واليوم الوطني ويوم التأسيس
        plain(40, "عيد فطر مبارك، تقبّل الله صيامكم وقيامكم، وكل عام وأنتم بخير", .occasions),
        plain(41, "كل عام وأنتم إلى الله أقرب — عيدكم مبارك وأيامكم سعيدة", .occasions),
        plain(42, "عيد أضحى مبارك، تقبّل الله طاعتكم وأعاده عليكم بالخير والبركة", .occasions),
        plain(43, "أضحى مبارك، جعله الله عيد خير وفرح عليكم وعلى من تحبّون", .occasions),
        plain(44, "رمضان مبارك، بلّغنا الله وإياكم صيامه وقيامه على خير", .occasions),
        plain(45, "مبارك عليكم الشهر، جعله الله شهر رحمة ومغفرة وعتق من النار", .occasions),
        plain(46, "كل عام ووطننا بخير — حفظ الله بلادنا وأدام أمنها وعزّها", .occasions),
        plain(47, "في يومنا الوطني نسأل الله أن يديم على بلادنا الأمن والرخاء، وأن يحفظ قادتها وأهلها", .occasions),
        plain(48, "يوم التأسيس: ذكرى عزّ وتاريخ ممتدّ — حفظ الله وطننا وأدام مجده", .occasions),
        plain(49, "في ذكرى التأسيس، نحمد الله على نعمة الأمن والاجتماع، ونسأله دوام الخير لبلادنا", .occasions),

        // مواساة
        ayah(2, 156, .condolence),
        ayah(64, 11, .condolence),
        ayah(3, 185, .condolence),
        hadith("r949", .condolence),       // إذا مات الإنسان انقطع عمله
        hadith("r37", .condolence),        // ما يصيب المسلم من نصب
        plain(20, "عظّم الله أجركم وأحسن عزاءكم وغفر لميّتكم", .condolence),
        plain(21, "رحمه الله رحمة واسعة وأسكنه فسيح جناته", .condolence),
        plain(22, "أحسن الله عزاءكم، وألهمكم الصبر والسلوان", .condolence),

        // شفاء
        ayah(26, 80, .recovery),
        ayah(17, 82, .recovery),
        // r903 لا r902: نصّ r902 يبدأ بـ«وعنها» بلا سابق وفيه تكرار مطبعي في الصلاة على النبي.
        hadith("r903", .recovery),         // اللهم ربّ الناس أذهب البأس (رقية أنس)
        // r897 لا r362: نصّ r362 يبدأ بـ«وعنه» بلا راوٍ وتخريجه الترمذي؛ r897 راويه مسمّى ورواه البخاري.
        hadith("r897", .recovery),         // عودوا المريض
        plain(30, "شفاكم الله وعافاكم، وألبسكم ثوب الصحة والعافية", .recovery),
        plain(32, "دعواتنا لكم بالشفاء العاجل والعافية التامة", .recovery),
    ]
}
