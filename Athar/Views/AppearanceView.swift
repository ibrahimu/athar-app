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
                    if !AppConfig.arabicOnly { languagePicker }
                    themes
                    backgroundPicker
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
        .navigationTitle(loc("appearance"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: اللغة

    private var languagePicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("language"))
            SettingsCard {
                SettingsPickerRow(
                    icon: "globe", tint: Theme.accent(for: "sea"),
                    title: loc("language"), options: AppLanguage.allCases,
                    selection: Binding(
                        get: { store.appLanguage },
                        set: { store.appLanguage = $0 }))
            }
            Text("﴿ بِلِسَانٍ عَرَبِيٍّ مُّبِينٍ ﴾ — القرآن والأذكار تبقى بالعربية دائمًا")
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: الطابع

    private var themes: some View {
        VStack(spacing: 10) {
            SectionHeader(title: loc("colorTheme"), tint: Theme.gold)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        withAnimation(Motion.gentle) { store.appTheme = theme }
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
        let accent  = Color.adaptive(light: Color(hex: theme.accent.light),  dark: Color(hex: theme.accent.dark))
        let accent2 = Color.adaptive(light: Color(hex: theme.accent2.light), dark: Color(hex: theme.accent2.dark))
        let canvas  = Color.adaptive(light: Color(hex: theme.canvas.light),  dark: Color(hex: theme.canvas.dark))
        let surface = Color.adaptive(light: Color(hex: theme.surface.light), dark: Color(hex: theme.surface.dark))
        let gold    = Color.adaptive(light: Color(hex: theme.ornament.light), dark: Color(hex: theme.ornament.dark))
        return VStack(spacing: 7) {
            ZStack {
                // معاينة مصغّرة: ورق الطابع + بطاقة صغيرة + كرة اللون المتدرّج ولمسة ذهب
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(canvas)
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [accent, accent2],
                                                 startPoint: .topTrailing, endPoint: .bottomLeading))
                            .frame(width: 26, height: 26)
                            .shadow(color: accent.opacity(0.35), radius: 4, y: 2)
                        if on {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(surface)
                        .frame(width: 40, height: 14)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 3) {
                                Capsule().fill(accent.opacity(0.4)).frame(width: 16, height: 4)
                                Circle().fill(gold).frame(width: 4, height: 4)
                            }
                            .padding(.leading, 5)
                        }
                }
            }
            .frame(height: 74)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(on ? accent : Theme.hairline.opacity(0.6), lineWidth: on ? 2.5 : 1)
            )
            .shadow(color: on ? accent.opacity(0.22) : .clear, radius: 8, y: 3)
            Text(theme.title)
                .font(Theme.display(12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? accent : Theme.inkSoft)
        }
        .scaleEffect(on ? 1.03 : 1)
    }

    // MARK: الخلفية

    private var backgroundPicker: some View {
        VStack(spacing: 10) {
            SectionHeader(title: loc("خلفية التطبيق"), tint: Theme.accent(for: "sea"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                ForEach(BackgroundPattern.allCases) { pattern in
                    Button {
                        withAnimation(Motion.gentle) { store.backgroundPattern = pattern }
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        patternSwatch(pattern)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func patternSwatch(_ pattern: BackgroundPattern) -> some View {
        let on = store.backgroundPattern == pattern
        return VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.canvas)
                // معاينة النقش نفسه، بشدّة أعلى ليُرى في المربّع الصغير
                PaperMotif(tint: Theme.accent, pattern: pattern, intensity: 9)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .background(Circle().fill(Theme.surface).padding(2))
                }
            }
            .frame(height: 74)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(on ? Theme.accent : Theme.hairline.opacity(0.6), lineWidth: on ? 2.5 : 1)
            )
            .shadow(color: on ? Theme.accent.opacity(0.22) : .clear, radius: 8, y: 3)
            Text(pattern.title)
                .font(Theme.display(12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
        }
        .scaleEffect(on ? 1.03 : 1)
    }

    // MARK: الوضع

    private var appearanceMode: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("lighting"))
            HStack(spacing: 10) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        withAnimation(Motion.smooth) { store.appearance = mode }
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        let on = store.appearance == mode
                        VStack(spacing: 6) {
                            Image(systemName: mode == .system ? "circle.lefthalf.filled"
                                            : mode == .light ? "sun.max.fill" : "moon.fill")
                                .font(.system(size: 17))
                            Text(mode.title).font(Theme.display(12, weight: on ? .semibold : .regular))
                        }
                        .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surface))
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
            HStack(spacing: 10) {
                SettingsGroupTitle(text: loc("bottomBar"))
                Spacer()
                if editing && !isDefaultOrder {
                    Button { resetTabs() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10, weight: .semibold))
                            Text(loc("basicBtn"))
                        }
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(Capsule().fill(Theme.surfaceAlt))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
                Button {
                    withAnimation(.smooth) { editing.toggle() }
                    Haptics.tap(enabled: store.hapticsEnabled)
                } label: {
                    Text(editing ? loc("done") : loc("reorderBtn"))
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(editing ? .white : Theme.accent)
                        .padding(.horizontal, 13).padding(.vertical, 6)
                        .background(Capsule().fill(editing ? Theme.accent : Theme.accentSoft))
                }
                .buttonStyle(.plain)
            }

            // شرح ما يفعله الوضع، بدل أن يخمّنه المستخدم
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: editing ? "hand.tap.fill" : "info.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(editing ? Theme.accent : Theme.inkFaint)
                    .padding(.top, 1)
                Text(editing
                     ? loc("استعمل الأسهم لتغيير الترتيب، و⊖ لإخفاء تبويب. «اليوم» ثابت لا يُخفى.")
                     : loc("هذه التبويبات تظهر في أسفل الشاشة. اضغط «ترتيب» لتغيّرها."))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(editing ? Theme.accentSoft : Theme.surfaceAlt))
            .animation(Motion.snappy, value: editing)

            SettingsCard {
                ForEach(Array(store.visibleTabs.enumerated()), id: \.element) { i, tab in
                    HStack(spacing: 12) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.accentSoft))

                        if editing {
                            Text("\((i + 1).counterText)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.inkFaint)
                                .frame(width: 18)
                        }
                        Text(tab.title).font(Theme.display(15)).foregroundStyle(Theme.ink)
                        if tab.isPinned {
                            Text(loc("ثابت")).font(Theme.display(10))
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
                                   ? loc("غير ظاهرة — احذف واحدًا لتضيف")
                                   : loc("أضِف إلى الشريط"))
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

            Text("\(store.visibleTabs.count.counterText) من \(AppTab.maxVisible.counterText) تبويبات")
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

    private var isDefaultOrder: Bool { store.visibleTabs == AppTab.defaultOrder }

    private func resetTabs() {
        withAnimation(Motion.smooth) { store.visibleTabs = AppTab.defaultOrder }
        Haptics.done(enabled: store.hapticsEnabled)
    }

    private func move(_ i: Int, _ delta: Int) {
        var v = store.visibleTabs
        let j = i + delta
        guard v.indices.contains(i), v.indices.contains(j), j > 0 else { return }
        v.swapAt(i, j)
        withAnimation(Motion.snappy) { store.visibleTabs = v }
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    private func remove(_ tab: AppTab) {
        withAnimation(Motion.snappy) {
            store.visibleTabs = store.visibleTabs.filter { $0 != tab }
        }
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    private func add(_ tab: AppTab) {
        guard store.visibleTabs.count < AppTab.maxVisible else { return }
        withAnimation(Motion.snappy) { store.visibleTabs.append(tab) }
        Haptics.tap(enabled: store.hapticsEnabled)
    }
}
