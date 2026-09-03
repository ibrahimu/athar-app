import Foundation

// MARK: - أسماء الله الحسنى

struct DivineName: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    /// شرح موجز — من كلام السعدي في «تفسير أسماء الله الحسنى» حين وُجد.
    let meaning: String
    /// شاهد من القرآن أو السنّة (نصّه).
    let evidence: String
    /// عزو الشاهد: «البقرة: ٢٥٥» أو «رواه مسلم».
    let evidenceSource: String
    /// «السعدي» حين كان الشرح من كلامه، وإلا «إعداد التطبيق».
    let source: String
}

enum NamesLibrary {
    private struct File: Decodable {
        struct Meta: Decodable { let source: String?; let note: String? }
        let meta: Meta?
        let names: [DivineName]
    }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "names", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(File.self, from: data)
    }()

    static let all: [DivineName] = file?.names ?? []
    static let sourceNote: String = file?.meta?.source ?? ""
    static let note: String = file?.meta?.note ?? ""

    static func name(id: Int) -> DivineName? { all.first { $0.id == id } }

    /// اسم اليوم — ثابت لليوم كله.
    static func daily(for date: Date) -> DivineName? {
        guard !all.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
