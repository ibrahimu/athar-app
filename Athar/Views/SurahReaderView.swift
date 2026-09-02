import SwiftUI

/// ألوان صفحة القراءة حسب السِّمة المختارة.
struct ReadingPalette {
    let paper: Color
    let ink: Color
    let faint: Color
    let accent: Color
    let hairline: Color

    static func of(_ theme: ReadingTheme) -> ReadingPalette {
        switch theme {
        case .paper:
            return .init(paper: Color(hex: 0xFBF9F3), ink: Color(hex: 0x14201B),
                         faint: Color(hex: 0x8A9992), accent: Color(hex: 0x1F6B4F),
                         hairline: Color(hex: 0xE6E1D4))
        case .sepia:
            return .init(paper: Color(hex: 0xF4E9D6), ink: Color(hex: 0x3E3327),
                         faint: Color(hex: 0x9A8B72), accent: Color(hex: 0x8A6A2F),
                         hairline: Color(hex: 0xE0D2B8))
        case .night:
            // بطلب المستخدم: عكس النهاري — حبر أبيض على ورق أزرق داكن.
            return .init(paper: Color(hex: 0x0E1726), ink: Color(hex: 0xF2F5F8),
                         faint: Color(hex: 0x7C8AA0), accent: Color(hex: 0x6FC3A0),
                         hairline: Color(hex: 0x1F2C42))
        }
    }
}

struct SurahReaderView: View {
    let surahId: Int
    var scrollTo: AyahRef? = nil

    @EnvironmentObject private var store: AtharStore
    @State private var showControls = false
    @State private var selected: AyahRef? = nil

    private var surah: Surah? { Quran.surah(surahId) }
    private var palette: ReadingPalette { .of(store.readingTheme) }

