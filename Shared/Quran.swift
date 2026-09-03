import Foundation

// MARK: - النماذج

struct Surah: Codable, Identifiable, Hashable {
    let id: Int
    let name: String            // الاسم العربي: "الفاتحة"
    let nameSimple: String      // "Al-Fatihah"
    let ayahCount: Int
    let revelation: String      // "مكية" أو "مدنية"
    let hasBasmalah: Bool
    let verses: [String]

    /// آية بترقيمها المألوف (١ فأعلى).
    func verse(_ number: Int) -> String? {
        guard number >= 1, number <= verses.count else { return nil }
        return verses[number - 1]
    }

    var isMakki: Bool { revelation == "مكية" }
}

/// مرجع آية: سورة ورقم.
struct AyahRef: Codable, Hashable, Identifiable, Comparable {
    let surah: Int
    let ayah: Int

    var id: String { "\(surah):\(ayah)" }
    var display: String { "\(surah.counterText):\(ayah.counterText)" }

    static func < (a: AyahRef, b: AyahRef) -> Bool {
        a.surah != b.surah ? a.surah < b.surah : a.ayah < b.ayah
    }
}

private struct QuranFile: Codable {
    struct Meta: Codable {
        let script: String
        let source: String
        let basmalah: String
    }
    let meta: Meta
    let sajdahPositions: [[Int]]?
    let surahs: [Surah]
}

// MARK: - المكتبة

enum Quran {
    static let surahs: [Surah] = file?.surahs ?? []
    static let basmalah: String = file?.meta.basmalah ?? "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
    static let source: String = file?.meta.source ?? ""

    static let totalAyahs = 6236

    /// مواضع سجود التلاوة الخمسة عشر.
    static let sajdahPositions: Set<AyahRef> = {
        Set((file?.sajdahPositions ?? []).compactMap {
            $0.count == 2 ? AyahRef(surah: $0[0], ayah: $0[1]) : nil
        })
    }()

    static func isSajdah(_ ref: AyahRef) -> Bool { sajdahPositions.contains(ref) }

    // MARK: صفحات مصحف المدينة وأجزاؤه

    /// بيانات مواضع بدايات الصفحات (٦٠٤) والأجزاء (٣٠) — من تنزيل، متحقَّق منها
    /// على مراسٍ معلومة (آل عمران تبدأ ص٥٠، الجزء ٣٠ يبدأ بالنبأ...).
    private struct MetaFile: Codable { let pageStarts: [[Int]]; let juzStarts: [[Int]] }
    private static let metaFile: MetaFile? = {
        for b in [Bundle.main] + Bundle.allBundles {
            if let u = b.url(forResource: "quran_meta", withExtension: "json"),
               let d = try? Data(contentsOf: u),
               let f = try? JSONDecoder().decode(MetaFile.self, from: d) { return f }
        }
        return nil
    }()

    static let pageCount = 604

    /// رقم صفحة الآية في مصحف المدينة (١ إلى ٦٠٤).
    static func page(of ref: AyahRef) -> Int {
        position(of: ref, in: metaFile?.pageStarts ?? [[1, 1]])
    }

    /// رقم جزء الآية (١ إلى ٣٠).
    static func juz(of ref: AyahRef) -> Int {
        position(of: ref, in: metaFile?.juzStarts ?? [[1, 1]])
    }

    /// أول آية في صفحة معيّنة — للانتقال إلى موضع ورد الختمة.
    static func firstAyah(ofPage page: Int) -> AyahRef {
        let starts = metaFile?.pageStarts ?? [[1, 1]]
        let i = min(max(page, 1), starts.count) - 1
        guard starts.indices.contains(i), starts[i].count >= 2 else { return AyahRef(surah: 1, ayah: 1) }
        return AyahRef(surah: starts[i][0], ayah: starts[i][1])
    }

    /// كل آيات صفحة معيّنة من مصحف المدينة.
    static func ayahs(inPage page: Int) -> [AyahRef] {
        let from = firstAyah(ofPage: page)
        let to: AyahRef
        if page < pageCount {
            guard let prev = previous(before: firstAyah(ofPage: page + 1)) else { return [from] }
            to = prev
        } else {
            to = AyahRef(surah: 114, ayah: 6)
        }
        return range(from: from, to: to)
    }

