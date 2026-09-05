import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// فهرسة المحتوى لبحث iOS: السور والأسماء الحسنى ومسائل الأحكام وأقسام الأذكار والأقسام —
/// فيكتب المستخدم «الكهف» أو «الوضوء» في بحث الجهاز ويصل مباشرة.
enum SpotlightIndexer {
    static let domain = "com.ibrahim.athar"
    private static let versionKey = "athar.spotlight.version"
    private static let version = 3

    static func indexIfNeeded() {
        guard CSSearchableIndex.isIndexingAvailable(), UserDefaults.standard.integer(forKey: versionKey) != version else { return }
        Task.detached(priority: .utility) {
            var items: [CSSearchableItem] = []
            func add(_ id: String, _ title: String, _ desc: String, _ keywords: [String]) {
                let a = CSSearchableItemAttributeSet(contentType: .text)
                a.title = title; a.contentDescription = desc; a.keywords = keywords
                items.append(CSSearchableItem(uniqueIdentifier: id, domainIdentifier: domain, attributeSet: a))
            }
            for s in Quran.surahs { add("surah:\(s.id)", "سورة \(s.name)", "\(s.revelation) · \(s.ayahCount.ayahCountText) — المصحف في أثر", [s.name, "سورة", "قرآن", "مصحف"]) }
            for n in NamesLibrary.all { add("name:\(n.id)", n.name, "من أسماء الله الحسنى — \(String(n.meaning.prefix(80)))", [n.name, "أسماء الله الحسنى"]) }
            for t in AhkamLibrary.topics { for sec in t.sections { for it in sec.items { add("ahkam:\(t.id):\(it.id)", it.title, "\(t.title) · \(sec.title) — أحكام أثر", [it.title, t.title, sec.title, "حكم", "فقه"]) } } }
            for c in AdhkarLibrary.categories { add("adhkar:\(c.id)", c.title, "\(c.subtitle) — أذكار أثر", [c.title, "أذكار", "دعاء"]) }
            for tab in AppTab.sections { add("tab:\(tab.rawValue)", tab.title, tab.blurb, [tab.title, "أثر"]) }
            try? await CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain])
            try? await CSSearchableIndex.default().indexSearchableItems(items)
            UserDefaults.standard.set(version, forKey: versionKey)
        }
    }
}
