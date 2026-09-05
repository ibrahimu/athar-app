import Foundation

// MARK: - السنن الرواتب وغيرها من سنن الصلاة
//
// الشرح بأسلوب التطبيق، والأدلة بلفظها من الصحيحين (نُسخت من مصادرها لا من الذاكرة).
// ما ثبت في غير الصحيحين (كأربعٍ قبل العصر) يُذكر مصدره دون نقلٍ حرفي.

struct SunnahEvidence: Hashable {
    let text: String
    let source: String
}

struct SunnahPrayer: Identifiable, Hashable {
    enum Timing: Hashable {
        case before(Prayer)
        case after(Prayer)
        case other
    }
    enum Emphasis: Hashable {
        case muakkadah      // راتبة مؤكّدة داوم عليها النبي ﷺ
        case mustahabbah    // مستحبّة رغّب فيها

        var title: String { self == .muakkadah ? "مؤكّدة" : "مستحبّة" }
    }

    let id: String
    let title: String
    /// «٢» أو «٢ أو ٤» — نصّ العدد كما يُعرض.
    let rakaat: String
    let timing: Timing
    let emphasis: Emphasis
    let detail: String
    let evidence: [SunnahEvidence]
    let icon: String
}

enum SunanLibrary {
    /// حديث الاثنتي عشرة ركعة — فضل الرواتب كلها.
    static let twelveHadith = SunnahEvidence(
        text: "مَا مِنْ عَبْدٍ مُسْلِمٍ يُصَلِّي لِلَّهِ كُلَّ يَوْمٍ ثِنْتَىْ عَشْرَةَ رَكْعَةً تَطَوُّعًا غَيْرَ فَرِيضَةٍ إِلاَّ بَنَى اللَّهُ لَهُ بَيْتًا فِي الْجَنَّةِ",
        source: "رواه مسلم")

    static let rawatib: [SunnahPrayer] = [
        .init(id: "fajr-before", title: "سنّة الفجر", rakaat: "٢", timing: .before(.fajr), emphasis: .muakkadah,
              detail: "ركعتان خفيفتان قبل الفريضة، ما كان النبي ﷺ على شيء من النوافل أشدّ تعاهدًا منهما، ويُسنّ فيهما قراءة «قل يا أيها الكافرون» و«قل هو الله أحد». ومن فاتته قضاها بعد الفجر أو بعد طلوع الشمس.",
              evidence: [.init(text: "رَكْعَتَا الْفَجْرِ خَيْرٌ مِنَ الدُّنْيَا وَمَا فِيهَا", source: "رواه مسلم")],
              icon: "sunrise.fill"),
        .init(id: "dhuhr-before", title: "سنّة الظهر القبلية", rakaat: "٤", timing: .before(.dhuhr), emphasis: .muakkadah,
              detail: "أربع ركعات قبل الظهر بتسليمتين، ثبتت في رواية الترمذي وغيره عن أم حبيبة رضي الله عنها؛ وفي الصحيحين عن ابن عمر ركعتان، فمن صلّى ركعتين أصاب السنّة، ومن صلّى أربعًا فهو أكمل.",
              evidence: [.init(text: "حَفِظْتُ مِنَ النَّبِيِّ صلى الله عليه وسلم عَشْرَ رَكَعَاتٍ", source: "رواه البخاري — حديث ابن عمر، وفيه ركعتان قبل الظهر وركعتان بعدها وركعتان بعد المغرب وركعتان بعد العشاء وركعتان قبل الصبح")],
              icon: "sun.max.fill"),
        .init(id: "dhuhr-after", title: "سنّة الظهر البعدية", rakaat: "٢", timing: .after(.dhuhr), emphasis: .muakkadah,
              detail: "ركعتان بعد الفريضة، وهما من الرواتب التي داوم عليها النبي ﷺ في الحضر.",
              evidence: [twelveHadith], icon: "sun.max.fill"),
        .init(id: "maghrib-after", title: "سنّة المغرب", rakaat: "٢", timing: .after(.maghrib), emphasis: .muakkadah,
              detail: "ركعتان بعد المغرب، كان النبي ﷺ يصلّيهما في بيته، ويُسنّ فيهما قراءة «الكافرون» و«الإخلاص».",
              evidence: [twelveHadith], icon: "sunset.fill"),
        .init(id: "isha-after", title: "سنّة العشاء", rakaat: "٢", timing: .after(.isha), emphasis: .muakkadah,
              detail: "ركعتان بعد العشاء، ثم ما شاء من قيام الليل، ويختم بالوتر.",
              evidence: [twelveHadith], icon: "moon.stars.fill"),
        .init(id: "asr-before", title: "قبل العصر", rakaat: "٤", timing: .before(.asr), emphasis: .mustahabbah,
              detail: "أربع ركعات قبل العصر بتسليمتين، مستحبّة لا راتبة؛ جاء فيها حديث «رحم الله امرأً صلّى قبل العصر أربعًا» عند أبي داود والترمذي.",
              evidence: [.init(text: "بَيْنَ كُلِّ أَذَانَيْنِ صَلاَةٌ", source: "رواه البخاري — أي بين الأذان والإقامة")],
              icon: "sun.min.fill"),
        .init(id: "maghrib-before", title: "قبل المغرب", rakaat: "٢", timing: .before(.maghrib), emphasis: .mustahabbah,
              detail: "ركعتان بين أذان المغرب وإقامته لمن شاء، وقد أمر بهما النبي ﷺ وقال في الثالثة: «لمن شاء» كراهة أن يتخذها الناس سنّة لازمة.",
              evidence: [.init(text: "صَلُّوا قَبْلَ صَلاَةِ الْمَغْرِبِ", source: "رواه البخاري")],
              icon: "sunset.fill"),
        .init(id: "isha-before", title: "قبل العشاء", rakaat: "٢", timing: .before(.isha), emphasis: .mustahabbah,
              detail: "ركعتان بين الأذان والإقامة، داخلتان في عموم «بين كل أذانين صلاة».",
              evidence: [.init(text: "بَيْنَ كُلِّ أَذَانَيْنِ صَلاَةٌ", source: "رواه البخاري")],
              icon: "moon.stars.fill"),
    ]

