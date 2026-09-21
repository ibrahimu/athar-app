import Foundation

struct ReadingPath: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var position: AyahRef
    var updated: Date
}

/// Pages in this reading layout are groups of original pages, not a new Quran edition.
enum QiyamLayout {
    static let count = 200
    static func originalPages(for page: Int) -> ClosedRange<Int> {
        let p = max(1, min(count, page))
        let start = (p - 1) * Quran.pageCount / count + 1
        let end = p * Quran.pageCount / count
        return start...max(start, end)
    }
    static func page(containing original: Int) -> Int {
        let source = max(1, min(Quran.pageCount, original))
        return min(count, (source * count + Quran.pageCount - 1) / Quran.pageCount)
    }
}

#if !os(tvOS)
extension AtharStore {
    var readingPaths: [ReadingPath] {
        get {
            guard let data = defaults.data(forKey: "athar.mushaf.readingPaths"),
                  let list = try? JSONDecoder().decode([ReadingPath].self, from: data) else { return [] }
            return list.filter { Quran.surah($0.position.surah)?.verse($0.position.ayah) != nil }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: "athar.mushaf.readingPaths") }
            objectWillChange.send()
        }
    }
    func prepareReadingPaths() {
        guard !defaults.bool(forKey: "athar.mushaf.readingPaths.initialized") else { return }
        if readingPaths.isEmpty, let lastRead { addReadingPath(title: "قراءتي الأساسية", at: lastRead) }
        defaults.set(true, forKey: "athar.mushaf.readingPaths.initialized")
    }
    @discardableResult
    func addReadingPath(title: String, at ref: AyahRef) -> UUID {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = ReadingPath(id: UUID(), title: trimmed.isEmpty ? "قراءتي" : String(trimmed.prefix(60)), position: ref, updated: Date())
        var all = readingPaths; all.append(path); readingPaths = all
        return path.id
    }
    func updateReadingPath(_ id: UUID, at ref: AyahRef) {
        var all = readingPaths
        guard let index = all.firstIndex(where: { $0.id == id }), all[index].position != ref else { return }
        all[index].position = ref; all[index].updated = Date(); readingPaths = all
    }
}
#endif
