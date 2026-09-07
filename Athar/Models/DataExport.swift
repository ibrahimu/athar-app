import Foundation
import UniformTypeIdentifiers

/// تصدير بياناتك ملفًا واستيرادها — كل ما يخصّك من التفضيلات والمفضّلة والسجلات، بلا حسابات.
/// ومن بدّل جهازه لا يبدأ من الصفر: يُقرأ الملف ويُعرض عليه ما فيه، ثم يُكتب دفعةً أو لا يُكتب.
enum DataExport {
    static let fileName = "athar-backup.json"

    /// علامتا الملف: بهما يُعرف أنه نسخة «أثر» لا ملف JSON عابر. النسخة المشحونة في
    /// المتجر تكتب العلامتين نفسيهما، فما صدّرته تلك تُقرؤه هذه كما هو بلا تحويل ولا هجرة.
    private static let marker = "athar"
    private static let formatVersion = 1

    /// ما لا يُصدَّر ولا يُستورد — لأن استعادته على جهاز آخر تكسر التنصيب لا تُصلحه:
    /// «spotlight» و«whatsNew» طابعا نسخةٍ محليّان، فردّهما إلى القديم يُبطل فهرس بحث iOS
    /// المبنيّ على هذا الجهاز ويعيد فتح شاشة «الجديد» عن إصدار مضى؛ و«cloudSync» مربوط
    /// بحساب iCloud الحاضر في الجهاز لا في الملف؛ و«groupKhatmah» عضويةٌ برمز جماعة
    /// قد تكون انفضّت؛ و«notifications» بصمة الجدولة المحلية تُبنى من التنبيهات نفسها؛
    /// و«usesDeviceLocation» إذنٌ يُمنح للجهاز لا يُنقل معه؛ و«tzChangePending» حالٌ عابرة؛
    /// و«didOnboard» حالُ هذا التنصيب لا حالُ الملف، وردّه كاذبًا يعيد شاشة التعريف بلا سبب.
    private static let excludedPrefixes = [
        "athar.spotlight", "athar.whatsNew", "athar.tzChangePending", "athar.usesDeviceLocation",
        "athar.groupKhatmah", "athar.notifications", "athar.cloudSync", "athar.didOnboard",
    ]

    private static func isExcluded(_ key: String) -> Bool {
        excludedPrefixes.contains { key.hasPrefix($0) }
    }

    // MARK: التصدير

