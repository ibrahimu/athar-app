import Foundation
import CoreLocation

// MARK: - مفضّلة الحديث وتذكيره، تنبيه ما قبل الأذان، سجل الصلاة، الزكاة

extension AtharStore {
    private enum FKey {
        static let hadithFavorites       = "athar.hadith.favorites"
        static let hadithReminder        = "athar.hadith.reminder"
        static let hadithReminderMinutes = "athar.hadith.reminderMinutes"
        static let preAthanMinutes       = "athar.preAthanMinutes"
        static let prayerLogPrefix       = "athar.prayerLog."
        static let qadaPrefix            = "athar.qada."
        static let zakatGoldPrice        = "athar.zakat.goldPrice"
        static let zakatSilverPrice      = "athar.zakat.silverPrice"
        static let offsetPrefix          = "athar.prayerOffset."
        static let iqamahMinutes         = "athar.iqamahMinutes"
        static let whatsNewVersion       = "athar.whatsNewVersion"
        static let secondaryCity         = "athar.secondaryCityId"
        static let ayahSoundMode         = "athar.ayahSoundMode"
    }

    /// ما يحدث صوتيًّا عند فتح آية في ورقة التفسير: تلاوتها، أو قراءة تفسيرها بصوت الجهاز، أو لا شيء.
    var ayahSoundMode: AyahSoundMode {
        get { AyahSoundMode(rawValue: defaults.string(forKey: FKey.ayahSoundMode) ?? "") ?? .none }
        set { defaults.set(newValue.rawValue, forKey: FKey.ayahSoundMode); objectWillChange.send() }
    }

    // MARK: مدينة ثانية (للمسافر أو لأهلٍ في بلد آخر)

    var secondaryCity: City? {
        get {
            guard let id = defaults.string(forKey: FKey.secondaryCity) else { return nil }
            return City.all.first { $0.id == id }
        }
        set {
            if let c = newValue { defaults.set(c.id, forKey: FKey.secondaryCity) }
            else { defaults.removeObject(forKey: FKey.secondaryCity) }
            objectWillChange.send()
        }
    }

    /// مواقيت المدينة الثانية بتوقيتها هي — بلا تعديل يدوي (التعديل خاص بمسجد المستخدم).
    func secondaryPrayerTimes(for date: Date = Date()) -> PrayerTimes? {
        guard let c = secondaryCity else { return nil }
        return PrayerTimes(date: date,
                           coordinate: CLLocationCoordinate2D(latitude: c.latitude, longitude: c.longitude),
                           timeZone: TimeZone(identifier: c.tz) ?? .current,
                           method: calculationMethod, asr: asrMethod)
    }

    /// آخر إصدار عُرضت له ورقة «ما الجديد».
    var whatsNewShownVersion: String {
        get { defaults.string(forKey: FKey.whatsNewVersion) ?? "" }
        set { defaults.set(newValue, forKey: FKey.whatsNewVersion); objectWillChange.send() }
    }

    // MARK: ضبط المواقيت يدويًّا وتنبيه الإقامة

    /// تعديل بالدقائق لصلاة بعينها (−30 … +30) ليطابق تقويم مسجد الحيّ.
    func prayerOffset(_ prayer: Prayer) -> Int {
        defaults.integer(forKey: FKey.offsetPrefix + prayer.rawValue)
    }

    func setPrayerOffset(_ minutes: Int, for prayer: Prayer) {
        let clamped = max(-30, min(30, minutes))
        if clamped == 0 { defaults.removeObject(forKey: FKey.offsetPrefix + prayer.rawValue) }
        else { defaults.set(clamped, forKey: FKey.offsetPrefix + prayer.rawValue) }
        objectWillChange.send()
    }

    var prayerOffsets: [Prayer: Int] {
        var d: [Prayer: Int] = [:]
        for p in Prayer.allCases where p.isPrayer {
            let v = prayerOffset(p)
            if v != 0 { d[p] = v }
        }
        return d
    }

    var hasPrayerOffsets: Bool { !prayerOffsets.isEmpty }

    func resetPrayerOffsets() {
        for p in Prayer.allCases { defaults.removeObject(forKey: FKey.offsetPrefix + p.rawValue) }
        objectWillChange.send()
    }

    /// تنبيه الإقامة بعد الأذان بهذه الدقائق — صفر يعني لا تنبيه.
    var iqamahMinutes: Int {
        get { defaults.integer(forKey: FKey.iqamahMinutes) }
        set { defaults.set(max(0, newValue), forKey: FKey.iqamahMinutes); objectWillChange.send() }
    }

    // MARK: الحديث

    /// معرّفات الأحاديث المحفوظة (r123 / n7) بترتيب الحفظ.
    var hadithFavorites: [String] {
        get { defaults.stringArray(forKey: FKey.hadithFavorites) ?? [] }
        set { defaults.set(newValue, forKey: FKey.hadithFavorites); objectWillChange.send() }
    }

    func isHadithFavorite(_ id: String) -> Bool { hadithFavorites.contains(id) }

    func toggleHadithFavorite(_ id: String) {
        var v = hadithFavorites
        if let i = v.firstIndex(of: id) { v.remove(at: i) } else { v.insert(id, at: 0) }
        hadithFavorites = v
    }

