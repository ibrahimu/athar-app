import Foundation

// MARK: - الأحكام العملية

struct AhkamTopic: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    /// مفتاح لون Theme.accent(for:).
    let accent: String
    let summary: String
    let sections: [AhkamSection]
}

struct AhkamSection: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let items: [AhkamItem]
}

struct AhkamItem: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    /// الحكم أو الخطوة بأسلوب التطبيق — ليس نقلًا حرفيًا عن أحد.
    let body: String
    let evidence: [AhkamEvidence]
    let fatwa: FatwaLink?
}

/// دليل: آية تُقرأ من المصحف المضمَّن بمرجعها، أو حديث بنصّه وعزوه.
struct AhkamEvidence: Codable, Hashable, Identifiable {
    /// "quran" أو "hadith".
    let kind: String
    /// للآية: "2:183" أو "2:183-185".
    let ref: String?
    /// للحديث: نصّه كما في مصدره.
    let text: String?
    /// «رواه البخاري» أو «متفق عليه»، وللآية اسم السورة يُشتق تلقائيًا.
    let source: String?

    var id: String { "\(kind)|\(ref ?? "")|\(source ?? "")|\((text ?? "").prefix(24))" }
    var isQuran: Bool { kind == "quran" }

    /// مدى الآيات المُحال عليها.
    var ayahRefs: [AyahRef] {
        guard isQuran, let ref, let colon = ref.firstIndex(of: ":"),
              let surah = Int(ref[..<colon]) else { return [] }
        let rest = ref[ref.index(after: colon)...]
        let parts = rest.split(separator: "-").compactMap { Int($0) }
        guard let first = parts.first else { return [] }
        let last = parts.count > 1 ? parts[1] : first
        guard last >= first else { return [AyahRef(surah: surah, ayah: first)] }
        return (first...last).map { AyahRef(surah: surah, ayah: $0) }
    }
}

struct FatwaLink: Codable, Hashable {
    /// «الشيخ ابن باز» / «الشيخ ابن عثيمين».
    let scholar: String
    let title: String
    let url: String
}

enum AhkamLibrary {
    private struct File: Decodable {
        struct Meta: Decodable { let note: String? }
        let meta: Meta?
        let topics: [AhkamTopic]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "ahkam", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    static let topics: [AhkamTopic] = file?.topics ?? []
    static let note: String = file?.meta?.note ?? ""

    static func topic(id: String) -> AhkamTopic? { topics.first { $0.id == id } }
}
