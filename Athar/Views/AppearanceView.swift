import SwiftUI

/// المظهر: الطابع اللوني، الوضع الفاتح/الداكن، وترتيب الشريط السفلي.
struct AppearanceView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var editing = false

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                VStack(spacing: 24) {
                    themes
                    appearanceMode
                    tabBar
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("المظهر")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: الطابع

    private var themes: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "الطابع اللوني")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 12)], spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        withAnimation(.smooth(duration: 0.25)) { store.appTheme = theme }
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        swatch(theme)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func swatch(_ theme: AppTheme) -> some View {
        let on = store.appTheme == theme
        let accent = Color.adaptive(light: Color(hex: theme.accent.light), dark: Color(hex: theme.accent.dark))
        let canvas = Color.adaptive(light: Color(hex: theme.canvas.light), dark: Color(hex: theme.canvas.dark))
        return VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(canvas)
                VStack(spacing: 5) {
                    Circle().fill(accent).frame(width: 20, height: 20)
                    Capsule().fill(accent.opacity(0.3)).frame(width: 34, height: 5)
                }
            }
            .frame(height: 68)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(on ? accent : Theme.hairline, lineWidth: on ? 2.5 : 1)
            )
            Text(theme.title)
                .font(Theme.display(12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
        }
    }

    // MARK: الوضع

    private var appearanceMode: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: "الإضاءة")
            HStack(spacing: 10) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        withAnimation(.smooth(duration: 0.25)) { store.appearance = mode }
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        let on = store.appearance == mode
                        VStack(spacing: 6) {
                            Image(systemName: mode == .system ? "circle.lefthalf.filled"
                                            : mode == .light ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 17))
                            Text(mode.title).font(Theme.display(12, weight: on ? .semibold : .regular))
                        }
                        .foregroundStyle(on ? .white : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(on ? Theme.accent : Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(on ? .clear : Theme.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: الشريط السفلي

    private var tabBar: some View {
        VStack(spacing: 8) {
            HStack {
                SettingsGroupTitle(text: "الشريط السفلي")
                Spacer()
                Button(editing ? "تم" : "ترتيب") {
                    withAnimation(.smooth) { editing.toggle() }
                }
                .font(Theme.display(13, weight: .semibold))
                .foregroundStyle(Theme.accent)
            }

            SettingsCard {
                ForEach(Array(store.visibleTabs.enumerated()), id: \.element) { i, tab in
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.accentSoft))

                        Text(tab.title).font(Theme.display(15)).foregroundStyle(Theme.ink)
                        if tab.isPinned {
                            Text("ثابت").font(Theme.display(10))
                                .foregroundStyle(Theme.inkFaint)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Theme.surfaceAlt))
                        }
                        Spacer()

                        if editing && !tab.isPinned {
                            HStack(spacing: 4) {
                                arrowButton("chevron.up", enabled: i > 1) { move(i, -1) }
                                arrowButton("chevron.down", enabled: i < store.visibleTabs.count - 1) { move(i, 1) }
                                Button { remove(tab) } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Color.red.opacity(0.75))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if i < store.visibleTabs.count - 1 { SettingsDivider() }
                }
            }

            if !store.hiddenTabs.isEmpty {
                SettingsGroupTitle(text: store.visibleTabs.count >= AppTab.maxVisible
                                   ? "غير ظاهرة — احذف واحدًا لتضيف"
                                   : "أضِف إلى الشريط")
                SettingsCard {
                    ForEach(Array(store.hiddenTabs.enumerated()), id: \.element) { i, tab in
                        Button { add(tab) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.inkFaint)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(Theme.surfaceAlt))
                                Text(tab.title).font(Theme.display(15)).foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(store.visibleTabs.count >= AppTab.maxVisible
                                                     ? Theme.hairline : Theme.accent)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(store.visibleTabs.count >= AppTab.maxVisible)
                        if i < store.hiddenTabs.count - 1 { SettingsDivider() }
                    }
                }
            }

            Text("أقصى عدد ٥ تبويبات. «اليوم» ثابت لا يُحذف.")
                .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
    }

    private func arrowButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled ? Theme.accent : Theme.hairline)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.surfaceAlt))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func move(_ i: Int, _ delta: Int) {
        var v = store.visibleTabs
        let j = i + delta
        guard v.indices.contains(i), v.indices.contains(j), j > 0 else { return }
        v.swapAt(i, j)
        withAnimation(.smooth(duration: 0.2)) { store.visibleTabs = v }
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    private func remove(_ tab: AppTab) {
        withAnimation(.smooth(duration: 0.2)) {
            store.visibleTabs = store.visibleTabs.filter { $0 != tab }
        }
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    private func add(_ tab: AppTab) {
        guard store.visibleTabs.count < AppTab.maxVisible else { return }
        withAnimation(.smooth(duration: 0.2)) { store.visibleTabs.append(tab) }
        Haptics.tap(enabled: store.hapticsEnabled)
    }
}
