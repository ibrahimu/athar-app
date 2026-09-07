import AppIntents

// MARK: - تخصيص ودجة «ذِكر»
//
// لكلٍّ بابٌ يلزمه: هذا مسافر، وهذا مكروب، وهذا يُصبح ويُمسي.
// فتُترك الودجة على حالها لمن رضي، وتُقصر على بابه لمن اختار.

/// باب الأذكار الذي تعرضه الودجة. القيم الخام معرّفات `adhkar.json` نفسها، فالنصّ
/// المعروض في الودجة يبقى مقروءًا من الدليل بالمعرّف. أمّا عناوين الأبواب هنا فمكتوبةٌ
/// حرفًا: `AppIntents` يستخرج قائمة الخيارات وقت الترجمة لتظهر في محرّر الودجة قبل أن
/// يعمل التطبيق، فلا يقبل عنوانًا يُقرأ من ملفٍ وقت التشغيل. (وهي أسماء أبواب لا نصّ
/// شرعيّ؛ إن تبدّل اسمٌ في الدليل فليُبدَّل هنا معه.)
enum DhikrSectionChoice: String, AppEnum {
    /// ما يسوقه الوقت من كل الأبواب — سيرة الودجة قبل هذا الاختيار، وتبقى الأصل.
    case auto
    case morning, evening, sleep, waking, prayer, distress, istighfar, salawat, tasbih, daily, travel

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "باب الأذكار" }

    static var caseDisplayRepresentations: [DhikrSectionChoice: DisplayRepresentation] = [
        .auto:      DisplayRepresentation(title: "يتبع الوقت",
                                          subtitle: "ذكر يتبدّل مع مضيّ اليوم من الأبواب كلّها",
                                          image: .init(systemName: "clock")),
        .morning:   DisplayRepresentation(title: "أذكار الصباح", image: .init(systemName: "sunrise.fill")),
        .evening:   DisplayRepresentation(title: "أذكار المساء", image: .init(systemName: "moon.stars.fill")),
        .sleep:     DisplayRepresentation(title: "أذكار النوم", image: .init(systemName: "bed.double.fill")),
        .waking:    DisplayRepresentation(title: "أذكار الاستيقاظ", image: .init(systemName: "sun.horizon.fill")),
        .prayer:    DisplayRepresentation(title: "أذكار بعد الصلاة", image: .init(systemName: "hands.and.sparkles.fill")),
        .distress:  DisplayRepresentation(title: "أذكار الهم والكرب", image: .init(systemName: "heart.circle.fill")),
        .istighfar: DisplayRepresentation(title: "الاستغفار والتوبة", image: .init(systemName: "drop.fill")),
        .salawat:   DisplayRepresentation(title: "الصلاة على النبي ﷺ", image: .init(systemName: "star.circle.fill")),
        .tasbih:    DisplayRepresentation(title: "الباقيات الصالحات", image: .init(systemName: "sparkles")),
        .daily:     DisplayRepresentation(title: "أذكار اليوم والليلة", image: .init(systemName: "house.fill")),
        .travel:    DisplayRepresentation(title: "أذكار السفر", image: .init(systemName: "airplane")),
    ]

    /// الباب المختار من المكتبة — ولا باب في «يتبع الوقت».
    var category: DhikrCategory? {
        self == .auto ? nil : AdhkarLibrary.category(id: rawValue)
    }
}

/// إعداد ودجة «ذِكر». للمُعامل قيمة افتراضية لأن الودجات الموضوعة قبل هذا الإصدار
/// تصل بلا إعداد محفوظ، فتقع على «يتبع الوقت» وتبقى كما عهدها صاحبها.
struct DhikrWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "ذِكر" }
    static var description: IntentDescription { IntentDescription("اختر باب الأذكار الذي تعرضه الودجة.") }

    @Parameter(title: "القسم", default: .auto)
    var section: DhikrSectionChoice

    static var parameterSummary: some ParameterSummary {
        Summary("اعرض من \(\.$section)")
    }
}
