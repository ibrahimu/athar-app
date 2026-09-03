import AppIntents
import Foundation

// MARK: - طلبات «سيري» والاختصارات

/// «ابدأ التسبيح»: يفتح التطبيق على المسبحة. الاختيار الفعلي للتبويب يقع في RootView
/// عبر `pendingTab`، لأن الطلب قد يصل قبل أن يُرسم الجذر عند الإقلاع البارد.
struct StartTasbihIntent: AppIntent {
    static var title: LocalizedStringResource { "ابدأ التسبيح" }
    static var description: IntentDescription { IntentDescription("يفتح المسبحة لتبدأ عدّك.") }
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        AtharStore.shared.pendingTab = .tasbih
        return .result()
    }
}

/// «كم باقي للصلاة»: يجيب «سيري» بلا فتح التطبيق — الحساب فلكي محلي فلا يحتاج شبكة.
struct NextPrayerIntent: AppIntent {
    static var title: LocalizedStringResource { "كم باقي للصلاة" }
    static var description: IntentDescription { IntentDescription("يخبرك بالصلاة القادمة والوقت المتبقي لها.") }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let phrase = AtharStore.shared.nextPrayerPhrase()
            ?? loc("تعذّر حساب موعد الصلاة القادمة لهذا الموقع.")
        return .result(dialog: IntentDialog(stringLiteral: phrase))
    }
}

/// أقسام التطبيق التي يمكن فتحها بالصوت — القيم الخام تطابق `AppTab` ليكون التحويل مباشرًا.
enum SectionChoice: String, AppEnum {
    case mushaf, adhkar, prayer, tasbih, hajj, qibla, hifz, recitation,
         khatmah, wird, hadith, names, ahkam, prayerLog, calendar, zakat

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "القسم" }

    static var caseDisplayRepresentations: [SectionChoice: DisplayRepresentation] {
        [
            .mushaf:     "المصحف",
            .adhkar:     "الأذكار",
            .prayer:     "الصلاة",
            .tasbih:     "المسبحة",
            .hajj:       "الحج والعمرة",
            .qibla:      "القبلة",
            .hifz:       "الحفظ",
            .recitation: "التلاوة",
            .khatmah:    "الختمة",
            .wird:       "الورد",
            .hadith:     "الحديث",
            .names:      "الأسماء الحسنى",
            .ahkam:      "الأحكام",
            .prayerLog:  "سجل الصلاة",
            .calendar:   "التقويم",
            .zakat:      "الزكاة"
        ]
    }

    var tab: AppTab { AppTab(rawValue: rawValue) ?? .home }
}

/// «افتح المصحف في أثر»: يفتح التطبيق على القسم المطلوب — في الشريط إن كان فيه،
/// وإلا كغطاء كامل بزرّ إغلاق (يتولّاه RootView).
struct OpenSectionIntent: AppIntent {
    static var title: LocalizedStringResource { "افتح قسمًا" }
    static var description: IntentDescription { IntentDescription("يفتح أحد أقسام أثر مباشرة.") }
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "القسم")
    var section: SectionChoice

    static var parameterSummary: some ParameterSummary {
        Summary("افتح \(\.$section)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AtharStore.shared.pendingTab = section.tab
        return .result()
    }
}

/// العبارات التي يفهمها «سيري» دون إعداد من المستخدم. كل عبارة تحمل اسم التطبيق
/// (شرط النظام)، وعبارة القسم تتوسّع تلقائيًا لكل حالة في `SectionChoice`.
struct AtharShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTasbihIntent(),
            phrases: [
                "ابدأ التسبيح في \(.applicationName)",
                "افتح المسبحة في \(.applicationName)",
                "سبّح في \(.applicationName)"
            ],
            shortTitle: "التسبيح",
            systemImageName: "circle.hexagongrid.fill"
        )
        AppShortcut(
            intent: NextPrayerIntent(),
            phrases: [
                "كم باقي للصلاة في \(.applicationName)",
                "متى الصلاة القادمة في \(.applicationName)",
                "الصلاة القادمة في \(.applicationName)"
            ],
            shortTitle: "الصلاة القادمة",
            systemImageName: "moon.stars.fill"
        )
        AppShortcut(
            intent: OpenSectionIntent(),
            phrases: [
                "افتح \(\.$section) في \(.applicationName)",
                "اذهب إلى \(\.$section) في \(.applicationName)"
            ],
            shortTitle: "افتح قسمًا",
            systemImageName: "square.grid.2x2.fill"
        )
    }
}
