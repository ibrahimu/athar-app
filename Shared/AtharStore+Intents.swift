import Foundation

// MARK: - تكامل النظام: النشاط الحيّ، وطلبات «سيري»، والروابط العميقة

/// التبويب المعلَّق لكل مخزن — حالة عابرة في الذاكرة لا تُحفظ في UserDefaults،
/// لأن الامتداد لا يضيف خصائص مخزَّنة، ولأن طلب «سيري» يجب أن يُستهلك مرة واحدة
/// ثم يزول (لو حُفظ لفتح القسم نفسه في كل إقلاع لاحق).
private var pendingTabs: [ObjectIdentifier: AppTab] = [:]

extension AtharStore {
    private enum IKey {
        static let liveActivity = "athar.liveActivity"
    }

    // MARK: النشاط الحيّ

    /// عرض الصلاة القادمة في Dynamic Island وشاشة القفل. مفعَّل افتراضيًا —
    /// نقرأ الكائن لا `bool(forKey:)` لأن الأخير يُعيد false عند غياب المفتاح.
    var liveActivityEnabled: Bool {
        get { defaults.object(forKey: IKey.liveActivity) as? Bool ?? true }
        set { defaults.set(newValue, forKey: IKey.liveActivity); objectWillChange.send() }
    }

    // MARK: الروابط العميقة

    /// التبويب الذي طلبه المستخدم من «سيري» أو اختصار قبل أن يرسم الجذر —
    /// يقرؤه RootView ويصفّره بعد الاستهلاك.
    var pendingTab: AppTab? {
        get { pendingTabs[ObjectIdentifier(self)] }
        set { pendingTabs[ObjectIdentifier(self)] = newValue; objectWillChange.send() }
    }

    // MARK: الصلاة القادمة

    /// الصلاة القادمة فعليًا (الشروق ليس صلاة)، وإن انقضت صلوات اليوم فَفجرُ الغد —
    /// المنطق نفسه في «اليوم» والويدجت، جُمع هنا ليشترك فيه النشاط الحيّ و«سيري».
    func upcomingPrayer(after now: Date = Date()) -> (prayer: Prayer, date: Date)? {
        if let next = prayerTimes(for: now)?.nextPrayer(after: now) { return next }
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let times = prayerTimes(for: tomorrow), let fajr = times[.fajr]
        else { return nil }
        return (.fajr, fajr)
    }

    /// جملة «سيري»: «العصر بعد 3 ساعات و12 دقيقة» — بأرقام غربية (counterText) ومعدود
    /// عربي صحيح: واحد بلا رقم، واثنان بالمثنّى، ومن ثلاثة إلى عشرة بالجمع، وما فوق بالمفرد.
    func nextPrayerPhrase(now: Date = Date()) -> String? {
        guard let up = upcomingPrayer(after: now) else { return nil }
        let totalMinutes = Int(up.date.timeIntervalSince(now) / 60)
        guard totalMinutes >= 1 else { return loc("حان وقت %1$@ الآن", up.prayer.title) }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let parts: [String] = [
            hours > 0 ? Self.hoursText(hours) : nil,
            minutes > 0 ? Self.minutesText(minutes) : nil
        ].compactMap { $0 }
        return loc("%1$@ بعد %2$@", up.prayer.title, parts.joined(separator: " و"))
    }

    private static func hoursText(_ n: Int) -> String {
        switch n {
        case 1:      return loc("ساعة")
        case 2:      return loc("ساعتين")
        case 3...10: return loc("%1$@ ساعات", n.counterText)
        default:     return loc("%1$@ ساعة", n.counterText)
        }
    }

    private static func minutesText(_ n: Int) -> String {
        switch n {
        case 1:      return loc("دقيقة")
        case 2:      return loc("دقيقتين")
        case 3...10: return loc("%1$@ دقائق", n.counterText)
        default:     return loc("%1$@ دقيقة", n.counterText)
        }
    }
}
