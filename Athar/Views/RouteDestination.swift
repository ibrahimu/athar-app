import SwiftUI

/// يعرض وجهةً طلبها بحث iOS أو اختصار الأيقونة.
struct RouteDestination: View {
    let route: AppRoute

    @ViewBuilder
    var body: some View {
        switch route {
        case .tab(let t):            SectionDestination(tab: t)
        case .surah(let n):          SurahReaderView(surahId: n)
        case .name(let id):
            if let n = NamesLibrary.name(id: id) { NameDetailView(name: n) } else { NamesView() }
        case .ahkam(let topicId, let itemId):
            if let t = AhkamLibrary.topic(id: topicId), let sec = t.sections.first(where: { $0.items.contains { $0.id == itemId } }),
               let i = sec.items.firstIndex(where: { $0.id == itemId }) {
                AhkamItemView(section: sec, index: i, tint: Theme.accent(for: t.accent))
            } else { AhkamView() }
        case .adhkar(let id):
            if let c = AdhkarLibrary.category(id: id) { DhikrSessionView(category: c) } else { AdhkarIndexView(embedded: true) }
        }
    }
}
