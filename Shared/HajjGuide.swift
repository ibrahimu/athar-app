import Foundation

/// دليل مناسك (حج أو عمرة) مُحمَّل من hajj.json — نصّ متحقَّق شرعيًّا.
struct HajjGuide: Codable, Identifiable {
    let title: String
    let subtitle: String
    let icon: String
    let steps: [HajjStep]
    var id: String { title }
}

struct HajjStep: Codable, Identifiable {
    let name: String
    let detail: String
    let dua: String
    var icon: String = "circle.fill"
    var id: String { name }
    var hasDua: Bool { !dua.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

enum HajjData {
    private struct File: Codable { let umrah: HajjGuide; let hajj: HajjGuide }

    private static let file: File? = {
        guard let url = Bundle.main.url(forResource: "hajj", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(File.self, from: data)
        else { return nil }
        return f
    }()

    static var umrah: HajjGuide? { file?.umrah }
    static var hajj: HajjGuide? { file?.hajj }
}
