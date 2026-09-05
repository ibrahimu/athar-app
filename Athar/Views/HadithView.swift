import SwiftUI

// MARK: - أدوات مشتركة

/// تمييز العدد لـ«حديث»: واحد، ومثنّى، وجمعٌ من ٣ إلى ١٠، ومفردٌ منصوب لما فوقها.
private func hadithCountText(_ n: Int) -> String {
    switch n {
    case 0: return loc("لا أحاديث")
    case 1: return loc("حديث واحد")
    case 2: return loc("حديثان")
    case 3...10: return loc("%1$@ أحاديث", n.counterText)
    default: return loc("%1$@ حديثًا", n.counterText)
    }
}

/// لون قسم الحديث في التطبيق كله (كبطاقة «حديث اليوم» في الرئيسية).
private var hadithTint: Color { Theme.accent(for: "sea") }

/// نصّ المشاركة والنسخ: المتن ثم عزوه ثم اسم التطبيق — كالآية والذكر.
private func hadithShareText(_ h: Hadith) -> String {
    "\(h.text)\n\n\(h.citation)\n\nمن تطبيق أثر"
}

// MARK: - لوحة الحديث

/// لوحة الحديث: حديث اليوم، وبحث في الكتابين، والمحفوظة، ثم الكتابان.
struct HadithView: View {
    var isRootTab = false

    @EnvironmentObject private var store: AtharStore
    @State private var query = ""
    @State private var results: [Hadith] = []
    @State private var sahihaynOnly = false

    private var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isSearching: Bool { !trimmedQuery.isEmpty }
    private var shown: [Hadith] { sahihaynOnly ? results.filter(\.isSahihayn) : results }

