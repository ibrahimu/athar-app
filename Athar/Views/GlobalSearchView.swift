import SwiftUI

// MARK: - البحث الموحّد

/// حقل واحد يمرّ على كل ما في التطبيق: آيات المصحف، والأحاديث، والأذكار، وأسماء الله
/// الحسنى، والأحكام، وأسماء السور والأقسام. النتائج مجموعاتٌ مرتّبة، لكل مجموعة رأسها
/// وخمسٌ منها و«المزيد» تبلغ شاشتها. والبحث نفسه يجري خارج الخيط الرئيسي كبحث المصحف.
struct GlobalSearchView: View {
    /// صفوف النتائج تقرأ ألوان الطابع ساكنةً؛ مراقبة المخزن هي ما يعيد صبغها فور تبديله.
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results = GlobalSearchResults()
    /// جارٍ البحث: النتائج لا تصل فورًا (إمهالُ ربع ثانية ثم مسحٌ خارج الخيط الرئيسي)،
    /// فبغير هذه العلامة تبدو الشاشة وكأنها لم تجد شيئًا وهي لم تبحث بعد.
    @State private var searching = false
    /// المجموعات المكشوفة بعناوينها — تُصفَّر مع كل استعلام جديد فلا يرث بحثٌ كشفَ ما قبله.
    @State private var expanded: Set<String> = []

