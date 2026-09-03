import SwiftUI

/// الحديث — هيكل أوّلي، يُستكمل في موجة البناء.
struct HadithView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    var body: some View {
        ZStack {
            AtharBackground()
            VStack(spacing: 12) {
                Image(systemName: "quote.opening").font(.system(size: 34)).foregroundStyle(Theme.accent)
                Text(loc("الحديث")).font(Theme.display(20, weight: .bold)).foregroundStyle(Theme.ink)
                Text(loc("قريبًا")).font(Theme.display(13)).foregroundStyle(Theme.inkFaint)
            }
        }
        .navigationTitle(loc("الحديث"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }
}

/// حديث واحد بتمامه مع عزوه وحفظه ومشاركته — هيكل أوّلي.
struct HadithDetailView: View {
    let hadith: Hadith
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                AtharCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(hadith.text).font(Theme.dhikrFont(size: 18)).foregroundStyle(Theme.ink).lineSpacing(8)
                        Text(hadith.citation).font(Theme.display(12)).foregroundStyle(Theme.inkFaint)
                    }
                }
                .padding(Theme.gutter)
            }
        }
        .navigationTitle(hadith.bookTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