    var body: some View {
        ZStack {
            AtharBackground(tint: hadithTint)
            ScrollView {
                LazyVStack(spacing: 14) {
                    if isSearching {
                        searchSection
                    } else {
                        if let h = HadithLibrary.daily(for: Date()) { hero(h).appearStagger(0) }
                        favoritesRow.appearStagger(1)
                        booksSection.appearStagger(2)
                        credit
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 6)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .searchable(text: $query, prompt: loc("ابحث في الأحاديث"))
        // البحث يمرّ على نحو ألفي حديث ويطبّع نصّ كلٍّ منها، فيُؤجَّل قليلًا بعد آخر
        // حرف ويُجرى خارج الخيط الرئيس حتى لا يتلعثم الكيبورد.
        .task(id: query) {
            let q = trimmedQuery
            guard q.count >= 2 else { results = []; return }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            let found = await Task.detached(priority: .userInitiated) { HadithLibrary.search(q) }.value
            guard !Task.isCancelled else { return }
            results = found
        }
        .navigationTitle(loc("الحديث"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }

    // MARK: حديث اليوم

    private func hero(_ h: Hadith) -> some View {
        NavigationLink { HadithDetailView(hadith: h) } label: {
            AtharCard(padding: 18, elevation: .e2, tint: hadithTint) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(loc("حديث اليوم"))
                            .font(Theme.display(11, weight: .medium))
                            .foregroundStyle(hadithTint)
                        Spacer()
                        if h.isSahihayn { GradeChip() }
                    }
                    Text(h.text)
                        .font(Theme.dhikrFont(size: 17))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(7)
                        .lineLimit(8)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Text(h.citation)
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(hadithTint)
                    }
                }
            }
        }
        .pressable()
    }

    // MARK: المحفوظة

    private var favoritesRow: some View {
        let n = store.hadithFavorites.count
        return NavigationLink { HadithFavoritesView() } label: {
            AtharLinkRow(icon: "heart.fill", tint: hadithTint, title: loc("المحفوظة"),
                         subtitle: n == 0 ? loc("اضغط القلب على أي حديث ليبقى هنا") : hadithCountText(n))
        }
        .pressable()
    }

    // MARK: الكتابان

    @ViewBuilder
    private var booksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("الكتب"), tint: hadithTint)
            if HadithLibrary.books.isEmpty {
                ContentUnavailableView(loc("تعذّر تحميل الأحاديث"), systemImage: "text.book.closed",
                                       description: Text(loc("أعد فتح التطبيق.")))
                    .padding(.top, 10)
            }
            ForEach(HadithLibrary.books) { book in
                bookCard(book)
            }
        }
    }

    /// كتاب ذو باب واحد (الأربعون) يفتح أحاديثه مباشرةً — قائمة بصفّ واحد لا تنفع.
    private func bookCard(_ book: HadithBook) -> some View {
        NavigationLink {
            if book.chapters.count == 1, let only = book.chapters.first {
                HadithChapterView(book: book, chapter: only)
            } else {
                HadithBookView(book: book)
            }
        } label: {
            AtharCard(padding: 16) {
                HStack(spacing: 14) {
                    IconChip(icon: book.id == "nawawi40" ? "text.book.closed.fill" : "books.vertical.fill",
                             tint: hadithTint, size: .lg)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(Theme.display(17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(book.author)
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(book.chapters.count == 1
                             ? hadithCountText(book.count)
                             : loc("%1$@ بابًا · %2$@", book.chapters.count.counterText, hadithCountText(book.count)))
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    // MARK: البحث

    @ViewBuilder
    private var searchSection: some View {
        HStack(spacing: 10) {
            SettingsGroupTitle(text: trimmedQuery.count < 2 ? loc("البحث") : hadithCountText(shown.count),
                               tint: hadithTint)
            Spacer()
            sahihaynChip
        }
        .padding(.top, 2)
        .padding(.horizontal, 2)

        if trimmedQuery.count < 2 {
            Text(loc("اكتب حرفين على الأقل."))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
        } else if shown.isEmpty {
            ContentUnavailableView(loc("لا نتائج"), systemImage: "magnifyingglass",
                                   description: Text(sahihaynOnly
                                                     ? loc("جرّب كلمة أخرى، أو أزل قيد الصحيحين.")
                                                     : loc("جرّب كلمة أخرى.")))
                .padding(.top, 20)
        } else {
            HadithRows(hadiths: shown) { h in
                let chapter = HadithLibrary.chapter(of: h)?.title ?? ""
                return chapter.isEmpty || chapter == h.bookTitle ? h.citation : "\(h.bookTitle) · \(chapter)"
            }
        }
    }

    /// رقاقة تقصر النتائج على ما عزاه النووي إلى البخاري أو مسلم.
    private var sahihaynChip: some View {
        Button {
            withAnimation(Motion.snappy) { sahihaynOnly.toggle() }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: sahihaynOnly ? "checkmark.seal.fill" : "seal")
                    .font(.system(size: 11, weight: .semibold))
                Text(loc("الصحيحين فقط"))
                    .font(Theme.display(12, weight: .medium))
            }
            .foregroundStyle(sahihaynOnly ? hadithTint : Theme.inkSoft)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(sahihaynOnly ? hadithTint.opacity(0.14) : Theme.surfaceAlt))
            .overlay(Capsule().strokeBorder(sahihaynOnly ? hadithTint.opacity(0.25) : Theme.hairline.opacity(0.5),
                                            lineWidth: 0.6))
        }
        .pressable()
        .accessibilityAddTraits(sahihaynOnly ? .isSelected : [])
    }

    private var credit: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Theme.hairline.opacity(0.6))
                .frame(height: 0.7).padding(.horizontal, 50).padding(.top, 10)
            Text(HadithLibrary.sourceNote)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }
}

// MARK: - أبواب الكتاب

/// أبواب كتاب واحد: العنوان وعدد أحاديثه.
struct HadithBookView: View {
    let book: HadithBook
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        ZStack {
            AtharBackground(tint: hadithTint)
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 6) {
                        Text(book.author)
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                        countPill(loc("%1$@ بابًا · %2$@", book.chapters.count.counterText, hadithCountText(book.count)))
                    }
                    .padding(.top, 4)

