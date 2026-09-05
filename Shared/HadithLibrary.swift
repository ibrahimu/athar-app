import Foundation

// MARK: - الحديث

struct HadithBook: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let author: String
    let chapters: [HadithChapter]

    var count: Int { chapters.reduce(0) { $0 + $1.hadiths.count } }
}

struct HadithChapter: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let hadiths: [Hadith]
}

struct Hadith: Codable, Identifiable, Hashable {
    let id: String
    /// رقمه في كتابه.
    let n: Int
    let text: String
    /// عزو المؤلف نفسه (متفق عليه، رواه مسلم...) — فارغ حين لم يذكره.
    let source: String
    /// «sahihayn» حين عزاه المؤلف إلى البخاري أو مسلم أو كليهما.
    let grade: String

    var isSahihayn: Bool { grade == "sahihayn" }
    var bookId: String { id.hasPrefix("n") ? "nawawi40" : "riyad" }
    var bookTitle: String { bookId == "nawawi40" ? "الأربعون النووية" : "رياض الصالحين" }

    /// «رياض الصالحين (١٢) — متفق عليه».
    var citation: String {
        let base = "\(bookTitle) (\(n.counterText))"
        return source.isEmpty ? base : "\(base) — \(source)"
    }
}

enum HadithLibrary {
    private struct File: Decodable {
        struct Meta: Decodable { let source: String; let note: String }
        let meta: Meta
        let books: [HadithBook]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "hadith", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    static let books: [HadithBook] = file?.books ?? []
    static let sourceNote: String = file?.meta.source ?? ""
    static let gradingNote: String = file?.meta.note ?? ""

    static let all: [Hadith] = books.flatMap { $0.chapters.flatMap(\.hadiths) }
    private static let byId: [String: Hadith] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    private static let chapterOf: [String: HadithChapter] = {
        var d: [String: HadithChapter] = [:]
        for b in books { for c in b.chapters { for h in c.hadiths { d[h.id] = c } } }
        return d
    }()

    static func hadith(id: String) -> Hadith? { byId[id] }
    static func book(id: String) -> HadithBook? { books.first { $0.id == id } }
    static func chapter(of hadith: Hadith) -> HadithChapter? { chapterOf[hadith.id] }

    /// حديث اليوم: من الصحيحين فقط وقصير بما يناسب بطاقة، ثابت لليوم كله.
    /// بِركة حديث اليوم تُبنى مرة واحدة — لا في كل رسمة لبطاقة الرئيسية.
    private static let dailyPool: [Hadith] = all.filter { $0.isSahihayn && $0.text.count <= 420 }

    static func daily(for date: Date) -> Hadith? {
        let pool = dailyPool
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[day % pool.count]
    }

    /// بحث متسامح: يتجاهل التشكيل وفروق الهمزة والتاء المربوطة.
    static func search(_ query: String, in books: [String]? = nil) -> [Hadith] {
        let q = query.hadithSearchKey
        guard q.count >= 2 else { return [] }
        return all.filter { (books == nil || books!.contains($0.bookId)) && $0.text.hadithSearchKey.contains(q) }
    }
}

extension String {
    /// مفتاح بحث عربي: بلا تشكيل ولا تطويل، والهمزات ألفًا، والتاء المربوطة هاءً، والألف المقصورة ياءً.
    var hadithSearchKey: String {
        var s = ""
        s.reserveCapacity(count)
        for u in unicodeScalars {
            switch u.value {
            case 0x064B...0x065F, 0x0670, 0x06D6...0x06ED, 0x0640: continue   // تشكيل وتطويل
            case 0x0622, 0x0623, 0x0625, 0x0671: s.append("ا")
            case 0x0629: s.append("ه")
            case 0x0649: s.append("ي")
            case 0x0624: s.append("و")
            case 0x0626: s.append("ي")
            default: s.unicodeScalars.append(u)
            }
        }
        return s.lowercased()
    }
}
