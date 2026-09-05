import Foundation

// MARK: - فضائل السور وأسباب النزول

struct SurahVirtue: Codable, Hashable { let text: String; let source: String }

struct AsbabEntry: Codable, Hashable {
    /// الآية الأولى التي يخصّها السبب (وقد يمتدّ لآيات بعدها).
    let ayah: Int
    let text: String
}

enum SurahExtras {
    private struct VirtuesFile: Decodable { let virtues: [String: [SurahVirtue]] }
    private struct AsbabFile: Decodable {
        struct Meta: Decodable { let source: String; let note: String }
        let meta: Meta
        let surahs: [String: [AsbabEntry]]
    }
    private static let virtuesFile: VirtuesFile? = {
        guard let url = Bundle.main.url(forResource: "surah_virtues", withExtension: "json"), let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(VirtuesFile.self, from: d)
    }()
    private static let asbabFile: AsbabFile? = {
        guard let url = Bundle.main.url(forResource: "asbab", withExtension: "json"), let d = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AsbabFile.self, from: d)
    }()

    static func virtues(of surah: Int) -> [SurahVirtue] { virtuesFile?.virtues[String(surah)] ?? [] }
    static let asbabSource: String = asbabFile?.meta.source ?? ""
    static let asbabNote: String = asbabFile?.meta.note ?? ""

    /// سبب نزول الآية إن ذُكر (أو سبب مجموعةٍ تبدأ بها).
    static func asbab(for ref: AyahRef) -> AsbabEntry? {
        asbabFile?.surahs[String(ref.surah)]?.first { $0.ayah == ref.ayah }
    }
    static func asbab(inSurah surah: Int) -> [AsbabEntry] { asbabFile?.surahs[String(surah)] ?? [] }
}
