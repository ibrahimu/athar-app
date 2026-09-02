import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, mushaf, adhkar, prayer, tasbih }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(onOpenTab: { selection = $0 })
                .tabItem { Label("اليوم", systemImage: "sun.horizon.fill") }
                .tag(Tab.home)

            MushafView()
                .tabItem { Label("المصحف", systemImage: "book.pages.fill") }
                .tag(Tab.mushaf)

            AdhkarIndexView()
                .tabItem { Label("الأذكار", systemImage: "text.book.closed.fill") }
                .tag(Tab.adhkar)

            PrayerView(store: store)
                .tabItem { Label("الصلاة", systemImage: "moon.stars.fill") }
                .tag(Tab.prayer)

            TasbihView()
                .tabItem { Label("المسبحة", systemImage: "circle.hexagongrid.fill") }
                .tag(Tab.tasbih)

        }
    }
}
