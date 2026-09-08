import Foundation

// MARK: - ما كان من الأذكار قرآنًا
//
// في الأذكار ما هو قرآن: آية الكرسي، والمعوّذات، وخواتيم البقرة… وكان التطبيق
// يقرؤها بصوتٍ مركَّب كما يقرأ سائر الأذكار، والقرآن يُتلى ولا يُصطنع — فصوتُ
// الآلة فيه نشازٌ يُنفّر السامع قبل أن يُخلّ بالحرمة.
//
// وهذا الجدول مستخرَجٌ من عزو `adhkar.json` نفسه (حقل reference) لا من ذاكرة أحد:
// «سورة البقرة: ٢٥٥» تصير موضعًا، و«سورة الإخلاص» تصير السورة كاملة. فإن صُحّح
// عزوٌ في الدليل صُحّح معه هذا الجدول بإعادة الاستخراج.
struct AyahRange {
    let surah: Int
    let from: Int
    let to: Int

    var refs: [AyahRef] { (from...to).map { AyahRef(surah: surah, ayah: $0) } }
    var first: AyahRef { AyahRef(surah: surah, ayah: from) }
    var last: AyahRef { AyahRef(surah: surah, ayah: to) }
}

enum DhikrRecitation {
    /// المفتاح «قسم/ذكر» — مركّبٌ لأن معرّف الذكر لا يُعرف إلا بقسمه.
    static let quranic: [String: AyahRange] = [
        "distress/d02": AyahRange(surah: 21, from: 87, to: 87),
        "distress/d04": AyahRange(surah: 3, from: 173, to: 173),
        "evening/e01": AyahRange(surah: 2, from: 255, to: 255),
        "evening/e02": AyahRange(surah: 112, from: 1, to: 4),
        "evening/e03": AyahRange(surah: 113, from: 1, to: 5),
        "evening/e04": AyahRange(surah: 114, from: 1, to: 6),
        "morning/m01": AyahRange(surah: 2, from: 255, to: 255),
        "morning/m02": AyahRange(surah: 112, from: 1, to: 4),
        "morning/m03": AyahRange(surah: 113, from: 1, to: 5),
        "morning/m04": AyahRange(surah: 114, from: 1, to: 6),
        "prayer/p09": AyahRange(surah: 2, from: 255, to: 255),
        "sleep/s11": AyahRange(surah: 2, from: 285, to: 286),
        "waking/w04": AyahRange(surah: 3, from: 190, to: 191),
    ]

    static func range(category: String, dhikr: String) -> AyahRange? {
        quranic[category + "/" + dhikr]
    }
}
