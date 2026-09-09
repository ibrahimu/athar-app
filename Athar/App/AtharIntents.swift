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

/// الصلوات الخمس وحدها تُسجَّل — الشروق ليس صلاة. القيم الخام تطابق `Prayer`
/// ليكون التحويل مباشرًا بلا جدولٍ ثانٍ يفترق عنه.
enum PrayerChoice: String, AppEnum {
    case fajr, dhuhr, asr, maghrib, isha

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "الصلاة" }

    static var caseDisplayRepresentations: [PrayerChoice: DisplayRepresentation] {
        [
            .fajr:    "الفجر",
            .dhuhr:   "الظهر",
            .asr:     "العصر",
            .maghrib: "المغرب",
            .isha:    "العشاء"
        ]
    }

    var prayer: Prayer { Prayer(rawValue: rawValue) ?? .fajr }
}

/// «سجّل صلاة العصر»: يكتب في سجل اليوم بلا فتح التطبيق — من صلّى ثم أراد أن
/// يقيّدها لا يُقطع عليه ما هو فيه، كزرّ بطاقة الأذان سواء.
struct LogPrayerIntent: AppIntent {
    static var title: LocalizedStringResource { "سجّل صلاة" }
    static var description: IntentDescription { IntentDescription("يسجّل صلاةً في وقتها في سجل اليوم.") }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "الصلاة")
    var prayer: PrayerChoice

    static var parameterSummary: some ParameterSummary {
        Summary("سجّل \(\.$prayer)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let p = prayer.prayer
        AtharStore.shared.setPrayerStatus(.onTime, for: p, on: Date())
        return .result(dialog: IntentDialog(stringLiteral: loc("سُجّلت %1$@ في وقتها — تقبّل الله.", p.title)))
    }
}

/// «أين ختمتي»: يجيب «سيري» بلا فتح التطبيق — الجواب من التخزين المحلي وحده.
struct KhatmahPositionIntent: AppIntent {
    static var title: LocalizedStringResource { "أين ختمتي" }
    static var description: IntentDescription { IntentDescription("يخبرك أين بلغت في ختمتك: السورة والصفحة والنسبة.") }
    static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: IntentDialog(stringLiteral: AtharStore.shared.khatmahPositionPhrase()))
    }
}

/// أقسام التطبيق التي يمكن فتحها بالصوت — القيم الخام تطابق `AppTab` ليكون التحويل مباشرًا.
enum SectionChoice: String, AppEnum {
    case mushaf, adhkar, prayer, live, radio, tasbih, hajj, qibla, hifz, recitation,
         khatmah, wird, hadith, phrases, names, ahkam, prayerLog, calendar, zakat, wallet, sunan, friday

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "القسم" }

    static var caseDisplayRepresentations: [SectionChoice: DisplayRepresentation] {
        [
            .friday:     "يوم الجمعة",
            .mushaf:     "المصحف",
            .adhkar:     "الأذكار",
            .prayer:     "الصلاة",
            .live:       "البث المباشر",
            .radio:      "إذاعة القرآن",
            .tasbih:     "المسبحة",
            .hajj:       "الحج والعمرة",
            .qibla:      "القبلة",
            .hifz:       "الحفظ",
            .recitation: "التلاوة",
            .khatmah:    "الختمة",
            .wird:       "الورد",
            .hadith:     "الحديث",
            .phrases:    "عبارات",
            .names:      "الأسماء الحسنى",
            .ahkam:      "الأحكام",
            .prayerLog:  "سجل الصلاة",
            .calendar:   "التقويم",
            .zakat:      "الزكاة",
            .wallet:     "بطاقات المحفظة",
            .sunan:      "السنن الرواتب"
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
            intent: LogPrayerIntent(),
            phrases: [
                "سجّل \(\.$prayer) في \(.applicationName)",
                "سجّل صلاة \(\.$prayer) في \(.applicationName)",
                "صلّيت \(\.$prayer) في \(.applicationName)"
            ],
            shortTitle: "سجّل صلاة",
            systemImageName: "checkmark.seal.fill"
        )
        AppShortcut(
            intent: KhatmahPositionIntent(),
            phrases: [
                "أين ختمتي في \(.applicationName)",
                "أين وصلت في \(.applicationName)",
                "موضع ختمتي في \(.applicationName)"
            ],
            shortTitle: "أين ختمتي",
            systemImageName: "book.closed.fill"
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
