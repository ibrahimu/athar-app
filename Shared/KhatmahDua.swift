import Foundation

/// دعاء ختم القرآن.
///
/// لم يثبت عن النبي ﷺ دعاءٌ بلفظٍ معيّن يُقال عند ختم القرآن، والمشهور المطبوع في
/// أواخر المصاحف لا يصحّ رفعُه إليه. فلا يُكتب هنا دعاءٌ يُنسب إلى ما لم يقله، ولا
/// يُنقل نصٌّ من خارج بيانات التطبيق.
///
/// وما يُعرض بدلًا منه هو دعاءُ القرآن نفسِه: مواضعُ الدعاء في المصحف تُحلّ من
/// `quran.json` بمعرّفاتها (سورة وآية)، فلا حرفَ فيها من عندنا، ولا عزوَ يُخشى عليه.
/// من ختم فليدعُ بها، وليَدعُ بعدها بما شاء من خير.
struct KhatmahDua: Identifiable, Hashable {
    /// أوّل آيةٍ في الدعاء وآخرها — أكثرها آيةٌ واحدة، وبعضها آيتان متّصلتان.
    let from: AyahRef
    let to: AyahRef
    /// عمّا يُدعى به هنا — كلمةٌ من عندنا تُبوّب، لا تُنسب ولا تُتلى.
    let theme: String

    var id: String { from.id }

    var refs: [AyahRef] {
        guard from.surah == to.surah else { return [from] }
        return (from.ayah...max(from.ayah, to.ayah)).map { AyahRef(surah: from.surah, ayah: $0) }
    }

    /// نصّ الدعاء كما في المصحف — يُجمع من الآيات بمعرّفاتها لا يُكتب.
    var text: String {
        refs.compactMap { Quran.text($0) }.joined(separator: " ")
    }

    /// «سورة البقرة: ٢٠١» أو «سورة إبراهيم: ٤٠–٤١».
    var source: String {
        let name = Quran.surah(from.surah)?.name ?? ""
        let numbers = from.ayah == to.ayah
            ? from.ayah.counterText
            : "\(from.ayah.counterText)–\(to.ayah.counterText)"
        return "سورة \(name): \(numbers)"
    }

    private init(_ surah: Int, _ from: Int, _ to: Int? = nil, _ theme: String) {
        self.from = AyahRef(surah: surah, ayah: from)
        self.to = AyahRef(surah: surah, ayah: to ?? from)
        self.theme = theme
    }

    /// مواضعُ الدعاء المختارة، على ترتيب المصحف. تُؤثَر منها ما غلب عليه الدعاء نفسُه،
    /// لأن الآية تُعرض تامّةً ولا يُقتطع منها موضعُ الدعاء وحده.
    static let all: [KhatmahDua] = [
        KhatmahDua(2, 201, nil, "حسنة الدارين"),
        KhatmahDua(2, 286, nil, "خواتيم البقرة"),
        KhatmahDua(3, 8, nil, "ثبات القلب"),
        KhatmahDua(3, 193, 194, "المغفرة وإنجاز الوعد"),
        KhatmahDua(14, 40, 41, "الصلاة والمغفرة للوالدين"),
        KhatmahDua(17, 80, nil, "صدق المدخل والمخرج"),
        KhatmahDua(20, 114, nil, "الزيادة من العلم"),
        KhatmahDua(23, 118, nil, "المغفرة والرحمة"),
        KhatmahDua(25, 74, nil, "قرّة العين"),
        KhatmahDua(60, 5, nil, "ألّا نكون فتنة"),
    ]
}