    private static func position(of ref: AyahRef, in starts: [[Int]]) -> Int {
        var result = 1
        for (i, st) in starts.enumerated() {
            guard st.count >= 2 else { continue }   // حراسة: مدخلة سليمة [سورة، آية]
            let s = AyahRef(surah: st[0], ayah: st[1])
            if s <= ref { result = i + 1 } else { break }
        }
        return result
    }

    static func surah(_ id: Int) -> Surah? {
        guard id >= 1, id <= surahs.count else { return nil }
        return surahs[id - 1]
    }

    static func text(_ ref: AyahRef) -> String? {
        surah(ref.surah)?.verse(ref.ayah)
    }

    /// الآية التالية عبر حدود السور، أو nil عند خاتمة الناس.
    static func next(after ref: AyahRef) -> AyahRef? {
        guard let s = surah(ref.surah) else { return nil }
        if ref.ayah < s.ayahCount { return AyahRef(surah: ref.surah, ayah: ref.ayah + 1) }
        guard ref.surah < surahs.count else { return nil }
        return AyahRef(surah: ref.surah + 1, ayah: 1)
    }

    static func previous(before ref: AyahRef) -> AyahRef? {
        if ref.ayah > 1 { return AyahRef(surah: ref.surah, ayah: ref.ayah - 1) }
        guard ref.surah > 1, let prev = surah(ref.surah - 1) else { return nil }
        return AyahRef(surah: ref.surah - 1, ayah: prev.ayahCount)
    }

    /// كل الآيات بين مرجعين، شاملةً الطرفين.
    static func range(from: AyahRef, to: AyahRef) -> [AyahRef] {
        guard from <= to else { return [] }
        var out: [AyahRef] = []
        var cur: AyahRef? = from
        while let c = cur, c <= to {
            out.append(c)
            cur = next(after: c)
        }
        return out
    }

    /// بحث في النص بعد تجريد التشكيل، فيجد المستخدم آيته كما يكتبها.
    static func search(_ query: String, limit: Int = 60) -> [AyahRef] {
        let needle = query.strippedForSearch
        guard needle.count >= 2 else { return [] }
        var hits: [AyahRef] = []
        for s in surahs {
            for (i, v) in s.verses.enumerated() {
                if v.strippedForSearch.contains(needle) {
                    hits.append(AyahRef(surah: s.id, ayah: i + 1))
                    if hits.count >= limit { return hits }
                }
            }
        }
        return hits
    }

    private static let file: QuranFile? = {
        let candidates: [Bundle] = [.main] + Bundle.allBundles + Bundle.allFrameworks
        for b in candidates {
            guard let url = b.url(forResource: "quran", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let f = try? JSONDecoder().decode(QuranFile.self, from: data)
            else { continue }
            return f
        }
        assertionFailure("quran.json missing from bundle")
        return nil
    }()
}

// MARK: - تجريد النص للبحث والمقارنة

extension String {
    /// يجرّد التشكيل والتطويل وعلامات الوقف ويوحّد صور الألف والياء،
    /// ليطابق ما يكتبه المستخدم بلوحة مفاتيح عادية.
    var strippedForSearch: String {
        var out = String.UnicodeScalarView()
        for u in unicodeScalars {
            let v = u.value
            if (0x064B...0x065F).contains(v) || v == 0x0670 || v == 0x0640 { continue } // تشكيل + ألف خنجرية + تطويل
            if (0x06D6...0x06ED).contains(v) { continue }                                // علامات وقف وتجويد
            out.append(u)
        }
        return String(out)
            .replacingOccurrences(of: "ءا", with: "ا")
            .replacingOccurrences(of: "ٱ", with: "ا")
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .replacingOccurrences(of: "ة", with: "ه")
            .replacingOccurrences(of: "ؤ", with: "و")
            .replacingOccurrences(of: "ئ", with: "ي")
            .split(separator: " ").joined(separator: " ")
    }

    /// كلمات الآية، لاستخدامها في الحجب التدريجي أثناء الحفظ.
    var ayahWords: [String] {
        split(separator: " ").map(String.init)
    }
}

// MARK: - تمييز العدد

extension Int {
    /// «٣ آيات» لا «٣ آية»: تمييز العدد من ٣ إلى ١٠ جمعٌ مجرور، وما عداه مفرد.
    var ayahCountText: String {
        (3...10).contains(self) ? "\(counterText) آيات" : "\(counterText) آية"
    }
}
