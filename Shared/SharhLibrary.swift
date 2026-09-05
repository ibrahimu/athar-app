import Foundation

// MARK: - شروح الأحاديث (تراث عام)

struct HadithSharh: Hashable {
    let title: String
    let text: String
}

/// شرح الأربعين النووية لابن دقيق العيد (ت ٧٠٢هـ) — لكل حديث من الأربعين شرحه.
enum SharhLibrary {
    private struct File: Decodable {
        struct Meta: Decodable { let title: String; let author: String; let source: String; let note: String }
        struct Entry: Decodable { let title: String; let text: String }
        let meta: Meta
        let entries: [String: Entry]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "sharh40", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    static let bookTitle: String = file?.meta.title ?? "شرح الأربعين النووية"
    static let author: String = file?.meta.author ?? "ابن دقيق العيد"
    static let sourceNote: String = file?.meta.source ?? ""

    /// شرح حديث بمعرّفه (n1…n42) — لا شرح لأحاديث رياض الصالحين بعد.
    static func sharh(for hadithId: String) -> HadithSharh? {
        guard let e = file?.entries[hadithId] else { return nil }
        return HadithSharh(title: e.title, text: e.text)
    }
}