                    SettingsCard {
                        ForEach(Array(book.chapters.enumerated()), id: \.element.id) { i, chapter in
                            NavigationLink { HadithChapterView(book: book, chapter: chapter) } label: {
                                SettingsRow(icon: "text.book.closed", tint: hadithTint,
                                            title: chapter.title,
                                            subtitle: hadithCountText(chapter.hadiths.count)) {
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.inkFaint)
                                }
                            }
                            .buttonStyle(.plain)
                            if i < book.chapters.count - 1 { SettingsDivider() }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

/// شارة عدد هادئة بلون القسم — كشريط الخطوات في دليل الحج.
private func countPill(_ text: String) -> some View {
    Text(text)
        .font(Theme.display(12, weight: .semibold))
        .foregroundStyle(hadithTint)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(Capsule().fill(hadithTint.opacity(0.12)))
}

// MARK: - أحاديث الباب

/// أحاديث باب واحد — كتاب المقدمات وحده ٦٧٩ حديثًا، فالقائمة كسولة.
struct HadithChapterView: View {
    let book: HadithBook
    let chapter: HadithChapter
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        ZStack {
            AtharBackground(tint: hadithTint)
            ScrollView {
                LazyVStack(spacing: 14) {
                    VStack(spacing: 6) {
                        if chapter.title != book.title {
                            Text(book.title)
                                .font(Theme.display(13))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        countPill(hadithCountText(chapter.hadiths.count))
                    }
                    .padding(.top, 4)

                    if chapter.hadiths.isEmpty {
                        ContentUnavailableView(loc("لا أحاديث في هذا الباب"), systemImage: "text.book.closed")
                            .padding(.top, 20)
                    } else {
                        HadithRows(hadiths: chapter.hadiths)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - المحفوظة

/// ما حفظه المستخدم بترتيب حفظه (الأحدث أولًا).
struct HadithFavoritesView: View {
    @EnvironmentObject private var store: AtharStore

    private var hadiths: [Hadith] { store.hadithFavorites.compactMap { HadithLibrary.hadith(id: $0) } }

    var body: some View {
        ZStack {
            AtharBackground(tint: hadithTint)
            ScrollView {
                LazyVStack(spacing: 14) {
                    if hadiths.isEmpty {
                        ContentUnavailableView(loc("لا أحاديث محفوظة"), systemImage: "heart",
                                               description: Text(loc("اضغط القلب على أي حديث ليبقى هنا.")))
                            .padding(.top, 40)
                    } else {
                        countPill(hadithCountText(hadiths.count)).padding(.top, 4)
                        HadithRows(hadiths: hadiths) { h in
                            let chapter = HadithLibrary.chapter(of: h)?.title ?? ""
                            return chapter.isEmpty || chapter == h.bookTitle ? h.citation : "\(h.bookTitle) · \(chapter)"
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .animation(Motion.smooth, value: store.hadithFavorites)
        .navigationTitle(loc("المحفوظة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - قطع مشتركة

/// قائمة أحاديث كسولة على سطح بطاقة واحد. البطاقة الجاهزة تبني صفوفها كلّها
/// دفعةً، وهذا لا يصلح لباب فيه مئات الأحاديث.
private struct HadithRows: View {
    let hadiths: [Hadith]
    /// وصف الصفّ تحت المتن — العزو افتراضيًا، أو الكتاب والباب في البحث والمحفوظة.
    var caption: ((Hadith) -> String)? = nil
    /// مدخلات القائمة لا تتغيّر مع الطابع، فلولا مراقبة المخزن لتخطّى SwiftUI جسمها
    /// وبقي سطح البطاقة بألوانه القديمة بعد تبديل الطابع.
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(hadiths.enumerated()), id: \.element.id) { i, h in
                HadithRow(hadith: h, caption: caption?(h))
                if i < hadiths.count - 1 { SettingsDivider(inset: 16) }
            }
        }
        .background(CardSurface(radius: Theme.Radius.lg))
    }
}

/// صفّ حديث: المتن في أربعة أسطر، وعزوه، وقلب الحفظ. القلب أخٌ للرابط لا ابنٌ له،
/// حتى لا تبتلع ضغطتَه ضغطةُ فتح الحديث.
private struct HadithRow: View {
    let hadith: Hadith
    var caption: String? = nil
    @EnvironmentObject private var store: AtharStore

    /// أربعة أسطر لا تحتاج أكثر من هذا؛ وبعض الأحاديث آلاف الحروف، فقصّها يبقي
    /// تخطيط الصفوف الطويلة خفيفًا.
    /// معاينة تُقصّ عند آخر كلمة كاملة وتُختم بعلامة الحذف — لا تُبتر كلمةٌ من الحديث.
    private var preview: String {
        guard hadith.text.count > 400 else { return hadith.text }
        let head = hadith.text.prefix(400)
        if let cut = head.lastIndex(of: " ") { return String(head[..<cut]) + "…" }
        return String(head) + "…"
    }

    var body: some View {
        let fav = store.isHadithFavorite(hadith.id)
        HStack(alignment: .top, spacing: 8) {
            NavigationLink { HadithDetailView(hadith: hadith) } label: {
                VStack(alignment: .leading, spacing: 7) {
                    Text(preview)
                        .font(Theme.dhikrFont(size: 15))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(5)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                    Text(caption ?? hadith.citation)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.toggleHadithFavorite(hadith.id)
                Haptics.tap(enabled: store.hapticsEnabled)
            } label: {
                Image(systemName: fav ? "heart.fill" : "heart")
                    .font(.system(size: 16))
                    .foregroundStyle(fav ? hadithTint : Theme.inkFaint)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle().inset(by: -5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(fav ? loc("إزالة من المحفوظة") : loc("حفظ الحديث"))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

/// «في الصحيحين» — تظهر فقط حين عزا النووي الحديث إلى البخاري أو مسلم.
/// لا تصحيح ولا تضعيف من عندنا لغيرها.
private struct GradeChip: View {
    /// بلا مدخلات تتبدّل، فمراقبة المخزن هي ما يعيد صبغها عند تبديل الطابع.
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(loc("في الصحيحين"))
                .font(Theme.display(11, weight: .semibold))
        }
        .foregroundStyle(hadithTint)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(hadithTint.opacity(0.12)))
    }
}

// MARK: - حديث واحد بتمامه

/// الحديث كاملًا مع عزوه وبابه، وحفظه ونسخه ومشاركته، والتنقّل داخل بابه.
struct HadithDetailView: View {
    let hadith: Hadith
    @EnvironmentObject private var store: AtharStore
    /// المعروض الآن — يتبدّل بالسابق/التالي داخل الباب بلا دفع صفحة جديدة.
    @State private var current: Hadith
    @State private var copied = false

    init(hadith: Hadith) {
        self.hadith = hadith
        _current = State(initialValue: hadith)
    }

    private var chapter: HadithChapter? { HadithLibrary.chapter(of: current) }
    private var index: Int? { chapter?.hadiths.firstIndex { $0.id == current.id } }
    private var previous: Hadith? {
        guard let c = chapter, let i = index, i > 0 else { return nil }
        return c.hadiths[i - 1]
    }
    private var next: Hadith? {
        guard let c = chapter, let i = index, i + 1 < c.hadiths.count else { return nil }
        return c.hadiths[i + 1]
    }
    private var isFavorite: Bool { store.isHadithFavorite(current.id) }

    var body: some View {
        ZStack {
            AtharBackground(tint: hadithTint)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        textCard.id("top")
                        actionsCard
                        if chapter != nil { chapterNav(proxy) }
                        footer
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 4)
                    .padding(.bottom, 30)
                    .readableWidth(620)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(current.bookTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: toggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(isFavorite ? hadithTint : Theme.inkSoft)
                }
                .accessibilityLabel(isFavorite ? loc("إزالة من المحفوظة") : loc("حفظ الحديث"))
            }
        }
    }

    // MARK: المتن

    private var textCard: some View {
        AtharCard(padding: 20, elevation: .e2) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    // اسم الباب لا يُكرَّر حين يطابق اسم الكتاب (الأربعون النووية).
                    if let title = chapter?.title, title != current.bookTitle {
                        HStack(spacing: 5) {
                            Image(systemName: "text.book.closed")
                                .font(.system(size: 10, weight: .semibold))
                            Text(title)
                                .font(Theme.display(11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 6)
                    if current.isSahihayn { GradeChip() }
                }

                Text(current.text)
                    .font(Theme.dhikrFont(size: 18, scale: store.fontScale))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(12)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                Rectangle().fill(Theme.hairline.opacity(0.55)).frame(height: 0.7)

                Text(current.citation)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(Motion.smooth, value: current.id)
    }

    // MARK: حفظ · نسخ · مشاركة

    private var actionsCard: some View {
        AtharCard(padding: 6) {
            HStack(spacing: 0) {
                Button(action: toggleFavorite) {
                    actionLabel(icon: isFavorite ? "heart.fill" : "heart",
                                text: isFavorite ? loc("محفوظ") : loc("حفظ"), on: isFavorite)
                }
                .buttonStyle(.plain)

                cellDivider

                Button {
                    UIPasteboard.general.string = hadithShareText(current)
                    Haptics.done(enabled: store.hapticsEnabled)
                    withAnimation(Motion.snappy) { copied = true }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(Motion.snappy) { copied = false }
                    }
                } label: {
                    actionLabel(icon: copied ? "checkmark.circle.fill" : "doc.on.doc",
                                text: copied ? loc("نُسخ") : loc("نسخ"), on: copied)
                }
                .buttonStyle(.plain)

                cellDivider

                ShareLink(item: hadithShareText(current)) {
                    actionLabel(icon: "square.and.arrow.up", text: loc("مشاركة"), on: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var cellDivider: some View {
        Rectangle().fill(Theme.hairline.opacity(0.5))
            .frame(width: 0.7, height: 34)
    }

    private func actionLabel(icon: String, text: String, on: Bool) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(on ? hadithTint : Theme.inkSoft)
                .frame(height: 18)
            Text(text)
                .font(Theme.display(11, weight: .medium))
                .foregroundStyle(on ? hadithTint : Theme.inkFaint)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func toggleFavorite() {
        store.toggleHadithFavorite(current.id)
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    // MARK: السابق والتالي داخل الباب

    private func chapterNav(_ proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 8) {
            if let c = chapter, let i = index {
                Text(loc("الحديث %1$@ من %2$@ في الباب", (i + 1).counterText, c.hadiths.count.counterText))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
            }
            HStack(spacing: 10) {
                navButton(loc("السابق"), icon: "chevron.backward", target: previous, proxy: proxy)
                navButton(loc("التالي"), icon: "chevron.forward", target: next, proxy: proxy)
            }
        }
    }

    /// الأسهم تنعكس مع اتجاه الواجهة وحدها: السابق يشير إلى اليمين في العربية.
    private func navButton(_ title: String, icon: String, target: Hadith?, proxy: ScrollViewProxy) -> some View {
        Button {
            guard let target else { return }
            withAnimation(Motion.smooth) {
                current = target
                proxy.scrollTo("top", anchor: .top)
            }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            Label(title, systemImage: icon)
                .font(Theme.display(14, weight: .semibold))
                .softButton(hadithTint, radius: Theme.Radius.sm)
        }
        .pressable()
        .disabled(target == nil)
        .opacity(target == nil ? 0.4 : 1)
    }

    // MARK: المصدر

    private var footer: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Theme.hairline.opacity(0.6))
                .frame(height: 0.7).padding(.horizontal, 50).padding(.top, 6)
            Text(HadithLibrary.sourceNote)
            Text(HadithLibrary.gradingNote)
        }
        .font(Theme.display(11))
        .foregroundStyle(Theme.inkFaint)
        .multilineTextAlignment(.center)
        .padding(.top, 4)
    }
}
