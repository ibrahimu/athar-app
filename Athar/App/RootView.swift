import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var selection: Tab = .home

    enum Tab: Hashable { case home, adhkar, prayer, tasbih, settings }

    var body: some View {
        TabView(selection: $selection) {
            HomeView(onOpenTab: { selection = $0 })
                .tabItem { Label("اليوم", systemImage: "sun.horizon.fill") }
                .tag(Tab.home)

            AdhkarIndexView()
                .tabItem { Label("الأذكار", systemImage: "book.closed.fill") }
                .tag(Tab.adhkar)

            PrayerView(store: store)
                .tabItem { Label("الصلاة", systemImage: "moon.stars.fill") }
                .tag(Tab.prayer)

            TasbihView()
                .tabItem { Label("المسبحة", systemImage: "circle.hexagongrid.fill") }
                .tag(Tab.tasbih)

            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
        }
    }
}
