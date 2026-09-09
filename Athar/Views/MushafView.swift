import SwiftUI

struct MushafView: View {
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false
    @EnvironmentObject private var store: AtharStore
    /// يُرصَد المحرّك هنا لا يُقرأ قراءةً عابرة: بطاقة التلاوة تعرض اسم القارئ
    /// وعدد السور المحمَّلة، ولا شيء في المتجر يُعيد رسم الشاشة عند تغيّرهما.
    @StateObject private var audio = Recitation.shared
    @State private var query = ""
    /// نتائج البحث في نصّ المصحف — تُحسب مرّةً واحدة لكل استعلام لا مع كل رسم.
    @State private var hits: [AyahRef] = []
    /// البحث في النصّ جارٍ — تُميَّز عن «لا نتائج».
    @State private var searching = false

    /// رقمٌ مجرّد كتبه الباحث: مقصده موضعٌ في المصحف لا كلمةٌ في آية —
    /// «أذكر رقم الصفحة، وما في إلّا أن أقرّب لأرى أقرب صورة ثم أسحب».
    private var bareNumber: Int? { query.bareNumberValue }
    /// صفحةٌ قائمة — وما جاوز ٦٠٤ فلا صفّ له، بلا رسالة خطأ تقاطع الكتابة.
    private var pageJump: Int? {
        guard let n = bareNumber, n >= 1, n <= Quran.pageCount else { return nil }
        return n
    }
    /// والرقم نفسه قد يكون سورةً — فيُعرَض المقصدان معًا، والصفحة أولًا.
    private var surahJump: Int? {
        guard let n = bareNumber, n >= 1, n <= 114 else { return nil }
        return n
    }
    /// وقد يكون جزءًا: كثيرٌ يحفظ موضعه بالجزء لا بالصفحة. الثلاثون أضيق مدًى فتأتي بينهما.
    private var juzJump: Int? {
        guard let n = bareNumber, n >= 1, n <= Quran.juzCount else { return nil }
        return n
    }

