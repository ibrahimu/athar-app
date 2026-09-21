import Foundation

/// A local planner; dates can be matched to the user's announced Ramadan start.
enum RamadanSection: String, Codable, CaseIterable, Identifiable {
    case timetable, qada, readings, qiyam, adhkar
    var id: String { rawValue }
    var title: String {
        switch self {
        case .timetable: return "إمساكية رمضان"
        case .qada: return "قضاء الصيام"
        case .readings: return "قراءاتي"
        case .qiyam: return "مصحف القيام"
        case .adhkar: return "أذكار اليوم"
        }
    }
}

struct RamadanPreferences: Codable {
    var followsAppTheme: Bool? = nil // Missing in earlier preferences also follows the app.
    var color = AppTheme.indigo
    var pattern = BackgroundPattern.stars
    var icon = "moon.stars.fill"
    var sections = RamadanSection.allCases
    var hidden: Set<RamadanSection> = []
    var start: Date?
    var length: Int? // nil follows the selected calendar; an announcement can override it.
    static let icons = ["moon.stars.fill", "moon.fill", "sparkles", "sun.horizon.fill"]
}

enum RamadanCalendar {
    static func start(now: Date, zone: TimeZone, offset: Int) -> Date {
        var c = Calendar(identifier: .islamicUmmAlQura)
        c.timeZone = zone
        let shifted = c.date(byAdding: .day, value: offset, to: now) ?? now
        let parts = c.dateComponents([.year, .month], from: shifted)
        let year = (parts.year ?? 1448) + ((parts.month ?? 1) > 9 ? 1 : 0)
        let first = c.date(from: DateComponents(year: year, month: 9, day: 1, hour: 12)) ?? now
        return c.date(byAdding: .day, value: -offset, to: first) ?? first
    }
    static func dates(start: Date, count: Int, zone: TimeZone) -> [Date] {
        var c = Calendar(identifier: .gregorian); c.timeZone = zone
        return (0..<max(29, min(30, count))).compactMap { c.date(byAdding: .day, value: $0, to: start) }
    }
    static func length(start: Date, zone: TimeZone, offset: Int) -> Int {
        var c = Calendar(identifier: .islamicUmmAlQura); c.timeZone = zone
        let shifted = c.date(byAdding: .day, value: offset, to: start) ?? start
        return c.range(of: .day, in: .month, for: shifted)?.count ?? 30
    }
}

#if !os(tvOS)
extension AtharStore {
    var ramadanPreferences: RamadanPreferences {
        get {
            guard let d = defaults.data(forKey: "athar.ramadan.preferences"),
                  let p = try? JSONDecoder().decode(RamadanPreferences.self, from: d) else { return .init() }
            return p
        }
        set {
            if let d = try? JSONEncoder().encode(newValue) { defaults.set(d, forKey: "athar.ramadan.preferences") }
            objectWillChange.send()
        }
    }
    var fastingDaysOwed: Int {
        get { max(0, min(10000, defaults.integer(forKey: "athar.ramadan.qada"))) }
        set { defaults.set(max(0, min(10000, newValue)), forKey: "athar.ramadan.qada"); objectWillChange.send() }
    }
}
#endif
