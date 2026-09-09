import Foundation

/// ترتيبُ قوائم CarPlay مفصولًا عن قوالبها: ما يُقصّ وما يُجمَّع حسابٌ يُختبر
/// بلا سيارةٍ ولا شاشة. وما يسقط هنا يسقط صامتًا في السيارة — يقصّه النظام بلا
/// خبر — فالأولى أن يُقصّ عندنا بحسابٍ معلوم.
enum CarPlayMenu {

    /// سورٌ يطلبها الناس في الطريق: البقرة، الكهف، يس، الرحمن، الواقعة، المُلك.
    /// تُقدَّم لأنّها المقصد الأوّل، فلا تُدفن تحت مئةٍ وأربع عشرة.
    static let favourites = [2, 18, 36, 55, 56, 67]

    /// سقفُ القائمة الواحدة في CarPlay اثنا عشر عنصرًا لا غير — والنظام يقصّ ما زاد
    /// صامتًا. فمئةٌ وأربع عشرة سورة لا تُعرض في قائمة، ولا تُنقذها الأقسام (الحدّ
    /// على العناصر عبرها جميعًا). فتُقسَّم إلى عشر مجموعاتٍ من اثنتي عشرة — والعشرُ
    /// تسعها قائمةٌ واحدة — وكلُّ مجموعة تُفتح على قائمتها.
    static let pageSize = 12

    /// المصحف مقسّمًا إلى مجموعاتٍ معنونة بمدى أرقامها.
    static func surahGroups(step: Int = pageSize, total: Int = 114) -> [(header: String, ids: [Int])] {
        guard step > 0, total > 0 else { return [] }
        var out: [(String, [Int])] = []
        var start = 1
        while start <= total {
            let end = min(start + step - 1, total)
            out.append(("\(start.counterText)–\(end.counterText)", Array(start...end)))
            start = end + 1
        }
        return out
    }

    /// يُقسَّم ما طال إلى صفحاتٍ لا تتجاوز السقف: أحد عشر عنصرًا وصفٌّ يفتح ما بعدها.
    /// فلا يسقط عنصرٌ صامتًا كما كان يسقط تسعون قارئًا وسورة.
    static func pages<T>(_ items: [T], size: Int = pageSize) -> [[T]] {
        guard size > 1, !items.isEmpty else { return items.isEmpty ? [] : [items] }
        if items.count <= size { return [items] }
        var out: [[T]] = []
        var rest = items[...]
        while !rest.isEmpty {
            if rest.count <= size { out.append(Array(rest)); break }
            out.append(Array(rest.prefix(size - 1)))     // مقعدٌ يُترك لصفّ «المزيد»
            rest = rest.dropFirst(size - 1)
        }
        return out
    }

    /// يقصّ الأقسام على حدَّي النظام: عددِ الأقسام وعددِ العناصر عبرها جميعًا.
    /// القسمُ الذي لا يبقى له موضعٌ يُطرح كاملًا، ولا يُترك قسمٌ بعنوانٍ بلا عناصر.
    static func clamp<T>(_ sections: [(header: String, items: [T])],
                         maxSections: Int,
                         maxItems: Int) -> [(header: String, items: [T])] {
        guard maxSections > 0, maxItems > 0 else { return [] }
        var out: [(String, [T])] = []
        var used = 0
        for section in sections.prefix(maxSections) {
            let room = maxItems - used
            if room <= 0 { break }
            let items = Array(section.items.prefix(room))
            if items.isEmpty { break }
            used += items.count
            out.append((section.header, items))
        }
        return out
    }
}