    var body: some View {
        ZStack {
            palette.paper.ignoresSafeArea()
                .animation(Motion.smooth, value: store.readingTheme)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        header
                        if let surah, surah.hasBasmalah, surah.id != 1 {
                            Text(Quran.basmalah)
                                .font(Theme.dhikrFont(size: 22, scale: store.mushafFontScale))
                                .foregroundStyle(palette.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                        }

                        MushafPage(surahId: surahId, palette: palette,
                                   scale: store.mushafFontScale,
                                   bookmarks: Set(store.bookmarks),
                                   highlights: store.highlights,
                                   selected: selected,
                                   isDark: store.readingTheme == .night,
                                   onTapAyah: { selected = $0 },
                                   onVisible: { store.lastRead = $0 })

                        endOfSurah
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                    .readableWidth(700)
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    if let t = scrollTo {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.smooth) { proxy.scrollTo(t, anchor: .center) }
                        }
                    }
                }
            }
        }
        .navigationTitle(surah.map { "سورة \($0.name)" } ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showControls = true } label: {
                    Image(systemName: "textformat.size")
                }
            }
        }
        .sheet(isPresented: $showControls) {
            ReaderControls().presentationDetents([.height(330)])
        }
        .sheet(item: $selected) { ref in
            AyahActions(ref: ref).presentationDetents([.height(420)])
        }
        .toolbarColorScheme(store.readingTheme == .night ? .dark : .light, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: 6) {
            if let surah {
                Text(surah.name)
                    .font(Theme.display(26, weight: .bold))
                    .foregroundStyle(palette.ink)
                Text("\(surah.revelation) · \(surah.ayahCount.counterText) آية")
                    .font(Theme.display(12))
                    .foregroundStyle(palette.faint)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var endOfSurah: some View {
        VStack(spacing: 10) {
            Rectangle().fill(palette.hairline).frame(height: 1).padding(.vertical, 22)
            if surahId < 114, let next = Quran.surah(surahId + 1) {
                NavigationLink { SurahReaderView(surahId: next.id) } label: {
                    HStack(spacing: 8) {
                        Text("سورة \(next.name)")
                            .font(Theme.display(15, weight: .semibold))
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 18).padding(.vertical, 11)
                    .background(Capsule().fill(palette.accent.opacity(0.12)))
                }
                .buttonStyle(.plain)
            } else {
                Text("صدق الله العظيم")
                    .font(Theme.dhikrFont(size: 17))
                    .foregroundStyle(palette.faint)
            }
        }
    }
}

// MARK: - صفحة المصحف

/// صفحة مصحف: النص يتدفّق متصلًا كالمطبوع، لكن **كل كلمة عنصر مستقل**
/// فيمكن لمس أي آية وتظليلها. التقسيم إلى مقاطع يبقي التمرير سلسًا في
/// السور الطويلة، ويكشف الآية الظاهرة لحفظ آخر موضع.
struct MushafPage: View {
    let surahId: Int
    let palette: ReadingPalette
    let scale: Double
    let bookmarks: Set<AyahRef>
    let highlights: [String: String]
    let selected: AyahRef?
    let isDark: Bool
    let onTapAyah: (AyahRef) -> Void
    let onVisible: (AyahRef) -> Void

    private var surah: Surah? { Quran.surah(surahId) }

    var body: some View {
        LazyVStack(alignment: .center, spacing: 20) {
            ForEach(chunks, id: \.first) { group in
                FlowLayout(lineSpacing: 14 * scale, wordSpacing: 5 * scale) {
                    ForEach(tokens(of: group)) { token in
                        tokenView(token)
                    }
                }
                .onAppear { if let f = group.first { onVisible(f) } }
            }
        }
        .padding(.top, 8)
    }

    // MARK: الوحدات

    /// كلمة واحدة أو فاصلة آية — أصغر وحدة قابلة للّمس.
    struct Token: Identifiable {
        let id: String
        let text: String
        let ref: AyahRef
        let isMarker: Bool
        let isSajdah: Bool
    }

    private func tokens(of group: [AyahRef]) -> [Token] {
        var out: [Token] = []
        for ref in group {
            let words = (Quran.text(ref) ?? "").ayahWords
            for (i, w) in words.enumerated() {
                out.append(Token(id: "\(ref.id)-w\(i)", text: w, ref: ref,
                                 isMarker: false, isSajdah: false))
            }
            if Quran.isSajdah(ref) {
                out.append(Token(id: "\(ref.id)-sj", text: "۩", ref: ref,
                                 isMarker: false, isSajdah: true))
            }
            out.append(Token(id: "\(ref.id)-m", text: medallion(ref.ayah), ref: ref,
                             isMarker: true, isSajdah: false))
        }
        return out
    }

    @ViewBuilder
    private func tokenView(_ t: Token) -> some View {
        let hl = highlights[t.ref.id].flatMap(HighlightColor.init(rawValue:))
        let isSelected = selected == t.ref

        Text(t.text)
            .font(t.isMarker ? .system(size: 18 * scale)
                             : Theme.dhikrFont(size: 23, scale: scale))
            .foregroundStyle(t.isMarker || t.isSajdah ? palette.accent : palette.ink)
            .padding(.horizontal, 2)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(background(hl: hl, isSelected: isSelected))
            )
            .overlay(alignment: .topLeading) {
                // علامة المرجعية على فاصلة الآية فقط، فلا تتكرر مع كل كلمة
                if t.isMarker, bookmarks.contains(t.ref) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(palette.accent)
                        .offset(x: -2, y: -3)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onTapAyah(t.ref) }
    }

    private func background(hl: HighlightColor?, isSelected: Bool) -> Color {
        if isSelected { return palette.accent.opacity(0.20) }
        if let hl { return hl.color(dark: isDark) }
        return .clear
    }

    /// مقاطع من خمس آيات: تبقي التمرير سلسًا وتحدّ من عدد العناصر المرسومة.
    private var chunks: [[AyahRef]] {
        guard let s = surah else { return [] }
        let refs = (1...s.ayahCount).map { AyahRef(surah: surahId, ayah: $0) }
        return stride(from: 0, to: refs.count, by: 5).map {
            Array(refs[$0..<min($0 + 5, refs.count)])
        }
    }

    private func medallion(_ n: Int) -> String {
        let ar = Array("٠١٢٣٤٥٦٧٨٩")
        let digits = String(String(n).compactMap { c -> Character? in
            guard let d = c.wholeNumberValue else { return nil }
            return ar[d]
        })
        return "﴿\(digits)﴾"
    }
}

// MARK: - ضوابط القراءة

