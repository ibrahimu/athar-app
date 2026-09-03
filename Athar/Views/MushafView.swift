import SwiftUI

struct MushafView: View {
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false
    @EnvironmentObject private var store: AtharStore
    @State private var query = ""
    /// نتائج البحث في نصّ المصحف — تُحسب مرّةً واحدة لكل استعلام لا مع كل رسم.
    @State private var hits: [AyahRef] = []

    private var filtered: [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Quran.surahs }
        let n = q.strippedForSearch
        return Quran.surahs.filter {
            $0.name.strippedForSearch.contains(n)
            || $0.nameSimple.lowercased().contains(q.lowercased())
            || String($0.id) == q
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
                            if !store.bookmarks.isEmpty { bookmarksCard }
                            SectionHeader(title: loc("suras"), tint: Theme.accent(for: "gold"))
                                .padding(.top, 2)
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

                        if filtered.isEmpty && hits.isEmpty && !query.isEmpty {
                            ContentUnavailableView(loc("لا توجد نتائج"), systemImage: "magnifyingglass",
                                                   description: Text(loc("جرّب اسم سورة أو جزءًا من آية")))
                                .padding(.top, 50)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                    .readableWidth(620)
                }
                .scrollIndicators(.hidden)
                // البحث يمسح ٦٢٣٦ آية ويجرّد تشكيلها — لو جرى في الخيط الرئيسي
                // مع كل حرف لتقطّعت الكتابة. فيُمهَل ربع ثانية ويُلغى بالحرف
                // التالي، ثم يجري خارج الخيط الرئيسي مرّةً واحدة لكل استعلام.
                .task(id: query) {
                    let q = query.trimmingCharacters(in: .whitespaces)
                    guard q.count >= 3, filtered.isEmpty || q.count >= 4 else {
                        hits = []
                        return
                    }
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
        }
    }

    // MARK: التلاوة

    /// مدخل التلاوة الصوتية: يفتح شاشةً تُشغّل السور بثًّا أو تنزّلها للاستماع بلا إنترنت.
    private var recitationCard: some View {
        let audio = Recitation.shared
        let sum = audio.downloadedSummary(reciter: audio.reciterId)
        return NavigationLink { RecitationView() } label: {
            AtharCard(padding: 14, elevation: .e2, tint: Theme.accent) {
                HStack(spacing: 13) {
                    Image(systemName: "waveform")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.accent.opacity(0.13)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loc("الاستماع للقرآن"))
                            .font(Theme.display(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(sum.count > 0
                             ? loc("%1$@ · %2$@ سورة محمَّلة", audio.reciter.name, sum.count.counterText)
                             : loc("%1$@ · شغّلها أو نزّلها للاستماع بلا إنترنت", audio.reciter.name))
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
                .font(Theme.display(10))
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
                        Image(systemName: "pin.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.gold)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Theme.gold.opacity(0.13)))
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
                        Image(systemName: "book.pages.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Theme.accentSoft))
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

    // MARK: الحفظ والورد

    private var toolsRow: some View {
        HStack(spacing: 12) {
            NavigationLink { HifzView() } label: {
                toolTile("brain.head.profile", Theme.accent(for: "sea"), loc("memorize"),
                         store.dueForReview.isEmpty
                            ? "\(store.memorizedCount.ayahCountText) محفوظة"
                            : "\(store.dueForReview.count.counterText) للمراجعة اليوم",
                         badge: !store.dueForReview.isEmpty)
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
    }

    private func toolTile(_ icon: String, _ tint: Color, _ title: String, _ sub: String, badge: Bool) -> some View {
        AtharCard(padding: 14, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(tint)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(tint.opacity(0.14)))
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: العلامات

    private var bookmarksCard: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("علاماتي"))
            SettingsCard {
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
                    .pressable()
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

    var body: some View {
        AtharCard(padding: 14) {
            HStack(spacing: 14) {
                SurahMedallion(number: surah.id, size: 46, tint: accent)

                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("سورة %1$@", surah.name))
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(surah.revelation) · \(surah.ayahCount.ayahCountText)")
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

    var body: some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Quran.surah(ref.surah)?.name ?? "") · \(ref.ayah.counterText)")
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
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

