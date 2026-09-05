import Foundation

// MARK: - دفتر يومي للإحصاء الشهري
//
// كل يوم مدخل واحد صغير: أذكار، صفحات، صلوات في وقتها. لا يُمسح إلا بتصفير الإحصائيات.

struct DailyLedger: Codable, Equatable {
    var dhikr: Int = 0
    var pages: Int = 0
    var prayersOnTime: Int = 0
    var kahf: Bool = false
}

struct MonthlyStats: Equatable {
    var days: Int = 0
    var activeDays: Int = 0
    var dhikr: Int = 0
    var pages: Int = 0
    var prayersOnTime: Int = 0
    var kahfFridays: Int = 0
    var bestDayDhikr: Int = 0
}

extension AtharStore {
    private static let ledgerPrefix = "athar.ledger."
    private static let tzPendingKey = "athar.tzChangePending"

    func ledger(for day: Date = Date()) -> DailyLedger {
        guard let data = defaults.data(forKey: Self.ledgerPrefix + Self.dayKey(day)),
              let l = try? JSONDecoder().decode(DailyLedger.self, from: data) else { return DailyLedger() }
        return l
    }

    func updateLedger(for day: Date = Date(), _ change: (inout DailyLedger) -> Void) {
        var l = ledger(for: day)
        change(&l)
        if let data = try? JSONEncoder().encode(l) { defaults.set(data, forKey: Self.ledgerPrefix + Self.dayKey(day)) }
        objectWillChange.send()
    }

    func noteDhikr(_ n: Int = 1) { updateLedger { $0.dhikr += n } }
    func notePageRead() { updateLedger { $0.pages += 1 } }
    func noteKahfRead() { updateLedger { $0.kahf = true } }

    /// إحصاء شهر هجري: (year, month) بتقويم أم القرى.
    func monthlyStats(year: Int, month: Int) -> MonthlyStats {
        var s = MonthlyStats()
        let n = Occasions.daysInMonth(year: year, month: month)
        for d in 1...n {
            guard let date = Occasions.date(year: year, month: month, day: d) else { continue }
            s.days += 1
            let l = ledger(for: date)
            if l.dhikr > 0 || l.pages > 0 || l.prayersOnTime > 0 { s.activeDays += 1 }
            s.dhikr += l.dhikr; s.pages += l.pages; s.prayersOnTime += l.prayersOnTime
            if l.kahf { s.kahfFridays += 1 }
            s.bestDayDhikr = max(s.bestDayDhikr, l.dhikr)
        }
        return s
    }

    func resetLedger() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(Self.ledgerPrefix) { defaults.removeObject(forKey: key) }
    }

    // MARK: المسافر — تغيّر المنطقة الزمنية

    /// يُرفع عند تغيّر المنطقة الزمنية ليسأل «الصلاة» المستخدمَ عن تحديث موقعه، ويُخفض بجوابه.
    var timeZoneChangePending: Bool {
        get { defaults.bool(forKey: Self.tzPendingKey) }
        set { defaults.set(newValue, forKey: Self.tzPendingKey); objectWillChange.send() }
    }
}
