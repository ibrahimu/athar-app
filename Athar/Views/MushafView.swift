import SwiftUI

struct MushafView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var query = ""

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

    private var searchHits: [AyahRef] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 3, filtered.isEmpty || q.count >= 4 else { return [] }
        return Quran.search(q, limit: 25)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if query.isEmpty {
                            stopMarkCard
                            continueCard
                            toolsRow
                            if !store.bookmarks.isEmpty { bookmarksCard }
                            SettingsGroupTitle(text: loc("suras"))
                        }

                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, surah in
                            NavigationLink { SurahReaderView(surahId: surah.id) } label: {
                                SurahRow(surah: surah)
                            }
                            .pressable()
                            .appearStagger(i)
                        }

                        if !searchHits.isEmpty {
                            SettingsGroupTitle(text: loc("آيات مطابقة"))
                            ForEach(searchHits) { ref in
                                NavigationLink { SurahReaderView(surahId: ref.surah, scrollTo: ref) } label: {
                                    SearchHitRow(ref: ref, query: query)
                                }
                                .pressable()
                            }
                        }

                        if query.isEmpty { sourceCredit }

                        if filtered.isEmpty && searchHits.isEmpty && !query.isEmpty {
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
            }
            .navigationTitle(loc("mushaf"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text(loc("searchMushaf")))
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
                AtharCard(padding: 16) {
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
                            Text(loc("سورة \(su.name) · آية \(mark.ayah.counterText) · ص \(Quran.page(of: mark).counterText)"))
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
                AtharCard(padding: 16) {
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
                            Text(loc("سورة \(s.name) · ص \(Quran.page(of: last).counterText) · الجزء \(Quran.juz(of: last).counterText)"))
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
                            ? "\(store.memorizedCount.counterText) آية محفوظة"
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
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(tint)
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

    var body: some View {
        AtharCard(padding: 14) {
            HStack(spacing: 14) {
                SurahMedallion(number: surah.id, size: 46)

                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("سورة \(surah.name)"))
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(surah.revelation) · \(surah.ayahCount.counterText) آية")
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                }

                Spacer()
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
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