struct ReaderControls: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AtharBackground()
            VStack(spacing: 22) {
                Capsule().fill(Theme.hairline).frame(width: 36, height: 5).padding(.top, 10)

                VStack(spacing: 12) {
                    HStack {
                        Text("حجم الخط").font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                        Spacer()
                        Text(String(format: "%.0f٪", store.mushafFontScale * 100))
                            .font(Theme.display(14)).foregroundStyle(Theme.inkSoft).monospacedDigit()
                    }
                    HStack(spacing: 12) {
                        Button { bump(-0.1) } label: { stepper("textformat.size.smaller") }
                        Slider(value: Binding(get: { store.mushafFontScale },
                                              set: { store.mushafFontScale = $0 }),
                               in: 0.7...2.2, step: 0.05)
                            .tint(Theme.accent)
                        Button { bump(0.1) } label: { stepper("textformat.size.larger") }
                    }
                    Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                        .font(Theme.dhikrFont(size: 21, scale: store.mushafFontScale))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceAlt))
                        .animation(Motion.snappy, value: store.mushafFontScale)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("سِمة الصفحة").font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                    HStack(spacing: 10) {
                        ForEach(ReadingTheme.allCases) { theme in
                            themeChip(theme)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
    }

    private func bump(_ d: Double) {
        store.mushafFontScale = max(0.7, min(2.2, store.mushafFontScale + d))
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    private func stepper(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: 38, height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surfaceAlt))
    }

    private func themeChip(_ theme: ReadingTheme) -> some View {
        let p = ReadingPalette.of(theme)
        let on = store.readingTheme == theme
        return Button {
            store.readingTheme = theme
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(p.paper)
                    Text("ٱ").font(.system(size: 21)).foregroundStyle(p.ink)
                }
                .frame(height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(on ? Theme.accent : Theme.hairline, lineWidth: on ? 2 : 1)
                )
                Text(theme.title)
                    .font(Theme.display(12, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - إجراءات الآية

struct AyahActions: View {
    let ref: AyahRef
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    private var text: String { Quran.text(ref) ?? "" }
    private var surahName: String { Quran.surah(ref.surah)?.name ?? "" }

    var body: some View {
        ZStack {
            AtharBackground()
            VStack(spacing: 16) {
                Capsule().fill(Theme.hairline).frame(width: 36, height: 5).padding(.top, 10)

                Text("\(surahName) · الآية \(ref.ayah.counterText)")
                    .font(Theme.display(13, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                Text(text)
                    .font(Theme.dhikrFont(size: 19))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 8)

                // ألوان التظليل — كما يُظلّل القارئ في مصحفه الورقي
                VStack(alignment: .leading, spacing: 8) {
                    Text("تظليل الآية")
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 10) {
                        ForEach(HighlightColor.allCases) { c in
                            let on = store.highlight(ref) == c
                            Button {
                                store.setHighlight(on ? nil : c, for: ref)
                                Haptics.tap(enabled: store.hapticsEnabled)
                            } label: {
                                Circle()
                                    .fill(c.color(dark: false).opacity(1))
                                    .frame(width: 34, height: 34)
                                    .overlay(
                                        Circle().stroke(on ? Theme.ink : Theme.hairline,
                                                        lineWidth: on ? 2.5 : 1)
                                    )
                                    .overlay {
                                        if on {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(Theme.ink)
                                        }
                                    }
                            }
                            .pressable(scale: 0.9)
                        }

                        if store.highlight(ref) != nil {
                            Button {
                                store.setHighlight(nil, for: ref)
                                Haptics.tap(enabled: store.hapticsEnabled)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.inkSoft)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Theme.surfaceAlt))
                            }
                            .pressable(scale: 0.9)
                            .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                    }
                }
                .animation(Motion.snappy, value: store.highlight(ref))

                SettingsCard {
                    Button {
                        store.toggleBookmark(ref)
                        Haptics.tap(enabled: store.hapticsEnabled)
                        dismiss()
                    } label: {
                        SettingsRow(icon: store.isBookmarked(ref) ? "bookmark.slash.fill" : "bookmark.fill",
                                    tint: Theme.gold,
                                    title: store.isBookmarked(ref) ? "إزالة العلامة" : "وضع علامة")
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()
                    Button {
                        store.recordReview(ref, passed: true)
                        Haptics.done(enabled: store.hapticsEnabled)
                        dismiss()
                    } label: {
                        SettingsRow(icon: "brain.head.profile", tint: Theme.accent(for: "sea"),
                                    title: "أضِف إلى الحفظ",
                                    subtitle: store.card(for: ref) == nil ? nil : "مضافة — للمراجعة")
                    }
                    .buttonStyle(.plain)

                    SettingsDivider()
                    ShareLink(item: "\(text)\n\n[\(surahName): \(ref.ayah)]\n\nمن تطبيق أثر") {
                        SettingsRow(icon: "square.and.arrow.up.fill", tint: Theme.accent, title: "مشاركة الآية")
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}