    /// تذكير يومي بحديث اليوم.
    var hadithReminder: Bool {
        get { defaults.bool(forKey: FKey.hadithReminder) }
        set { defaults.set(newValue, forKey: FKey.hadithReminder); objectWillChange.send() }
    }

    /// وقت تذكير الحديث بالدقائق من منتصف الليل (الافتراضي 8:30 صباحًا).
    var hadithReminderMinutes: Int {
        get { defaults.object(forKey: FKey.hadithReminderMinutes) as? Int ?? (8 * 60 + 30) }
        set { defaults.set(newValue, forKey: FKey.hadithReminderMinutes); objectWillChange.send() }
    }

    // MARK: قبل الأذان

    /// تنبيه قبل الأذان بهذه الدقائق — صفر يعني لا تنبيه.
    var preAthanMinutes: Int {
        get { defaults.integer(forKey: FKey.preAthanMinutes) }
        set { defaults.set(max(0, newValue), forKey: FKey.preAthanMinutes); objectWillChange.send() }
    }

    // MARK: سجل الصلاة

    enum PrayerStatus: String, CaseIterable {
        case none, onTime, late, missed

        var title: String {
            switch self {
            case .none:   return loc("لم تُسجَّل")
            case .onTime: return loc("في وقتها")
            case .late:   return loc("متأخّرة")
            case .missed: return loc("فائتة")
            }
        }
    }

    /// مفتاح اليوم الميلادي yyyy-MM-dd بتقويم غريغوري ثابت — لا يتأثر بلغة الجهاز.
    static func dayKey(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func prayerStatus(_ prayer: Prayer, on day: Date) -> PrayerStatus {
        let dict = defaults.dictionary(forKey: FKey.prayerLogPrefix + Self.dayKey(day)) as? [String: String] ?? [:]
        return PrayerStatus(rawValue: dict[prayer.rawValue] ?? "") ?? .none
    }

    func setPrayerStatus(_ status: PrayerStatus, for prayer: Prayer, on day: Date) {
        let key = FKey.prayerLogPrefix + Self.dayKey(day)
        var dict = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
        let was = PrayerStatus(rawValue: dict[prayer.rawValue] ?? "") ?? .none
        if status == .none { dict.removeValue(forKey: prayer.rawValue) } else { dict[prayer.rawValue] = status.rawValue }
        if dict.isEmpty { defaults.removeObject(forKey: key) } else { defaults.set(dict, forKey: key) }
        if status == .onTime, was != .onTime { updateLedger(for: day) { $0.prayersOnTime += 1 } }
        else if was == .onTime, status != .onTime { updateLedger(for: day) { $0.prayersOnTime = max(0, $0.prayersOnTime - 1) } }
        objectWillChange.send()
    }

    /// كل الأيام المسجَّلة (مفاتيح yyyy-MM-dd) — للإحصاء.
    var loggedDayKeys: [String] {
        defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(FKey.prayerLogPrefix) }
            .map { String($0.dropFirst(FKey.prayerLogPrefix.count)) }
            .sorted()
    }

    /// الفوائت المتراكمة لكل صلاة (يزيدها المستخدم أو يقضيها).
    func qadaCount(_ prayer: Prayer) -> Int {
        defaults.integer(forKey: FKey.qadaPrefix + prayer.rawValue)
    }

    func setQadaCount(_ n: Int, for prayer: Prayer) {
        defaults.set(max(0, n), forKey: FKey.qadaPrefix + prayer.rawValue)
        objectWillChange.send()
    }

    // MARK: الزكاة

    var zakatGoldPrice: Double {
        get { defaults.double(forKey: FKey.zakatGoldPrice) }
        set { defaults.set(max(0, newValue), forKey: FKey.zakatGoldPrice); objectWillChange.send() }
    }

    var zakatSilverPrice: Double {
        get { defaults.double(forKey: FKey.zakatSilverPrice) }
        set { defaults.set(max(0, newValue), forKey: FKey.zakatSilverPrice); objectWillChange.send() }
    }

    /// يُستدعى من تصفير الإحصائيات: يمسح سجل الصلاة والفوائت (لا المفضّلة ولا الإعدادات).
    func resetFeatureProgress() {
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(FKey.prayerLogPrefix) || key.hasPrefix(FKey.qadaPrefix) {
            defaults.removeObject(forKey: key)
        }
        resetLedger()
    }
}


/// خيار الصوت عند فتح الآية — «بلا صوت» هو الأصل حتى لا يفاجأ القارئ بصوت.
enum AyahSoundMode: String, CaseIterable, Identifiable {
    case none, recite, tafsir
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none:   return "بلا صوت"
        case .recite: return "تلاوة الآية"
        case .tafsir: return "قراءة التفسير"
        }
    }
    var shortTitle: String { title }
    var detail: String {
        switch self {
        case .none:   return "تفتح ورقة التفسير صامتة، وتشغّل ما تريد بيدك"
        case .recite: return "تُتلى الآية بصوت القارئ المختار عند فتحها (من الإنترنت)"
        case .tafsir: return "يُقرأ التفسير بصوت الجهاز العربي — بلا إنترنت"
        }
    }
    var icon: String {
        switch self {
        case .none:   return "speaker.slash.fill"
        case .recite: return "waveform.and.mic"
        case .tafsir: return "text.bubble.fill"
        }
    }
}