    /// خمسٌ من كل مجموعة — قدرُ ما يُقرأ بنظرة، وما وراءه تفتحه «المزيد».
    private static let cap = 5

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent(for: "sea"), secondary: Theme.gold)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if trimmed.count < 2 {
                        hint
                    } else if results.isEmpty {
                        if searching { searchingRow } else { noResults }
                    } else {
                        // الترتيب مقصود: ما يُقصد بالاسم أولًا (السور)، ثم النصّ الشرعي
                        // على منزلته — آيةٌ فذكرٌ فحديث — ثم الشرح، وأقسام التطبيق آخرًا.
                        surahsGroup
                        ayahsGroup
                        adhkarGroup
                        hadithGroup
                        namesGroup
                        ahkamGroup
                        sectionsGroup
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 6)
                .padding(.bottom, 32)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            // البحث يمسح المصحف كلّه ومئات الأحاديث ويجرّد تشكيلها — لو جرى في الخيط
            // الرئيسي مع كل حرف لتقطّعت الكتابة. فيُمهَل ربع ثانية ويُلغى بالحرف التالي،
            // ثم يجري خارج الخيط الرئيسي مرّةً واحدة لكل استعلام. (كـ MushafView تمامًا.)
            .task(id: query) {
                let q = trimmed
                // استعلامٌ جديد يطوي ما كُشف قبله: الكشف كان لنتائج ذهبت.
                expanded = []
                guard q.count >= 2 else {
                    results = GlobalSearchResults()
                    searching = false
                    return
                }
                searching = true
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                let cap = Self.cap
                let found = await Task.detached(priority: .userInitiated) {
                    searchEverything(q, cap: cap)
                }.value
                guard !Task.isCancelled, let found else { return }
                results = found
                searching = false
            }
        }
        .navigationTitle(loc("البحث"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .searchable(text: $query, prompt: Text(loc("ابحث في القرآن والحديث والأذكار والأحكام")))
    }

    // MARK: المجموعات

    private var surahsGroup: some View {
        group(loc("السور"), tint: Theme.accent, bucket: results.surahs,
              more: loc("المزيد من السور")) { surah in
            NavigationLink { SurahReaderView(surahId: surah.id) } label: { SurahRow(surah: surah) }
                .pressable()
        }
    }

    private var ayahsGroup: some View {
        group(loc("الآيات"), tint: Theme.gold, bucket: results.ayahs,
              more: loc("المزيد من الآيات")) { ref in
            NavigationLink { SurahReaderView(surahId: ref.surah, scrollTo: ref) } label: {
                SearchHitRow(ref: ref, query: query)
            }
            .pressable()
        }
    }

    private var adhkarGroup: some View {
        group(loc("الأذكار"), tint: Theme.accent(for: "sea"), bucket: results.adhkar,
              more: loc("المزيد من الأذكار")) { hit in
            NavigationLink { DhikrSessionView(category: hit.category) } label: {
                resultCard(caption: hit.category.title,
                           tint: Theme.accent(for: hit.category.accent),
                           sacred: hit.dhikr.text,
                           footnote: hit.dhikr.hasReference ? hit.dhikr.reference : nil)
            }
            .pressable()
        }
    }

    private var hadithGroup: some View {
        group(loc("الأحاديث"), tint: Theme.accent(for: "sea"), bucket: results.hadiths,
              more: loc("المزيد من الأحاديث")) { hadith in
            NavigationLink { HadithDetailView(hadith: hadith) } label: {
                resultCard(caption: hadith.bookTitle,
                           tint: Theme.accent(for: "sea"),
                           sacred: hadith.text,
                           footnote: hadith.citation)
            }
            .pressable()
        }
    }

    private var namesGroup: some View {
        group(loc("الأسماء الحسنى"), tint: Theme.accent(for: "dusk"), bucket: results.names,
              more: loc("المزيد من الأسماء")) { name in
            NavigationLink { NameDetailView(name: name) } label: { nameRow(name) }
                .pressable()
        }
    }

    private var ahkamGroup: some View {
        group(loc("الأحكام"), tint: Theme.accent(for: "green"), bucket: results.ahkam,
              more: loc("المزيد من الأحكام")) { hit in
            NavigationLink {
                AhkamItemView(section: hit.section, index: hit.index, tint: Theme.accent(for: hit.accent))
            } label: {
                ahkamRow(hit)
            }
            .pressable()
        }
    }

    /// الأقسام كسائر المجموعات: تُكشف في مكانها. وكانت «المزيد» ترجع إلى الشبكة —
    /// فتضيع النتائج كلّها لمن أراد قسمًا واحدًا زائدًا.
    private var sectionsGroup: some View {
        group(loc("الأقسام"), tint: Theme.accent(for: "dawn"), bucket: results.sections,
              more: loc("المزيد من الأقسام")) { tab in
            NavigationLink { SectionDestination(tab: tab) } label: { tabRow(tab) }
                .pressable()
        }
    }

    // MARK: قالب المجموعة

    /// رأسٌ ونتائجُه و«المزيد» — قالبٌ واحد لسبع مجموعات، فلا يختلف إيقاعها ولا مسافاتها.
    @ViewBuilder
    private func group<T: Identifiable, Row: View>(
        _ title: String,
        tint: Color,
        bucket: SearchBucket<T>,
        more: String,
        @ViewBuilder row: @escaping (T) -> Row
    ) -> some View {
        if !bucket.isEmpty {
            let open = expanded.contains(title)
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: title, tint: tint)
                ForEach(bucket.shown(expanded: open)) { item in row(item) }
                if bucket.hasMore {
                    // الكشف في مكانه: الاستعلام باقٍ والنتائج تحته، ولا يُدفع الباحث إلى فهرسٍ يبدأ من أوّله.
                    Button {
                        withAnimation(Motion.smooth) {
                            if open { expanded.remove(title) } else { expanded.insert(title) }
                        }
                    } label: {
                        moreRow(open ? loc("عرض أقلّ") : more, tint: tint, open: open)
                    }
                    .buttonStyle(.plain)
                }
                if open, bucket.beyondDepth > 0 {
                    Text(loc("ومثلها %1$@ — ضيّق كلمة البحث لتصل إليها.", bucket.beyondDepth.counterText))
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    private func moreRow(_ title: String, tint: Color, open: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(Theme.display(14, weight: .semibold))
                .foregroundStyle(tint)
            Image(systemName: open ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint.opacity(0.7))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .tapTarget()
    }

    // MARK: الصفوف

    /// صفّ نصٍّ شرعي: عزوه فوقه، والنصّ بخطّ النسخ لا بخطّ الواجهة، ثم تخريجه.
    private func resultCard(caption: String, tint: Color, sacred: String, footnote: String?) -> some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(caption)
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(sacred)
                    .font(Theme.dhikrFont(size: 16))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(6)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                if let footnote, !footnote.isEmpty {
                    Text(footnote)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nameRow(_ name: DivineName) -> some View {
        let tint = Theme.accent(for: "dusk")
        return AtharCard(padding: 14) {
            HStack(spacing: 14) {
                // الاسم نصٌّ شرعي فيُكتب بالنسخ، والمعنى شرحٌ فيبقى بخطّ الواجهة.
                Text(name.name)
                    .font(Theme.naskhFont(size: 19, bold: true))
                    .foregroundStyle(tint)
                    .frame(minWidth: 74, alignment: .leading)
                Text(name.meaning)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    private func ahkamRow(_ hit: AhkamHit) -> some View {
        let tint = Theme.accent(for: hit.accent)
        return AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(hit.topicTitle)
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(tint)
                Text(hit.item.title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Text(hit.item.body)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tabRow(_ tab: AppTab) -> some View {
        let tint = Theme.accent(for: tab.accentKey)
        return AtharCard(padding: 14) {
            HStack(spacing: 13) {
                // الصلاة والحج رمزاهما مرسومان (سجّادة وكعبة) فلا يسعهما IconChip —
                // تُرسم رقاقتهما بمقاسها نفسه كما في بلاطة القسم.
                TabGlyph(tab: tab, size: 17)
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(tint.opacity(0.13)))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tab.title)
                        .font(Theme.display(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(tab.blurb)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    // MARK: حالتا الفراغ

    private var hint: some View {
        AtharCard(padding: 18, elevation: .e2, tint: Theme.accent(for: "sea")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 13) {
                    IconChip(icon: "magnifyingglass", tint: Theme.accent(for: "sea"), size: .lg)
                    Text(loc("بحثٌ واحد يمرّ على كل شيء"))
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
                Text(loc("الآيات والأحاديث والأذكار وأسماء الله الحسنى والأحكام وأسماء السور والأقسام. حرفان يكفيان، ولا يضرّك تشكيلٌ ولا صورةُ همزة."))
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 8)
    }

    private var noResults: some View {
        ContentUnavailableView(loc("لا توجد نتائج"), systemImage: "magnifyingglass",
                               description: Text(loc("جرّب كلمة أخرى أو جزءًا من آية")))
            .padding(.top, 50)
    }

    /// سطرٌ هادئ بين الحرف الأخير ووصول النتائج — بغيره تبدو الشاشة خاليةً وهي تبحث.
    private var searchingRow: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            Text(loc("جارٍ البحث…"))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(loc("جارٍ البحث…"))
    }
}

// MARK: - حصيلة البحث

/// حصيلة مجموعة: ما يُعرض منها وعددها كلّه — فـ«المزيد» لا تظهر إلا ووراءها شيء.
/// نتائج مجموعةٍ واحدة: ما يُعرض أوّلًا، وما يُكشف عند «المزيد» في الشاشة نفسها،
/// والعدد كلّه. تُحفظ الزيادة هنا لا في شاشةٍ أخرى: «المزيد» كان يدفع الفهرس عاريًا
/// من الاستعلام، فيجد الباحثُ نفسه في أوّل القائمة يبحث من جديد.
private struct SearchBucket<T> {
    /// ما استُبقي للكشف — لا كلّ ما وُجد: مئات الصفوف في شاشة واحدة ثقيلة بلا فائدة.
    static var depth: Int { 40 }

    var items: [T] = []
    var cap: Int = 5
    var total: Int = 0

    init() {}
    init(_ all: [T], cap: Int) {
        self.items = Array(all.prefix(Self.depth))
        self.cap = cap
        self.total = all.count
    }
    init(shown: [T], total: Int, cap: Int = 5) {
        self.items = shown
        self.cap = cap
        self.total = total
    }

    var shown: [T] { Array(items.prefix(cap)) }
    func shown(expanded: Bool) -> [T] { expanded ? items : shown }

    var isEmpty: Bool { items.isEmpty }
    var hasMore: Bool { items.count > cap }
    /// ما وراء العمق لا يُكشف هنا: يُقال عدده ليضيّق الباحث كلمته.
    var beyondDepth: Int { max(0, total - items.count) }
}

/// ذكرٌ مع قسمه — القسم هو ما تُفتح به الجلسة، والذكر وحده لا يعرف أهله.
private struct DhikrHit: Identifiable {
    let category: DhikrCategory
    let dhikr: Dhikr
    /// الذكر الواحد قد يتكرّر في قسمين، فيُقرن المعرّف بقسمه حتى لا تشتبه صفوف القائمة.
    var id: String { "\(category.id)/\(dhikr.id)" }
}

/// حكمٌ مع بابه وموضعه فيه — شاشة الحكم تُفتح بالباب والفهرس لا بالحكم مفردًا.
private struct AhkamHit: Identifiable {
    let topicTitle: String
    /// مفتاح لون الموضوع؛ يُترجَم لونًا في الواجهة لا هنا (Theme لا يُقرأ خارج الخيط الرئيسي).
    let accent: String
    let section: AhkamSection
    let index: Int

    var item: AhkamItem { section.items[index] }
    var id: String { "\(section.id)/\(item.id)" }
}

private struct GlobalSearchResults {
    var surahs = SearchBucket<Surah>()
    var ayahs = SearchBucket<AyahRef>()
    var adhkar = SearchBucket<DhikrHit>()
    var hadiths = SearchBucket<Hadith>()
    var names = SearchBucket<DivineName>()
    var ahkam = SearchBucket<AhkamHit>()
    var sections = SearchBucket<AppTab>()

    var isEmpty: Bool {
        surahs.isEmpty && ayahs.isEmpty && adhkar.isEmpty && hadiths.isEmpty
            && names.isEmpty && ahkam.isEmpty && sections.isEmpty
    }
}

// MARK: - المسح

/// مفتاح المطابقة: تطبيع «أثر» نفسه (بلا تشكيل، والهمزات ألفًا، والتاء المربوطة هاءً)،
/// ثم توحيد الفراغات — فنصوص الأذكار فيها أسطر جديدة يقطعها المستخدم بمسافة واحدة —
/// وخفضُ اللاتيني ليجد «Al-Fatihah» من كتب «fatiha».
/// مفتاح المطابقة: تجريدٌ من التشكيل ثم إسقاط ما ليس حرفًا ولا رقمًا غربيًّا —
/// نصوص الأذكار تتخلّلها أرقام الآيات الهندية وأقواسها وعلامات الترقيم، فلو بقيت
/// لانقطعت العبارة عند أوّل قوسٍ وفشل بحثُ من كتبها متّصلة.
private func matchKey(_ s: String) -> String {
    let cleaned = ArabicMatch.normalize(s)
        .lowercased()
        .map { ch -> Character in
            if ch.isLetter { return ch }
            if ch.isNumber, ch.isASCII { return ch }
            return " "
        }
    return String(cleaned)
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")
}

/// المسح كلّه — دالّة حرّة تُنفَّذ في مهمّة منفصلة، ولا تلمس Theme ولا أي شيء من الواجهة.
/// تُعيد nil متى أُلغيت، فلا تُسلَّم للشاشة حصيلةٌ نصفُها لاستعلام قديم.
private func searchEverything(_ raw: String, cap: Int) -> GlobalSearchResults? {
    let key = matchKey(raw)
    guard key.count >= 2 else { return GlobalSearchResults() }
    var out = GlobalSearchResults()

    // السور: بالاسم العربي، أو باللاتيني كما يُكتب، أو برقمها.
    out.surahs = SearchBucket(Quran.surahs.filter {
        matchKey($0.name).contains(key) || matchKey($0.nameSimple).contains(key) || String($0.id) == raw
    }, cap: cap)
    if Task.isCancelled { return nil }

    // الآيات: بحث المصحف نفسه، بحدٍّ يزيد واحدًا على المعروض ليُعرف هل وراءه مزيد.
    let hits = Quran.search(raw, limit: cap + 1)
    out.ayahs = SearchBucket(shown: Array(hits.prefix(cap)), total: hits.count)
    if Task.isCancelled { return nil }

    // الأذكار: عنوان القسم يُمثَّل بأول ذكرٍ فيه — من كتب «الصباح» يريد جلسة أذكار
    // الصباح لا أذكارها مصفوفةً واحدًا واحدًا في النتائج.
    var adhkar: [DhikrHit] = []
    for c in AdhkarLibrary.categories {
        if matchKey(c.title).contains(key) || matchKey(c.subtitle).contains(key) {
            if let first = c.items.first { adhkar.append(DhikrHit(category: c, dhikr: first)) }
            continue
        }
        for d in c.items where matchKey(d.text).contains(key) {
            adhkar.append(DhikrHit(category: c, dhikr: d))
        }
    }
    out.adhkar = SearchBucket(adhkar, cap: cap)
    if Task.isCancelled { return nil }

    // الأحاديث: مكتبة الحديث تبحث بمفتاحها المتسامح في الكتابين معًا.
    out.hadiths = SearchBucket(HadithLibrary.search(raw), cap: cap)
    if Task.isCancelled { return nil }

    out.names = SearchBucket(NamesLibrary.all.filter {
        matchKey($0.name).contains(key) || matchKey($0.meaning).contains(key)
    }, cap: cap)
    if Task.isCancelled { return nil }

    // الأحكام: كالأذكار — الموضوع المطابق يُمثَّل بأول أحكامه لا بها كلها.
    var ahkam: [AhkamHit] = []
    for t in AhkamLibrary.topics {
        if matchKey(t.title).contains(key) || matchKey(t.summary).contains(key) {
            if let s = t.sections.first, !s.items.isEmpty {
                ahkam.append(AhkamHit(topicTitle: t.title, accent: t.accent, section: s, index: 0))
            }
            continue
        }
        for s in t.sections {
            for (i, item) in s.items.enumerated()
            where matchKey(item.title).contains(key) || matchKey(item.body).contains(key) {
                ahkam.append(AhkamHit(topicTitle: t.title, accent: t.accent, section: s, index: i))
            }
        }
    }
    out.ahkam = SearchBucket(ahkam, cap: cap)
    if Task.isCancelled { return nil }

    out.sections = SearchBucket(AppTab.sections.filter {
        matchKey($0.title).contains(key) || matchKey($0.blurb).contains(key)
    }, cap: cap)

    return out
}
