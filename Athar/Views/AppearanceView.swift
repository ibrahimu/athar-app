import SwiftUI

/// المظهر: الطابع اللوني، الوضع الفاتح/الداكن، وترتيب الشريط السفلي.
struct AppearanceView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var editing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if !AppConfig.arabicOnly { languagePicker }
                themes
                iconStylePicker
                backgroundPicker
                appearanceMode
                tabBar
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .readableWidth(560)
        }
        .scrollIndicators(.hidden)
        .modifier(PaperTopEdge())
        // الخلفية خلف ScrollView لا حوله في ZStack، فيبقى هو جذر الشاشة الذي
        // يكتشفه شريط العنوان ويعامل حافته العلوية عند التمرير تحته.
        .background { AtharBackground() }
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
        VStack(spacing: 8) {
            // هذه الشاشة ابنة «الإعدادات»، فعناوينها عناوين مجموعات كأمّها لا رؤوس أقسام كالرئيسية.
            SettingsGroupTitle(text: loc("colorTheme"), tint: Theme.accent(for: "gold"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        withAnimation(Motion.gentle) { store.appTheme = theme }
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        swatch(theme)
                    }
                    .buttonStyle(.plain)
                    // الاختيار كان لونًا وإطارًا فقط؛ VoiceOver يحتاج سمة «محدَّد» ليعرف الطابع الفعّال.
                    .accessibilityLabel(theme.title)
                    .accessibilityAddTraits(store.appTheme == theme ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("colorTheme"))
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
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(canvas)
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [accent, accent2],
                                                 startPoint: .topTrailing, endPoint: .bottomLeading))
                            .frame(width: 26, height: 26)
                            .shadow(color: accent.opacity(0.35), radius: 4, y: 2)
                        if on {
                            // لون الورق لا الأبيض: بعض الطوابع لها لون فاتح في الوضع
                            // الداكن، فالأبيض عليه يختفي. الورق دائمًا نقيض اللون.
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(canvas)
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
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(on ? accent : Theme.hairline.opacity(0.6), lineWidth: on ? 2.5 : 1)
            )
            .shadow(color: on ? accent.opacity(0.22) : .clear, radius: 8, y: 3)
            Text(theme.title)
                .font(Theme.display(12, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? accent : Theme.inkSoft)
        }
        .scaleEffect(on ? 1.03 : 1)
    }

    // MARK: لون الأيقونات

    private var iconStylePicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("لون الأيقونات"), tint: Theme.accent(for: "calm"))
            HStack(spacing: 10) {
                // ألوان صريحة (لا تمرّ بـaccent(for:) حتى لا تتأثر بالوضع الحالي)
                let multi: [Color] = [
                    .adaptive(light: Color(hex: 0xC77B36), dark: Color(hex: 0xE0A063)),
                    .adaptive(light: Color(hex: 0x1F6473), dark: Color(hex: 0x5FB7CB)),
                    .adaptive(light: Color(hex: 0xA0466A), dark: Color(hex: 0xDD8CAA)),
                    .adaptive(light: Color(hex: 0x2F4A73), dark: Color(hex: 0x7FA3D8))]
                iconStyleOption(unified: false, title: loc("متعدّد"), colors: multi)
                iconStyleOption(unified: true, title: loc("موحّد"),
                                colors: Array(repeating: Theme.accent, count: 4))
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("لون الأيقونات"))
        }
    }

    private func iconStyleOption(unified: Bool, title: String, colors: [Color]) -> some View {
        let on = store.unifyIcons == unified
        let icons = ["sparkles", "moon.stars.fill", "drop.fill", "book.closed.fill"]
        return Button {
            withAnimation(Motion.gentle) { store.unifyIcons = unified }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 9) {
                // معاينة: رقاقات الأيقونات الحقيقية نفسها (ملوّنة أو موحّدة) لا رسمًا يقارِبها
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        IconChip(icon: icons[i], tint: colors[i], size: .sm)
                    }
                }
                Text(title)
                    .font(Theme.display(13, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.surfaceGradient)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(on ? Theme.accent : Theme.hairline.opacity(0.6), lineWidth: on ? 2.5 : 1))
            )
            .atharElevation(on ? .e2 : .e1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: الخلفية

    private var backgroundPicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("خلفية التطبيق"), tint: Theme.accent(for: "sea"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 12)], spacing: 12) {
                ForEach(BackgroundPattern.allCases) { pattern in
                    Button {
                        withAnimation(Motion.gentle) { store.backgroundPattern = pattern }
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        patternSwatch(pattern)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(pattern.title)
                    .accessibilityAddTraits(store.backgroundPattern == pattern ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("خلفية التطبيق"))
        }
    }

    private func patternSwatch(_ pattern: BackgroundPattern) -> some View {
        let on = store.backgroundPattern == pattern
        return VStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.canvas)
                // معاينة النقش نفسه، بشدّة أعلى ليُرى في المربّع الصغير
                PaperMotif(tint: Theme.accent, pattern: pattern, intensity: 9)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                if on {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.accent)
                        .background(Circle().fill(Theme.surface).padding(2))
                }
            }
            .frame(height: 74)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
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
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surface))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .stroke(on ? .clear : Theme.hairline)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.appearance == mode ? .isSelected : [])
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("lighting"))
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
                        .foregroundStyle(editing ? Theme.onAccent : Theme.accent)
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
            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .fill(editing ? Theme.accentSoft : Theme.surfaceAlt))
            .animation(Motion.snappy, value: editing)

            SettingsCard {
                ForEach(Array(store.visibleTabs.enumerated()), id: \.element) { i, tab in
                    HStack(spacing: 12) {
                        // TabGlyph يرسم أشكالًا خاصة (سجّادة، كعبة) فلا يصلح IconChip؛ نطابق مقاسه الصغير (٣٢) فحسب.
                        TabGlyph(tab: tab, size: 14)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Theme.accentSoft))

                        if editing {
                            Text("\((i + 1).counterText)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.inkFaint)
                                .frame(width: 18)
                        }
                        Text(tab.title).font(Theme.display(15)).foregroundStyle(Theme.ink)
                        if tab.isPinned {
                            Text(loc("ثابت")).font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(Theme.surfaceAlt))
                        }
                        Spacer()

                        if editing && !tab.isPinned {
                            HStack(spacing: 4) {
                                arrowButton("chevron.up", label: loc("تقديم"), enabled: i > 1) { move(i, -1) }
                                arrowButton("chevron.down", label: loc("تأخير"), enabled: i < store.visibleTabs.count - 1) { move(i, 1) }
                                Button { remove(tab) } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(Theme.danger)
                                        // الرمز ١٨ نقطة؛ نوسّع منطقة اللمس إلى ٤٤ دون تغيير التخطيط.
                                        .contentShape(Rectangle().inset(by: -13))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(loc("إخفاء %1$@", tab.title))
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
                                TabGlyph(tab: tab, size: 14)
                                    .foregroundStyle(Theme.inkFaint)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Theme.surfaceAlt))
                                Text(tab.title).font(Theme.display(15)).foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 18))
                                    // المعطَّل «حاضر لكن خامل»: hairline لون الفواصل الشعرية ويكاد يختفي في رمز بحجم ١٨.
                                    .foregroundStyle(store.visibleTabs.count >= AppTab.maxVisible
                                                     ? Theme.inkFaint : Theme.accent)
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

    private func arrowButton(_ icon: String, label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled ? Theme.accent : Theme.inkFaint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Theme.surfaceAlt))
                .contentShape(Rectangle().inset(by: -9))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        // زر أيقونة فقط: بلا عنوان يقرأ VoiceOver اسم الرمز بلغة الجهاز.
        .accessibilityLabel(label)
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


