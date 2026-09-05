import Foundation

// MARK: - التفسير

/// كتابا التفسير المضمَّنان — كلاهما تراث عام ومن أهل السنّة:
/// السعدي للمعنى العام الميسّر، والجلالين للبيان الموجز لمعاني الكلمات.
enum TafsirEdition: String, CaseIterable, Identifiable {
    case saadi, jalalayn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .saadi:    return loc("تفسير السعدي")
        case .jalalayn: return loc("الجلالين")
        }
    }

    var fullTitle: String {
        switch self {
        case .saadi:    return "تيسير الكريم الرحمن في تفسير كلام المنّان"
        case .jalalayn: return "تفسير الجلالين"
        }
    }

    var author: String {
        switch self {
        case .saadi:    return "الشيخ عبد الرحمن بن ناصر السعدي (ت 1376هـ)"
        case .jalalayn: return "جلال الدين المحلّي (ت 864هـ) وجلال الدين السيوطي (ت 911هـ)"
        }
    }

    var subtitle: String {
        switch self {
        case .saadi:    return loc("شرح ميسّر للمعنى العام")
        case .jalalayn: return loc("بيان موجز لمعاني الكلمات")
        }
    }

    /// أقواس الاستشهاد بالآية داخل النص — تُبرَز عند العرض.
    var quoteMarks: (open: Character, close: Character) {
        switch self {
        case .saadi:    return ("{", "}")
        case .jalalayn: return ("﴿", "﴾")
        }
    }

    fileprivate var filePrefix: String { rawValue }
}

/// نصّ تفسير آية. حين يشرح المفسّر آيات مجتمعةً يُحال كل آية على أوّلها،
/// فيُعرض النص مرة واحدة مع بيان مداه (الآيات 4–7).
struct TafsirEntry: Hashable {
    let edition: TafsirEdition
    let ref: AyahRef
    /// أول آية يغطّيها النص وآخرها (تساويان ref.ayah حين يُفرد للآية نصّها).
    let coversFrom: Int
    let coversTo: Int
    let text: String

    var coversRange: Bool { coversFrom != coversTo }

    /// «الآية 5» أو «الآيات 4–7».
    var rangeTitle: String {
        coversRange
            ? loc("الآيات %1$@–%2$@", coversFrom.counterText, coversTo.counterText)
            : loc("الآية %1$@", ref.ayah.counterText)
    }
}

enum Tafsir {
    private struct SurahFile: Decodable { let surah: Int; let ayahs: [String: String] }

    private static var cache: [String: [String: String]] = [:]
    private static let lock = NSLock()

    /// خريطة آيات السورة (رقم → نص أو «@رقم» إحالة) — تُقرأ من الحزمة عند أول طلب وتُحفظ.
    private static func map(_ edition: TafsirEdition, surah: Int) -> [String: String]? {
        let key = "\(edition.rawValue)-\(surah)"
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[key] { return cached }
        let name = String(format: "%@_%03d", edition.filePrefix, surah)
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SurahFile.self, from: data) else { return nil }
        // الذاكرة: نُبقي أربع سور فقط (المصحف يتنقّل بين سورتين متجاورتين غالبًا).
        if cache.count >= 4, let first = cache.keys.first { cache.removeValue(forKey: first) }
        cache[key] = file.ayahs
        return file.ayahs
    }

    static func isAvailable(_ edition: TafsirEdition) -> Bool {
        Bundle.main.url(forResource: "\(edition.filePrefix)_001", withExtension: "json") != nil
    }

    static func entry(_ edition: TafsirEdition, for ref: AyahRef) -> TafsirEntry? {
        guard let m = map(edition, surah: ref.surah) else { return nil }
        // حلّ الإحالات «@n» — مع حدٍّ للدوران احتياطًا.
        var from = ref.ayah
        var text = m[String(from)] ?? ""
        var hops = 0
        while text.hasPrefix("@"), hops < 20 {
            guard let n = Int(text.dropFirst()) else { break }
            from = n
            text = m[String(n)] ?? ""
            hops += 1
        }
        guard !text.isEmpty, !text.hasPrefix("@") else { return nil }
        // مدى النص: آخر آية تُحيل على «from».
        var to = from
        let count = Quran.surah(ref.surah)?.ayahCount ?? ref.ayah
        var a = from + 1
        while a <= count, m[String(a)] == "@\(from)" { to = a; a += 1 }
        return TafsirEntry(edition: edition, ref: ref, coversFrom: from, coversTo: to, text: text)
    }
}