    static let others: [SunnahPrayer] = [
        .init(id: "witr", title: "الوتر", rakaat: "١ – ١١", timing: .other, emphasis: .muakkadah,
              detail: "آكد النوافل بعد الرواتب، وقته من بعد العشاء إلى طلوع الفجر، وآخر الليل أفضل لمن وثق بقيامه. أقلّه ركعة، وأكثر ما ثبت إحدى عشرة، يُصلّي مثنى مثنى ثم يوتر بواحدة. ويُسنّ فيه دعاء القنوت.",
              evidence: [.init(text: "اجْعَلُوا آخِرَ صَلاَتِكُمْ بِاللَّيْلِ وِتْرًا", source: "رواه البخاري"),
                         .init(text: "صَلاَةُ اللَّيْلِ مَثْنَى مَثْنَى", source: "رواه البخاري")],
              icon: "moon.fill"),
        .init(id: "duha", title: "صلاة الضحى", rakaat: "٢ – ٨", timing: .other, emphasis: .mustahabbah,
              detail: "من ارتفاع الشمس قِيد رمح إلى قبيل الزوال، وأفضلها حين يشتدّ الحرّ. أقلّها ركعتان، وتُجزئ عن صدقة مفاصل البدن كلّها في ذلك اليوم.",
              evidence: [.init(text: "يُصْبِحُ عَلَى كُلِّ سُلاَمَى مِنْ أَحَدِكُمْ صَدَقَةٌ", source: "رواه مسلم"),
                         .init(text: "وَيُجْزِئُ مِنْ ذَلِكَ رَكْعَتَانِ يَرْكَعُهُمَا مِنَ الضُّحَى", source: "رواه مسلم")],
              icon: "sun.haze.fill"),
        .init(id: "tahiyyah", title: "تحيّة المسجد", rakaat: "٢", timing: .other, emphasis: .mustahabbah,
              detail: "ركعتان لمن دخل المسجد قبل أن يجلس، في أي وقت دخل، وتُجزئ عنهما الفريضة أو الراتبة إن صلّاها فور دخوله.",
              evidence: [.init(text: "إِذَا دَخَلَ أَحَدُكُمُ الْمَسْجِدَ فَلاَ يَجْلِسْ حَتَّى يُصَلِّيَ رَكْعَتَيْنِ", source: "رواه البخاري")],
              icon: "building.columns.fill"),
        .init(id: "wudu", title: "سنّة الوضوء", rakaat: "٢", timing: .other, emphasis: .mustahabbah,
              detail: "ركعتان بعد الوضوء يُقبل فيهما بقلبه على الله؛ جاء في تمام الحديث أن من صلّاهما لا يحدّث فيهما نفسه غُفر له ما تقدّم من ذنبه.",
              evidence: [.init(text: "مَنْ تَوَضَّأَ نَحْوَ وُضُوئِي هَذَا ثُمَّ صَلَّى رَكْعَتَيْنِ", source: "رواه البخاري — حديث عثمان رضي الله عنه")],
              icon: "drop.fill"),
    ]

    static func before(_ p: Prayer) -> [SunnahPrayer] { rawatib.filter { $0.timing == .before(p) } }
    static func after(_ p: Prayer) -> [SunnahPrayer] { rawatib.filter { $0.timing == .after(p) } }

    /// عدد ركعات الرواتب المؤكّدة في اليوم — اثنتا عشرة على رواية الأربع قبل الظهر.
    static let muakkadahCount = 12

    static let note = "الرواتب المؤكّدة اثنتا عشرة ركعة كما في حديث أم حبيبة عند مسلم وتفصيله عند الترمذي؛ وما سواها مستحبّ رُغِّب فيه. والنصوص المنقولة بلفظها من الصحيحين، وما ليس فيهما ذُكر مصدره دون نقل."
}
