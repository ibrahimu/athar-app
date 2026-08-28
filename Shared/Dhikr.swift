import Foundation

struct Dhikr: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let count: Int
    let reference: String
    let virtue: String

    var hasVirtue: Bool { !virtue.trimmingCharacters(in: .whitespaces).isEmpty }
    var hasReference: Bool { !reference.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct DhikrCategory: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let accent: String
    let items: [Dhikr]

    /// Total repetitions required to complete the whole category.
    var totalRepetitions: Int { items.reduce(0) { $0 + $1.count } }
}

private struct AdhkarFile: Codable {
    let categories: [DhikrCategory]
}

enum AdhkarLibrary {
    static let categories: [DhikrCategory] = load()

    static func category(id: String) -> DhikrCategory? {
        categories.first { $0.id == id }
    }

    /// Every dhikr in the library, flattened — used by the widget rotation.
    static let allItems: [Dhikr] = categories.flatMap(\.items)

    /// Short, widget-friendly adhkar (single phrases that fit a lock screen).
    static let shortItems: [Dhikr] = allItems.filter { $0.text.count <= 90 && !$0.text.contains("\n") }

    private static func load() -> [DhikrCategory] {
        let candidates: [Bundle] = [.main] + Bundle.allBundles + Bundle.allFrameworks
        for bundle in candidates {
            guard let url = bundle.url(forResource: "adhkar", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder().decode(AdhkarFile.self, from: data)
            else { continue }
            return file.categories
        }
        assertionFailure("adhkar.json missing from bundle")
        return []
    }
}

extension DhikrCategory {
    /// Categories that are surfaced on the home screen as "now" suggestions.
    static func suggestedNow(date: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 4..<11:  return "morning"
        case 11..<15: return "tasbih"
        case 15..<19: return "evening"
        case 19..<22: return "istighfar"
        default:      return "sleep"
        }
    }
}
