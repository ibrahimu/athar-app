import Foundation

// MARK: - شروح الأحاديث (تراث عام)

struct HadithSharh: Hashable {
    let title: String
    let text: String
}

/// شرح الأربعين النووية لابن دقيق العيد (ت 702هـ) — لكل حديث من الأربعين شرحه.
enum SharhLibrary {
    private struct File: Decodable {
        struct Meta: Decodable { let title: String; let author: String; let source: String; let note: String }
        struct Entry: Decodable { let title: String; let text: String }
        let meta: Meta
        let entries: [String: Entry]
    }

    private static func load(_ name: String) -> File? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }
    /// شرح الأربعين (ابن دقيق العيد) — صغير، يُحمَّل عند أول طلب.
    private static let file: File? = load("sharh40")
    /// دليل الفالحين (ابن علّان) لرياض الصالحين — أكبر، ويُحمَّل عند أول طلب أيضًا.
    private static let riyadFile: File? = load("sharh_riyad")

    static let bookTitle: String = file?.meta.title ?? "شرح الأربعين النووية"
    static let author: String = file?.meta.author ?? "ابن دقيق العيد"
    static let sourceNote: String = file?.meta.source ?? ""
    static let riyadBookTitle: String = riyadFile?.meta.title ?? "دليل الفالحين لطرق رياض الصالحين"
    static let riyadAuthor: String = riyadFile?.meta.author ?? "ابن علّان الصدّيقي"
    static let riyadSourceNote: String = riyadFile?.meta.source ?? ""

    /// شرح حديث بمعرّفه: n1…n42 من شرح الأربعين، وr1…r1896 من دليل الفالحين.
    static func sharh(for hadithId: String) -> HadithSharh? {
        let src = hadithId.hasPrefix("n") ? file : riyadFile
        guard let e = src?.entries[hadithId] else { return nil }
        return HadithSharh(title: e.title, text: e.text)
    }

    /// اسم الكتاب ومؤلفه لهذا الحديث — للبطاقة والذيل.
    static func attribution(for hadithId: String) -> (book: String, author: String, source: String) {
        hadithId.hasPrefix("n") ? (bookTitle, author, sourceNote) : (riyadBookTitle, riyadAuthor, riyadSourceNote)
    }
}