    private var filtered: [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Quran.surahs }
        // الرقم المجرّد له صفّاه أعلى الشاشة، فلا تُكرَّر سورته في القائمة تحتهما.
        guard bareNumber == nil else { return [] }
        let n = q.searchKey
        return Quran.surahs.filter {
            $0.name.searchKey.contains(n)
            || $0.nameSimple.searchKey.contains(n)
            || String($0.id) == n
        }
    }

    var body: some View {
        MaybeStack(embedded: embedded) {
            ZStack {
                AtharBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if query.isEmpty {
                            stopMarkCard
                            continueCard
                            toolsRow
                            recitationCard
                            khatmahDuaCard
                            if !store.bookmarks.isEmpty { bookmarksCard }
                            SectionHeader(title: loc("suras"), tint: Theme.accent(for: "gold"))
                                .padding(.top, 2)
                        }

                        // الرقم المجرّد فوق كل شيء: صفحةً أولًا، ثم جزءًا، ثم سورةً إن صلح لها.
                        if let n = pageJump { pageJumpCard(n) }
                        if let j = juzJump { juzJumpCard(j) }
                        if let s = surahJump, let su = Quran.surah(s) {
                            NavigationLink { SurahReaderView(surahId: s) } label: {
                                SurahRow(surah: su)
                            }
                            .pressable()
                        }

                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, surah in
                            NavigationLink { SurahReaderView(surahId: surah.id) } label: {
                                SurahRow(surah: surah)
                            }
                            .pressable()
                            .appearStagger(i)
                        }

                        if !hits.isEmpty {
                            SettingsGroupTitle(text: loc("آيات مطابقة"))
                            ForEach(hits) { ref in
                                NavigationLink { SurahReaderView(surahId: ref.surah, scrollTo: ref) } label: {
                                    SearchHitRow(ref: ref, query: query)
                                }
                                .pressable()
                            }
                        }

                        if query.isEmpty { sourceCredit }

                        // البحث في النصّ مؤجَّل ثم يجري خارج الخيط الرئيسي، وكانت الحالة الفارغة
            // تتحقّق أثناءه فتقفز «لا توجد نتائج» في وجه من لم يُبحث له بعد.
            if searching {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity).padding(.top, 40)
            } else if filtered.isEmpty && hits.isEmpty && pageJump == nil && !query.isEmpty {
                            ContentUnavailableView(loc("لا توجد نتائج"), systemImage: "magnifyingglass",
                                                   description: Text(loc("جرّب اسم سورة أو جزءًا من آية")))
                                .padding(.top, 50)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    // المشغّل المصغّر يطفو فوق آخر صف ورابط تنزيل؛ فيُحجز له
                    // أسفل القائمة بالقدر نفسه الذي تحجزه شاشة التلاوة.
                    .padding(.bottom, audio.surah == nil ? 30 : 112)
                    .readableWidth(620)
                }
                .scrollIndicators(.hidden)
                // البحث يمسح ٦٢٣٦ آية ويجرّد تشكيلها — لو جرى في الخيط الرئيسي
                // مع كل حرف لتقطّعت الكتابة. فيُمهَل ربع ثانية ويُلغى بالحرف
                // التالي، ثم يجري خارج الخيط الرئيسي مرّةً واحدة لكل استعلام.
                .task(id: query) {
                    searching = false
                    let q = query.trimmingCharacters(in: .whitespaces)
                    // الرقم المجرّد مقصده الصفحة والسورة، ولا رقم في الرسم العثماني
                    // يُطابَق — فلا يُمشى به على ٦٢٣٦ آية.
                    guard bareNumber == nil else {
                        hits = []
                        return
                    }
                    guard q.count >= 3, filtered.isEmpty || q.count >= 4 else {
                        hits = []
                        return
                    }
                    searching = true
                    defer { searching = false }
                    try? await Task.sleep(for: .milliseconds(250))
                    guard !Task.isCancelled else { return }
                    let found = await Task.detached(priority: .userInitiated) {
                        Quran.search(q, limit: 25)
                    }.value
                    guard !Task.isCancelled else { return }
                    hits = found
                }
            }
            .overlay(alignment: .bottom) { MiniPlayer() }
            .navigationTitle(loc("mushaf"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text(loc("searchMushaf")))
            // لوحة المفاتيح تغطّي نصف الشاشة ولا تنزل: من مرّر ليقرأ النتائج بقيت
            // فوقها. فتنزل بأوّل تمريرة كما في سائر شاشات البحث.
            .scrollDismissesKeyboard(.immediately)
        }
    }

    // MARK: الانتقال بالرقم

    /// صفّ الصفحة: الرقم عنوانًا، وتحته إلى أين يقع من المصحف — فلا يقفز في العمياء.
    private func pageJumpCard(_ n: Int) -> some View {
        jumpCard(icon: "doc.plaintext.fill",
                 title: loc("الانتقال إلى صفحة %1$@", n.counterText),
                 ref: Quran.firstAyah(ofPage: n))
    }

    private func juzJumpCard(_ n: Int) -> some View {
        jumpCard(icon: "square.stack.3d.up.fill",
                 title: loc("الانتقال إلى الجزء %1$@", n.counterText),
                 ref: Quran.firstAyah(ofJuz: n))
    }

    /// بطاقة مقصدٍ في المصحف: عنوانها ما طُلب، وتحته موضعه — سورةً وجزءًا وصفحة —
    /// ليتبيّن الطالب قبل أن يذهب أهو الموضع الذي أراد.
    private func jumpCard(icon: String, title: String, ref: AyahRef) -> some View {
        NavigationLink { SurahReaderView(surahId: ref.surah, scrollTo: ref) } label: {
            AtharCard(padding: 16, elevation: .e2, tint: Theme.accent(for: "gold")) {
                HStack(spacing: 14) {
                    IconChip(icon: icon, tint: Theme.gold, size: .lg)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(Theme.display(16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(loc("سورة %1$@ · الجزء %2$@ · صفحة %3$@",
                                 Quran.surah(ref.surah)?.name ?? "",
                                 Quran.juz(of: ref).counterText,
                                 Quran.page(of: ref).counterText))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    // MARK: التلاوة

    /// مدخل التلاوة الصوتية: يفتح شاشةً تُشغّل السور بثًّا أو تنزّلها للاستماع بلا إنترنت.
    private var recitationCard: some View {
        let sum = audio.downloadedSummary(reciter: audio.reciterId)
        return NavigationLink { RecitationView() } label: {
            AtharCard(padding: 14, elevation: .e2, tint: Theme.accent) {
                HStack(spacing: 13) {
                    IconChip(icon: "waveform", size: .md)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loc("الاستماع للقرآن"))
                            .font(Theme.display(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(sum.count > 0
                             ? loc("%1$@ · %2$@", audio.reciter.name, downloadedLabel(sum.count))
                             : loc("%1$@ · شغّلها أو نزّلها للاستماع بلا إنترنت", audio.reciter.name))
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    /// تمييز العدد في العربية: مثنّى لاثنتين، جمع مجرور من ٣ إلى ١٠، ومفرد فيما فوقها.
    private func downloadedLabel(_ n: Int) -> String {
        switch n {
        case 1:      return loc("سورة واحدة محمَّلة")
        case 2:      return loc("سورتان محمَّلتان")
        case 3...10: return loc("%1$@ سور محمَّلة", n.counterText)
        default:     return loc("%1$@ سورة محمَّلة", n.counterText)
        }
    }

    /// إسناد نص المصحف — شرط رخصة Tanzil: إظهار المصدر بوضوح مع رابط.
    private var sourceCredit: some View {
        VStack(spacing: 7) {
            Rectangle().fill(Theme.hairline.opacity(0.6))
                .frame(height: 0.7).padding(.horizontal, 40).padding(.top, 10)
            Text(loc("نص المصحف بالرسم العثماني من"))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
            Link(destination: URL(string: "https://tanzil.net")!) {
                HStack(spacing: 4) {
                    Text(loc("مشروع تنزيل — tanzil.net"))
                        .font(Theme.display(12, weight: .medium))
                    Image(systemName: "arrow.up.forward").font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(Theme.accent)
            }
            Text(loc("مُدقَّق على مصحف المدينة · يُنقل كما هو دون تغيير"))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 4)
    }

    /// علامة «وقفتُ هنا» التي وضعها القارئ بيده.
    @ViewBuilder
    private var stopMarkCard: some View {
        if let mark = store.stopMark, let su = Quran.surah(mark.surah) {
            NavigationLink { SurahReaderView(surahId: mark.surah, scrollTo: mark) } label: {
                AtharCard(padding: 16, elevation: .e2, tint: Theme.accent(for: "gold")) {
                    HStack(spacing: 14) {
                        IconChip(icon: "pin.fill", tint: Theme.gold, size: .lg)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(loc("myStop"))
                                .font(Theme.display(12, weight: .semibold))
                                .foregroundStyle(Theme.gold)
                            Text(loc("سورة %1$@ · آية %2$@ · ص %3$@", su.name, mark.ayah.counterText, Quran.page(of: mark).counterText))
                                .font(Theme.display(16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
            .pressable()
        }
    }

    // MARK: متابعة القراءة

    @ViewBuilder
    private var continueCard: some View {
        if let last = store.lastRead, let s = Quran.surah(last.surah) {
            NavigationLink { SurahReaderView(surahId: last.surah, scrollTo: last) } label: {
                AtharCard(padding: 16, elevation: .e2, tint: Theme.accent) {
                    HStack(spacing: 14) {
                        IconChip(icon: "book.pages.fill", size: .lg)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(loc("continueReading"))
                                .font(Theme.display(12, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                            Text(loc("سورة %1$@ · ص %2$@ · الجزء %3$@", s.name, Quran.page(of: last).counterText, Quran.juz(of: last).counterText))
                                .font(Theme.display(16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
            .pressable()
        }
    }

    // MARK: دعاء الختمة

    /// بابٌ ظاهر لا يُشترط لبلوغه ختمة: كثيرٌ ممّن يختم لا يمرّ بتحدّي الختمة أصلًا،
    /// ومن أراد الدعاء في غير ختمته وجده. والصفحة نفسها تُفتح من خاتمة الناس في القارئ.
    private var khatmahDuaCard: some View {
        NavigationLink { KhatmahDuaView() } label: {
            AtharCard(padding: 14, elevation: .e1, tint: Theme.gold) {
                HStack(spacing: 13) {
                    IconChip(icon: "hands.sparkles.fill", tint: Theme.gold, size: .md)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loc("دعاء الختمة"))
                            .font(Theme.display(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(loc("مواضع الدعاء في القرآن — تدعو بها إذا ختمت"))
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    // MARK: الحفظ والختمة والورد

    private var toolsRow: some View {
        // صفّان من بلاطتين لا صفٌّ من أربع: أربعٌ عرضًا تضيق كلّ واحدة عن رقاقتها
        // فينكسر عنوانها على الشاشات الصغيرة. والصفّ والبلاطة كما كانا.
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                NavigationLink { HifzView() } label: {
                    toolTile("brain.head.profile", Theme.accent(for: "sea"), loc("memorize"),
                             hifzSubtitle, badge: !store.dueForReview.isEmpty)
                }
                .pressable()

                NavigationLink { KhatmahView() } label: {
                    toolTile("book.closed.fill", Theme.gold, loc("khatmah"),
                             store.khatmahActive
                                ? "\(Int((Double(store.khatmahPagesDone) / Double(Quran.pageCount) * 100).rounded()).counterText)٪ — اليوم \(store.khatmahDayIndex.counterText)"
                                : loc("startKhatmahSub"),
                             badge: store.khatmahActive && store.khatmahDelta < 0)
                }
                .pressable()
            }
            // تتساوى البلاطات ارتفاعًا وإن التفّ عنوانٌ فرعي على سطرين.
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                NavigationLink { WirdView() } label: {
                    toolTile("sun.horizon.fill", Theme.accent(for: "dawn"), loc("الورد"),
                             wirdSubtitle,
                             badge: store.wirdEnabled && store.wirdDoneToday < store.wirdTarget)
                }
                .pressable()

                NavigationLink { NotesView() } label: {
                    toolTile("square.and.pencil", Theme.accent(for: "dusk"), loc("تدبّراتي"),
                             notesSubtitle, badge: false)
                }
                .pressable()
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// عنوان بلاطة الحفظ: المستحقّ اليوم أولًا، وإلا المحفوظ. يُفرَد ويُثنّى هنا لأن
    /// `ayahCountText` مبنيّ على عدد آيات السورة (٣ فأكثر) ولا يعرف الصفر ولا الواحد.
    private var hifzSubtitle: String {
        let due = store.dueForReview.count
        if due > 0 {
            return due == 1 ? loc("آية للمراجعة اليوم")
                 : due == 2 ? loc("آيتان للمراجعة اليوم")
                 : "\(due.ayahCountText) للمراجعة اليوم"
        }
        switch store.memorizedCount {
        case 0:  return loc("ابدأ بآية")
        case 1:  return loc("آية واحدة محفوظة")
        case 2:  return loc("آيتان محفوظتان")
        default: return "\(store.memorizedCount.ayahCountText) محفوظة"
        }
    }

    /// عنوان بلاطة الورد: ما أُنجز من مقدار اليوم، بتمييز العدد نفسه.
    private var wirdSubtitle: String {
        let done = store.wirdDoneToday, target = store.wirdTarget
        if done >= target { return loc("تمّ ورد اليوم") }
        switch target {
        case 1:  return loc("آية كل يوم")
        case 2:  return done == 0 ? loc("آيتان كل يوم") : loc("واحدة من آيتين")
        default: return done == 0 ? "\(target.ayahCountText) كل يوم"
                                  : "\(done.counterText) من \(target.ayahCountText)"
        }
    }

    /// عنوان بلاطة التدبّرات: كم كتب، بتمييز العدد كما في جارتيها.
    private var notesSubtitle: String {
        let n = store.notes.count
        switch n {
        case 0:      return loc("اكتب ما فُتح لك")
        case 1:      return loc("تدبّر واحد")
        case 2:      return loc("تدبّران")
        case 3...10: return "\(n.counterText) تدبّرات"
        default:     return "\(n.counterText) تدبّرًا"
        }
    }

    private func toolTile(_ icon: String, _ tint: Color, _ title: String, _ sub: String, badge: Bool) -> some View {
        AtharCard(padding: 14, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    IconChip(icon: icon, tint: tint, size: .md)
                    Spacer()
                    if badge {
                        Circle().fill(tint).frame(width: 8, height: 8)
                    }
                }
                Text(title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(sub)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: العلامات

    private var bookmarksCard: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("علاماتي"))
            SettingsCard {
                // العلامات محفوظة بترتيب المصحف، فالخمسةُ الأولى هي أوائله دائمًا — ومن
                // علّم في جزء عمّ لم يرَ علامته قط ولا خبرَ بأنّ ثمّة غيرها.
                ForEach(Array(store.bookmarks.prefix(5).enumerated()), id: \.element) { i, ref in
                    NavigationLink { SurahReaderView(surahId: ref.surah, scrollTo: ref) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.gold)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(Quran.surah(ref.surah)?.name ?? "") · \(ref.ayah.counterText)")
                                    .font(Theme.display(15))
                                    .foregroundStyle(Theme.ink)
                                Text(Quran.text(ref)?.prefix(46).appending("…") ?? "")
                                    .font(Theme.dhikrFont(size: 13))
                                    .foregroundStyle(Theme.inkFaint)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    // صفٌّ داخل بطاقة مقسومة: لا ينكمش وحده بين جيرانه.
                    .buttonStyle(.plain)
                    if i < min(4, store.bookmarks.count - 1) { SettingsDivider() }
                }
            }
        }
    }
}

// MARK: - صف السورة

struct SurahRow: View {
    let surah: Surah
    // يُقرأ لون الطابع هنا (لا داخل النجمة) ليتبدّل الصف مع الثيم فورًا.
    var accent: Color = Theme.accent

    /// «مكية · 7 آيات» بالترتيب نفسه الذي يظهر في صفّ التلاوة: يُمرَّر String لا
    /// LocalizedStringKey (فذاك يفكّك الأجزاء المُدخَلة ويقلب ترتيبها)، وعلامة RLM
    /// تثبّت اتجاه القراءة مهما كان مسار Text.
    private var meta: String { "\u{200F}\(surah.revelation) · \(surah.ayahCount.ayahCountText)" }

    var body: some View {
        AtharCard(padding: 14) {
            HStack(spacing: 14) {
                SurahMedallion(number: surah.id, size: 46, tint: accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("سورة %1$@", surah.name))
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(meta)
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                }

                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.gold.opacity(0.5))
            }
        }
    }
}

struct SearchHitRow: View {
    let ref: AyahRef
    let query: String
    // كـSurahRow: يُمرَّر لون الطابع قيمةً ليُعاد رسم الصف فور تبديل الثيم.
    var accent: Color = Theme.accent

    var body: some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Quran.surah(ref.surah)?.name ?? "") · \(ref.ayah.counterText)")
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(accent)
                Text(Quran.text(ref) ?? "")
                    .font(Theme.dhikrFont(size: 17))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(8)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

