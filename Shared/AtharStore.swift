import Foundation
import CoreLocation

/// Shared, file-backed state so the app and its widgets read the same numbers.
/// Falls back to standard defaults if the App Group is unavailable.
/// أين يضغط المستخدم ليعدّ. الدائرة وحدها تُلزمه بمدّ إبهامه إلى أسفل الشاشة،
/// فجعلنا «الشاشة كاملة» هي الأصل بناءً على ملاحظة مستخدم.
enum CountTapArea: String, CaseIterable, Identifiable {
    case screen, circle
    var id: String { rawValue }
    var title: String { self == .screen ? "الشاشة كاملة" : "الدائرة فقط" }
    var shortTitle: String { title }
    var detail: String {
        self == .screen
            ? "اضغط أي مكان في الشاشة ليزيد العدّ — أسهل للإبهام"
            : "لا يزيد العدّ إلا بالضغط على الدائرة نفسها"
    }
}

final class AtharStore: ObservableObject {
    static let appGroup = "group.com.ibrahim.athar"
    static let shared = AtharStore()

    let defaults: UserDefaults

    private enum Key {
        static let totalDhikrCount   = "athar.totalDhikrCount"
        static let tasbihCount       = "athar.tasbihCount"
        static let tasbihTarget      = "athar.tasbihTarget"
        static let tasbihPhrase      = "athar.tasbihPhrase"
        static let streak            = "athar.streak"
        static let lastActiveDay     = "athar.lastActiveDay"
        static let bestStreak        = "athar.bestStreak"
        static let completedToday    = "athar.completedToday"
        static let completedDayStamp = "athar.completedDayStamp"
        static let hapticsEnabled    = "athar.hapticsEnabled"
        static let fontScale         = "athar.fontScale"
        static let morningReminder   = "athar.morningReminder"
        static let eveningReminder   = "athar.eveningReminder"
        static let remindersEnabled  = "athar.remindersEnabled"
        static let latitude          = "athar.latitude"
        static let longitude         = "athar.longitude"
        static let placeName         = "athar.placeName"
        static let usesDeviceLocation = "athar.usesDeviceLocation"
        static let cityId            = "athar.cityId"
        static let calcMethod        = "athar.calcMethod"
        static let asrMethod         = "athar.asrMethod"
        static let athanAlerts       = "athar.athanAlerts"
        static let didOnboard        = "athar.didOnboard"
        static let istighfarAlerts   = "athar.istighfarAlerts"
        static let istighfarEvery    = "athar.istighfarEveryHours"
        static let qiyamAlert        = "athar.qiyamAlert"
        static let jumuahAlert       = "athar.jumuahAlert"
        static let fastingAlert      = "athar.fastingAlert"
        static let whiteDaysAlert    = "athar.whiteDaysAlert"
        static let countTapArea      = "athar.countTapArea"
        static let placeTimeZone     = "athar.placeTimeZone"
    }

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: AtharStore.appGroup) ?? .standard
        registerDefaults()
        // قبل أول رسم: وإلا رُسمت الشاشات بالطابع الافتراضي ولم تُعد.
        Theme.current = AppTheme(rawValue: self.defaults.string(forKey: "athar.theme") ?? "") ?? .green
        BackgroundPattern.current = BackgroundPattern(rawValue: self.defaults.string(forKey: "athar.bgPattern") ?? "") ?? .stars
        Theme.unifyIcons = self.defaults.bool(forKey: "athar.unifyIcons")
        // مزامنة iCloud مؤجّلة لإصدار لاحق (تحتاج دمجًا آمنًا واختبارًا على أجهزة) — CloudSync.swift جاهز.
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Key.tasbihTarget: 33,
            Key.tasbihPhrase: "سُبْحَانَ اللهِ",
            Key.hapticsEnabled: true,
            Key.fontScale: 1.0,
            Key.morningReminder: 7 * 60,   // 07:00, minutes past midnight
            Key.eveningReminder: 17 * 60,  // 17:00
            Key.remindersEnabled: false,
            Key.latitude: 21.4225,          // مكة المكرمة
            Key.longitude: 39.8262,
            Key.placeName: "مكة المكرمة",
            Key.cityId: "makkah",
            Key.placeTimeZone: "Asia/Riyadh",
            Key.usesDeviceLocation: false,
            Key.calcMethod: CalculationMethod.ummAlQura.rawValue,
            Key.asrMethod: AsrMethod.standard.rawValue,
            Key.athanAlerts: false,
            Key.istighfarAlerts: false,
            Key.istighfarEvery: 3,
            Key.qiyamAlert: false,
            Key.jumuahAlert: false,
            Key.fastingAlert: false,
            Key.whiteDaysAlert: false,
            Key.countTapArea: CountTapArea.screen.rawValue
        ])
    }

    // MARK: - Counters

    var totalDhikrCount: Int {
        get { defaults.integer(forKey: Key.totalDhikrCount) }
        set { defaults.set(newValue, forKey: Key.totalDhikrCount); objectWillChange.send() }
    }

    var tasbihCount: Int {
        get { defaults.integer(forKey: Key.tasbihCount) }
        set { defaults.set(newValue, forKey: Key.tasbihCount); objectWillChange.send() }
    }

    var tasbihTarget: Int {
        get { max(1, defaults.integer(forKey: Key.tasbihTarget)) }
        set { defaults.set(max(1, newValue), forKey: Key.tasbihTarget); objectWillChange.send() }
    }

    var tasbihPhrase: String {
        get { defaults.string(forKey: Key.tasbihPhrase) ?? "سُبْحَانَ اللهِ" }
        set { defaults.set(newValue, forKey: Key.tasbihPhrase); objectWillChange.send() }
    }

    // MARK: - Streak

    var streak: Int { defaults.integer(forKey: Key.streak) }
    var bestStreak: Int { defaults.integer(forKey: Key.bestStreak) }

    /// Category ids completed today.
    var completedToday: Set<String> {
        get {
            guard defaults.string(forKey: Key.completedDayStamp) == Self.dayStamp() else { return [] }
            return Set(defaults.stringArray(forKey: Key.completedToday) ?? [])
        }
        set {
            defaults.set(Self.dayStamp(), forKey: Key.completedDayStamp)
            defaults.set(Array(newValue), forKey: Key.completedToday)
            objectWillChange.send()
        }
    }

    func markCompleted(categoryId: String) {
        var set = completedToday
        guard !set.contains(categoryId) else { return }
        set.insert(categoryId)
        completedToday = set
        touchStreak()
    }

    /// Records activity for today and rolls the streak forward (or resets it).
    func touchStreak() {
        let today = Self.dayStamp()
        let last = defaults.string(forKey: Key.lastActiveDay)
        guard last != today else { return }

        let yesterday = Self.dayStamp(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        let newStreak = (last == yesterday) ? defaults.integer(forKey: Key.streak) + 1 : 1

        defaults.set(newStreak, forKey: Key.streak)
        defaults.set(today, forKey: Key.lastActiveDay)
        if newStreak > defaults.integer(forKey: Key.bestStreak) {
            defaults.set(newStreak, forKey: Key.bestStreak)
        }
        objectWillChange.send()
    }

    /// Streak is only "alive" if the user was active today or yesterday.
    var displayStreak: Int {
        guard let last = defaults.string(forKey: Key.lastActiveDay) else { return 0 }
        let today = Self.dayStamp()
        let yesterday = Self.dayStamp(for: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
        return (last == today || last == yesterday) ? streak : 0
    }

    // MARK: - Preferences

    var hapticsEnabled: Bool {
        get { defaults.bool(forKey: Key.hapticsEnabled) }
        set { defaults.set(newValue, forKey: Key.hapticsEnabled); objectWillChange.send() }
    }

    var fontScale: Double {
        get { max(0.85, min(1.6, defaults.double(forKey: Key.fontScale))) }
        set { defaults.set(newValue, forKey: Key.fontScale); objectWillChange.send() }
    }

    var remindersEnabled: Bool {
        get { defaults.bool(forKey: Key.remindersEnabled) }
        set { defaults.set(newValue, forKey: Key.remindersEnabled); objectWillChange.send() }
    }

    var morningReminderMinutes: Int {
        get { defaults.integer(forKey: Key.morningReminder) }
        set { defaults.set(newValue, forKey: Key.morningReminder); objectWillChange.send() }
    }

    var eveningReminderMinutes: Int {
        get { defaults.integer(forKey: Key.eveningReminder) }
        set { defaults.set(newValue, forKey: Key.eveningReminder); objectWillChange.send() }
    }

    // MARK: - Prayer times

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: defaults.double(forKey: Key.latitude),
                               longitude: defaults.double(forKey: Key.longitude))
    }

    var placeName: String {
        get { defaults.string(forKey: Key.placeName) ?? "مكة المكرمة" }
        set { defaults.set(newValue, forKey: Key.placeName); objectWillChange.send() }
    }

    var cityId: String? {
        get { defaults.string(forKey: Key.cityId) }
        set { defaults.set(newValue, forKey: Key.cityId); objectWillChange.send() }
    }

    /// The zone the chosen place actually sits in — not the device's. Prayer times computed
    /// with the device zone but a remote city's longitude come out hours wrong.
    var placeTimeZone: TimeZone {
        guard !usesDeviceLocation,
              let id = defaults.string(forKey: Key.placeTimeZone),
              let zone = TimeZone(identifier: id)
        else { return .current }
        return zone
    }

    var usesDeviceLocation: Bool {
        get { defaults.bool(forKey: Key.usesDeviceLocation) }
        set { defaults.set(newValue, forKey: Key.usesDeviceLocation); objectWillChange.send() }
    }

    var calculationMethod: CalculationMethod {
        get { CalculationMethod(rawValue: defaults.string(forKey: Key.calcMethod) ?? "") ?? .ummAlQura }
        set { defaults.set(newValue.rawValue, forKey: Key.calcMethod); objectWillChange.send() }
    }

    var asrMethod: AsrMethod {
        get { AsrMethod(rawValue: defaults.string(forKey: Key.asrMethod) ?? "") ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: Key.asrMethod); objectWillChange.send() }
    }

    var countTapArea: CountTapArea {
        get { CountTapArea(rawValue: defaults.string(forKey: Key.countTapArea) ?? "") ?? .screen }
        set { defaults.set(newValue.rawValue, forKey: Key.countTapArea); objectWillChange.send() }
    }

    var athanAlerts: Bool {
        get { defaults.bool(forKey: Key.athanAlerts) }
        set { defaults.set(newValue, forKey: Key.athanAlerts); objectWillChange.send() }
    }

    /// هل عُرضت شاشة الترحيب؟
    var didOnboard: Bool {
        get { defaults.bool(forKey: Key.didOnboard) }
        set { defaults.set(newValue, forKey: Key.didOnboard); objectWillChange.send() }
    }

    /// تذكير الاستغفار كل بضع ساعات.
    var istighfarAlerts: Bool {
        get { defaults.bool(forKey: Key.istighfarAlerts) }
        set { defaults.set(newValue, forKey: Key.istighfarAlerts); objectWillChange.send() }
    }

    var istighfarEveryHours: Int {
        get { max(1, defaults.integer(forKey: Key.istighfarEvery) == 0 ? 3 : defaults.integer(forKey: Key.istighfarEvery)) }
        set { defaults.set(max(1, newValue), forKey: Key.istighfarEvery); objectWillChange.send() }
    }

    /// تنبيه قيام الليل عند دخول الثلث الأخير.
    var qiyamAlert: Bool {
        get { defaults.bool(forKey: Key.qiyamAlert) }
        set { defaults.set(newValue, forKey: Key.qiyamAlert); objectWillChange.send() }
    }

    /// تذكير الجمعة: الكهف والصلاة على النبي.
    var jumuahAlert: Bool {
        get { defaults.bool(forKey: Key.jumuahAlert) }
        set { defaults.set(newValue, forKey: Key.jumuahAlert); objectWillChange.send() }
    }

    /// تذكير صيام الاثنين والخميس (ليلة الصيام).
    var fastingAlert: Bool {
        get { defaults.bool(forKey: Key.fastingAlert) }
        set { defaults.set(newValue, forKey: Key.fastingAlert); objectWillChange.send() }
    }

    /// تذكير الأيام البيض (١٣ و١٤ و١٥ من كل شهر هجري).
    var whiteDaysAlert: Bool {
        get { defaults.bool(forKey: Key.whiteDaysAlert) }
        set { defaults.set(newValue, forKey: Key.whiteDaysAlert); objectWillChange.send() }
    }

    func setCity(_ city: City) {
        defaults.set(city.latitude, forKey: Key.latitude)
        defaults.set(city.longitude, forKey: Key.longitude)
        defaults.set(city.name, forKey: Key.placeName)
        defaults.set(city.id, forKey: Key.cityId)
        defaults.set(city.tz, forKey: Key.placeTimeZone)
        defaults.set(false, forKey: Key.usesDeviceLocation)
        objectWillChange.send()
    }

    static let deviceLocationFallbackName = "موقعك الحالي"

    func setDeviceLocation(_ coordinate: CLLocationCoordinate2D, name: String?) {
        defaults.set(coordinate.latitude, forKey: Key.latitude)
        defaults.set(coordinate.longitude, forKey: Key.longitude)
        // Always overwrite: leaving the previous city's name next to new coordinates
        // would tell the user they are somewhere they are not.
        let resolved = (name?.isEmpty == false) ? name! : Self.deviceLocationFallbackName
        defaults.set(resolved, forKey: Key.placeName)
        defaults.removeObject(forKey: Key.cityId)
        defaults.removeObject(forKey: Key.placeTimeZone)
        defaults.set(true, forKey: Key.usesDeviceLocation)
        objectWillChange.send()
    }

    /// Prayer times for a given day at the stored location.
    func prayerTimes(for date: Date = Date()) -> PrayerTimes? {
        PrayerTimes(date: date,
                    coordinate: coordinate,
                    timeZone: placeTimeZone,
                    method: calculationMethod,
                    asr: asrMethod)
    }

    // MARK: - Helpers

    static func dayStamp(for date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }

    func resetAllProgress() {
        [Key.totalDhikrCount, Key.tasbihCount, Key.streak, Key.bestStreak,
         Key.lastActiveDay, Key.completedToday, Key.completedDayStamp].forEach {
            defaults.removeObject(forKey: $0)
        }
        objectWillChange.send()
    }
}