    static func export(from defaults: UserDefaults) throws -> URL {
        var payload: [String: Any] = [:]
        for (k, v) in defaults.dictionaryRepresentation() where k.hasPrefix("athar.") && !isExcluded(k) {
            if JSONSerialization.isValidJSONObject([v]) { payload[k] = v }
            else if let d = v as? Data { payload[k] = ["__data": d.base64EncodedString()] }
            else if let date = v as? Date { payload[k] = ["__date": date.timeIntervalSince1970] }
        }
        // رقم الإصدار يُكتب في غلاف الملف لا في مفاتيحه: تُظهره ورقة التأكيد ليعرف
        // صاحبه من أين جاءت النسخة، ولا سبيل إلى أن يعود قيمةً في التفضيلات.
        var wrapper: [String: Any] = ["app": marker, "version": formatVersion,
                                      "exported": Date().timeIntervalSince1970, "keys": payload]
        if let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String { wrapper["appVersion"] = v }
        let data = try JSONSerialization.data(withJSONObject: wrapper, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: ما في الملف — قبل الكتابة

    /// عائلة مفاتيح كما تُقرأ في ورقة التأكيد: «المصحف وعلاماتك — 12 قيمة».
    struct Family: Identifiable, Hashable {
        let id: String
        let title: String
        let icon: String
        /// مفتاح لون Theme.accent(for:) — يُقرأ في الواجهة لا هنا.
        let accent: String
        let count: Int
    }

    /// ملفٌ قُرئ وتُحقّق منه بتمامه ولم يُكتب منه حرف بعد. يحمل قيمه في الذاكرة،
    /// فلا يُحتاج إلى الملف مرّةً أخرى حين يوافق صاحبه — ولا إلى إذن وصولٍ ثانٍ.
    struct Preview: Identifiable {
        let fileName: String
        fileprivate let values: [String: Any]
        /// تاريخ التصدير ورقم الإصدار كما كُتبا في الغلاف — قد يغيبان في ملف قديم.
        let exported: Date?
        let appVersion: String?
        let families: [Family]

        var count: Int { values.count }
        var id: String { "\(fileName)#\(values.count)" }
    }

    /// يقرأ الملف ويتحقّق من كل قيمة فيه بلا أن يكتب حرفًا — فما يُرفض يُرفض قبل أن يمسّ بياناتك.
    static func inspect(_ url: URL) throws -> Preview {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw unreadableFile() }
        // سقفٌ قبل التحليل: نسخة «أثر» أصغر من هذا بمراحل، وملفٌ أضخم ليس منّا أصلًا
        // فلا يُستنزف عتاد الجهاز في تحليله.
        guard data.count <= 8 * 1024 * 1024 else { throw notOurFile() }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              obj["app"] as? String == marker,
              let fileVersion = obj["version"] as? Int, fileVersion >= 1, fileVersion <= formatVersion,
              let keys = obj["keys"] as? [String: Any]
        else { throw notOurFile() }

        var validated: [String: Any] = [:]
        for (key, value) in keys where key.hasPrefix("athar.") && !isExcluded(key) {
            let decoded: Any
            if let dict = value as? [String: Any], let b64 = dict["__data"] as? String {
                guard let bytes = Data(base64Encoded: b64) else { throw invalidBackup() }
                decoded = bytes
            } else if let dict = value as? [String: Any], let timestamp = dict["__date"] as? Double {
                guard timestamp.isFinite else { throw invalidBackup() }
                decoded = Date(timeIntervalSince1970: timestamp)
            } else { decoded = value }
            // JSON يسمح بـ null بينما UserDefaults لا يسمح به؛ يُفحص الملف كله قبل أول كتابة.
            guard PropertyListSerialization.propertyList([key: decoded], isValidFor: .binary) else { throw invalidBackup() }
            validated[key] = decoded
        }
        guard !validated.isEmpty else { throw emptyBackup() }

        let exported = (obj["exported"] as? Double).flatMap { $0.isFinite ? Date(timeIntervalSince1970: $0) : nil }
        return Preview(fileName: url.lastPathComponent,
                       values: validated,
                       exported: exported,
                       appVersion: obj["appVersion"] as? String,
                       families: families(for: Array(validated.keys)))
    }

    /// الكتابة — بعد التحقّق وحده، ودفعةً واحدة. فإمّا نسخةٌ كاملة أو لا شيء.
    @discardableResult
    static func apply(_ preview: Preview, into defaults: UserDefaults) -> Int {
        for (key, value) in preview.values { defaults.set(value, forKey: key) }
        return preview.values.count
    }

    /// قراءةٌ وكتابةٌ في نداءٍ واحد — لمن لا يعرض ورقة تأكيد.
    @discardableResult
    static func importFile(_ url: URL, into defaults: UserDefaults) throws -> Int {
        apply(try inspect(url), into: defaults)
    }

    // MARK: تصنيف المفاتيح

    /// عائلات المفاتيح كما تُعرض في ورقة التأكيد. الترتيب مقصود — القرآن أولًا ثم
    /// العبادة ثم التفضيلات — وأول عائلة يطابقها المفتاح هي عائلته فلا يُعدّ مرتين.
    private static func familyTable() -> [(id: String, title: String, icon: String, accent: String, prefixes: [String])] {
        [
            ("mushaf", loc("المصحف وعلاماتك"), "book.closed.fill", "green",
             ["athar.mushaf.", "athar.fitPage", "athar.readingThemeAuto"]),
            ("hifz", loc("الحفظ والمراجعة"), "brain.head.profile", "hifz",
             ["athar.hifz"]),
            ("khatmah", loc("الختمة والورد"), "books.vertical.fill", "gold",
             ["athar.khatmah.", "athar.wird."]),
            ("dhikr", loc("الذكر والتسبيح"), "circle.hexagongrid.fill", "calm",
             ["athar.tasbih", "athar.streak", "athar.bestStreak", "athar.totalDhikrCount",
              "athar.completed", "athar.session.", "athar.ledger.", "athar.lastActiveDay"]),
            ("prayer", loc("الصلاة وسجلّها"), "moon.stars.fill", "night",
             ["athar.prayerLog.", "athar.qada.", "athar.prayerPref.", "athar.prayerOffset.",
              "athar.calcMethod", "athar.asrMethod", "athar.iqamahMinutes", "athar.coverage", "athar.prayer"]),
            ("alerts", loc("التنبيهات والأذان"), "bell.badge.fill", "dawn",
             ["athar.athan", "athar.preAthanMinutes", "athar.reminder", "athar.morningReminder",
              "athar.eveningReminder", "athar.adhkarReminderByPrayer", "athar.istighfar",
              "athar.jumuah", "athar.fasting.", "athar.qiyam", "athar.white", "athar.liveActivity"]),
            ("place", loc("مدينتك وموقعك"), "location.fill", "maghrib",
             ["athar.latitude", "athar.longitude", "athar.cityId", "athar.secondaryCityId",
              "athar.placeName", "athar.placeTimeZone"]),
            ("hadith", loc("الحديث والمحفوظة"), "quote.opening", "sea",
             ["athar.hadith."]),
            ("audio", loc("التلاوة والتفسير"), "waveform", "dusk",
             ["athar.recitation.", "athar.ayah", "athar.tafsir."]),
            ("look", loc("المظهر والترتيب"), "paintbrush.fill", "green",
             ["athar.theme", "athar.appearance", "athar.bgPattern", "athar.unifyIcons",
              "athar.uiFont", "athar.fontScale", "athar.tabs.", "athar.home.", "athar.widgetPalette",
              "athar.countTapArea", "athar.hapticsEnabled", "athar.language"]),
            ("zakat", loc("الزكاة"), "banknote.fill", "calm",
             ["athar.zakat."]),
        ]
    }

    private static func families(for keys: [String]) -> [Family] {
        let table = familyTable()
        var counts: [String: Int] = [:]
        var rest = 0
        for key in keys {
            if let f = table.first(where: { fam in fam.prefixes.contains(where: { key.hasPrefix($0) }) }) {
                counts[f.id, default: 0] += 1
            } else {
                rest += 1
            }
        }
        var out = table.compactMap { f -> Family? in
            guard let n = counts[f.id], n > 0 else { return nil }
            return Family(id: f.id, title: f.title, icon: f.icon, accent: f.accent, count: n)
        }
        // ما لم يقع في عائلة يُذكر ولا يُخفى: من يستورد يرى كل ما سيُكتب.
        if rest > 0 {
            out.append(Family(id: "other", title: loc("تفضيلات أخرى"),
                              icon: "slider.horizontal.3", accent: "sea", count: rest))
        }
        return out
    }

    // MARK: الأعذار

    private static func unreadableFile() -> NSError {
        NSError(domain: "athar", code: 4, userInfo: [NSLocalizedDescriptionKey: loc("تعذّرت قراءة الملف.")])
    }

    private static func notOurFile() -> NSError {
        NSError(domain: "athar", code: 1, userInfo: [NSLocalizedDescriptionKey: loc("ليس ملف نسخة احتياطية من أثر.")])
    }

    private static func invalidBackup() -> NSError {
        NSError(domain: "athar", code: 2, userInfo: [NSLocalizedDescriptionKey: loc("تحتوي النسخة على بيانات غير صالحة. لم تُستورد أي تغييرات.")])
    }

    private static func emptyBackup() -> NSError {
        NSError(domain: "athar", code: 3, userInfo: [NSLocalizedDescriptionKey: loc("هذا الملف من أثر لكنه لا يحمل بيانات تُستعاد.")])
    }
}
