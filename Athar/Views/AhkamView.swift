import SwiftUI

/// الأحكام — هيكل أوّلي، يُستكمل في موجة البناء.
struct AhkamView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    var body: some View {
        ZStack {
            AtharBackground()
            VStack(spacing: 12) {
                Image(systemName: "list.bullet.clipboard.fill").font(.system(size: 34)).foregroundStyle(Theme.accent)
                Text(loc("الأحكام")).font(Theme.display(20, weight: .bold)).foregroundStyle(Theme.ink)
                Text(loc("قريبًا")).font(Theme.display(13)).foregroundStyle(Theme.inkFaint)
            }
        }
        .navigationTitle(loc("الأحكام"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }
}
