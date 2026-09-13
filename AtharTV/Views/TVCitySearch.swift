import Foundation

// MARK: - ترتيب الأماكن
//
// ثلاثةُ مستويات: **السعودية ← منطقة ← مدينة**، ثمّ الخليج، ثمّ الشرق الأوسط،
// ثمّ العالم. وقبل ذلك كان تجميعًا مخترعًا — «عسير والجنوب»، «القصيم والشمال» —
// يجمع مناطقَ لا يجمعها شيء، وكلُّ مدينةٍ فيها وقتُها الذي لا يشبه جارتها. فردّ
// إلى المناطق الإدارية الثلاث عشرة كما تُسمّى في المملكة: اسمٌ يعرفه صاحبُه،
// ولا يَعِد بأن ما تحته وقتٌ واحد.
//
// والمواقيت تُحسب لكل مدينةٍ بإحداثيّاتها ومنطقتها الزمنية وحدها. فالمنطقةُ هنا
// طريقُ وصولٍ لا غير — تُقصّر الطريقَ بالمِرقاب، ولا تدّعي حسابًا مشتركًا.

struct TVPlaceGroup: Identifiable, Hashable {
    let id: String
    let title: String
    /// معرّفات المدن بترتيب العرض.
    let cities: [String]

    var resolved: [City] { cities.compactMap { id in City.all.first { $0.id == id } } }
}

struct TVPlaceSection: Identifiable, Hashable {
    let id: String
    let title: String
    let groups: [TVPlaceGroup]
}

enum TVCities {

    /// مناطق المملكة الإدارية الثلاث عشرة. ما لا مدينةَ له في `City.all` يسقط
    /// وحده — لا يُعرض عنوانٌ يَعِد بما ليس تحته.
    private static let saudiRegions: [TVPlaceGroup] = [
        .init(id: "r_riyadh",  title: "منطقة الرياض",
              cities: ["riyadh", "kharj", "majmaah", "zulfi", "dawadmi", "shaqra",
                       "wadidawasir", "afif", "diriyah"]),
        .init(id: "r_makkah",  title: "منطقة مكة المكرمة",
              cities: ["makkah", "jeddah", "taif", "rabigh", "qunfudhah", "layth"]),
        .init(id: "r_madinah", title: "منطقة المدينة المنورة",
              cities: ["madinah", "yanbu", "alula"]),
        .init(id: "r_eastern", title: "المنطقة الشرقية",
              cities: ["dammam", "khobar", "dhahran", "hofuf", "qatif", "jubail",
                       "khafji", "hafar"]),
        .init(id: "r_qassim",  title: "منطقة القصيم",
              cities: ["buraydah", "unaizah", "rass"]),
        .init(id: "r_asir",    title: "منطقة عسير",
              cities: ["abha", "khamis", "mahayil", "bisha"]),
        .init(id: "r_tabuk",   title: "منطقة تبوك",
              cities: ["tabuk", "duba", "neom"]),
        .init(id: "r_hail",    title: "منطقة حائل",         cities: ["hail"]),
        .init(id: "r_northern", title: "منطقة الحدود الشمالية", cities: ["arar"]),
        .init(id: "r_jazan",   title: "منطقة جازان",
              cities: ["jazan", "sabya", "abuarish"]),
        .init(id: "r_najran",  title: "منطقة نجران",        cities: ["najran"]),
        .init(id: "r_baha",    title: "منطقة الباحة",
              cities: ["baha", "baljurashi"]),
        .init(id: "r_jawf",    title: "منطقة الجوف",
              cities: ["sakaka", "qurayyat"]),
    ]

    /// مجموعةٌ لكل دولة خارج المملكة: بلدٌ واحد فيه مدينةٌ أو مدينتان، فاسمُ
    /// الدولة هو العنوان الطبيعي — لا «بلاد العرب».
    private static func countries(_ ids: [String]) -> [TVPlaceGroup] {
        ids.compactMap { country in
            let cities = City.all.filter { $0.country == country }
            guard !cities.isEmpty else { return nil }
            return TVPlaceGroup(id: "c_" + country, title: country, cities: cities.map(\.id))
        }
    }

    static let sections: [TVPlaceSection] = [
        .init(id: "sa", title: "المملكة العربية السعودية",
              groups: saudiRegions.filter { !$0.resolved.isEmpty }),
        .init(id: "gulf", title: "الخليج",
              groups: countries(["الكويت", "البحرين", "قطر", "الإمارات", "عُمان"])),
        .init(id: "me", title: "الشرق الأوسط",
              groups: countries(["العراق", "الأردن", "فلسطين", "سوريا", "لبنان",
                                 "اليمن", "مصر", "السودان", "تركيا"])),
        .init(id: "world", title: "العالم",
              groups: countries(["المغرب", "الجزائر", "تونس", "بريطانيا", "فرنسا",
                                 "ألمانيا", "أمريكا", "كندا", "ماليزيا", "إندونيسيا"])),
    ]

    /// كلُّ مجموعةٍ في مكانٍ واحد — للوصول إليها بمعرّفها.
    static let allGroups: [TVPlaceGroup] = sections.flatMap(\.groups)

    static func group(_ id: String) -> TVPlaceGroup? { allGroups.first { $0.id == id } }

    /// أين تقع هذه المدينة من الطريق — إقليمُها ثمّ منطقتُها.
    ///
    /// وبها تُفتح الشاشةُ حين يعود صاحبُها ليغيّر مدينته: على مدينته هو لا على
    /// رأس القائمة. من جاء ليبدّل «الأحساء» يريد أن يرى «الأحساء» أوّلَ ما يرى،
    /// فيعرف أنّ الجهاز يعرف مكانه، ولا يمشي الطريقَ كلَّه ليكتشف أين كان.
    static func place(of city: City) -> (section: TVPlaceSection, group: TVPlaceGroup)? {
        for section in sections {
            if let group = section.groups.first(where: { $0.cities.contains(city.id) }) {
                return (section, group)
            }
        }
        return nil
    }

    /// البحث بمِفتاح `ArabicSearch` نفسه الذي في الجوال: «الاحساء» تجد
    /// «الأحساء»، و«مكه» تجد «مكة». وتُطابَق أسماءُ الدول كذلك، فمن كتب «مصر»
    /// وجد القاهرة.
    static func search(_ query: String) -> [City] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        // ويُطابَق اسمُ المنطقة كذلك: من كتب «الشرقية» أراد مدنَها الثماني، ومن
        // كتب «القصيم» أراد بريدةَ وعنيزةَ والرسّ — وهو أقربُ إلى ما في الذهن من
        // حصر البحث في اسم المدينة وحده.
        let inGroup = Set(allGroups.filter { ArabicSearch.matches($0.title, q) }.flatMap(\.cities))
        return City.all.filter {
            ArabicSearch.matches($0.name, q) || ArabicSearch.matches($0.country, q) || inGroup.contains($0.id)
        }
    }
}
