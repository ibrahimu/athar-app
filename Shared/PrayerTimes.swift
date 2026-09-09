import Foundation
import CoreLocation

// MARK: - Prayer

enum Prayer: String, CaseIterable, Identifiable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fajr:    return loc("fajr")
        case .sunrise: return loc("sunrise")
        case .dhuhr:   return loc("dhuhr")
        case .asr:     return loc("asr")
        case .maghrib: return loc("maghrib")
        case .isha:    return loc("isha")
        }
    }

    var icon: String {
        switch self {
        case .fajr:    return "moon.haze.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr:   return "sun.max.fill"
        case .asr:     return "sun.haze.fill"
        case .maghrib: return "sunset.fill"
        case .isha:    return "moon.stars.fill"
        }
    }

    /// الشروق ليس صلاة — يُعرض للعلم فقط ولا يُذكَّر به كصلاة قادمة.
    var isPrayer: Bool { self != .sunrise }

    /// مفتاح لون الوقت — تتبدّل هوية اللون مع تدرّج اليوم (فجر كهرماني ← عشاء نيليّ).
    /// يشترك فيه التطبيق والويدجت ليتناغم لونهما عبر اليوم.
    var accentKey: String {
        switch self {
        case .fajr:    return "dawn"
        case .sunrise: return "dawn"
        case .dhuhr:   return "noon"
        case .asr:     return "asr"
        case .maghrib: return "maghrib"
        case .isha:    return "night"
        }
    }
}

// MARK: - Calculation method

enum CalculationMethod: String, CaseIterable, Identifiable {
    case ummAlQura, mwl, egypt, karachi, isna, dubai

    var id: String { rawValue }

    var title: String { loc("calc_" + rawValue) }

    /// اسم مختصر يصلح للعرض داخل صف ضيق.
    var shortTitle: String { loc("calcShort_" + rawValue) }

    /// شرح يظهر تحت الاسم في شاشة الاختيار.
    var detail: String {
        switch self {
        case .ummAlQura: return "المعتمدة في السعودية · الفجر 18.5° والعشاء بعد المغرب 90 دقيقة"
        case .mwl:       return "الفجر 18° والعشاء 17°"
        case .egypt:     return "الفجر 19.5° والعشاء 17.5°"
        case .karachi:   return "الفجر والعشاء 18°"
        case .isna:      return "الفجر والعشاء 15°"
        case .dubai:     return "الفجر والعشاء 18.2°"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .ummAlQura: return 18.5
        case .mwl:       return 18
        case .egypt:     return 19.5
        case .karachi:   return 18
        case .isna:      return 15
        case .dubai:     return 18.2
        }
    }

    /// Umm al-Qura fixes Isha at a set interval after Maghrib instead of a sun angle.
    var ishaAngle: Double? {
        switch self {
        case .ummAlQura: return nil
        case .mwl:       return 17
        case .egypt:     return 17.5
        case .karachi:   return 18
        case .isna:      return 15
        case .dubai:     return 18.2
        }
    }

    /// Minutes after Maghrib, used when `ishaAngle` is nil.
    var ishaInterval: Double {
        self == .ummAlQura ? 90 : 0
    }
}

enum AsrMethod: String, CaseIterable, Identifiable {
    case standard, hanafi
    var id: String { rawValue }
    var title: String { loc(self == .standard ? "asr_standard" : "asr_hanafi") }
    var shortTitle: String { loc(self == .standard ? "asrShort_standard" : "asrShort_hanafi") }
    var detail: String {
        self == .standard
            ? "يدخل العصر إذا صار ظل الشيء مثله"
            : "يدخل العصر إذا صار ظل الشيء مثليه"
    }
    var shadowFactor: Double { self == .standard ? 1 : 2 }
}

// MARK: - Calculator

/// Offline astronomical prayer-time calculation. No network, no third-party data.
/// Follows the standard solar-position algorithm used by PrayTimes/ITL.
struct PrayerTimes {
    let date: Date
    let times: [Prayer: Date]
    /// True when Fajr or Isha had to be estimated because the sun never reaches the
    /// required depression angle at this latitude on this date.
    let usedHighLatitudeRule: Bool

    private init(date: Date, times: [Prayer: Date], usedHighLatitudeRule: Bool) {
        self.date = date; self.times = times; self.usedHighLatitudeRule = usedHighLatitudeRule
    }

    /// نسخة مزاحة بدقائق لكل صلاة — تعديل المستخدم اليدوي ليطابق تقويم مسجد حيّه.
    /// الشروق لا يُزاح (ليس صلاة ولا يُدرج في التقاويم المحلية).
    func shifted(by offsets: [Prayer: Int]) -> PrayerTimes {
        guard offsets.contains(where: { $0.value != 0 }) else { return self }
        var t = times
        for (prayer, minutes) in offsets where minutes != 0 && prayer != .sunrise {
            if let d = t[prayer] { t[prayer] = d.addingTimeInterval(Double(minutes) * 60) }
        }
        return PrayerTimes(date: date, times: t, usedHighLatitudeRule: usedHighLatitudeRule)
    }

    init?(date: Date,
          coordinate: CLLocationCoordinate2D,
          timeZone: TimeZone = .current,
          method: CalculationMethod = .ummAlQura,
          asr: AsrMethod = .standard) {

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day,
              let midnight = calendar.date(from: DateComponents(year: year, month: month, day: day))
        else { return nil }

        let lat = coordinate.latitude
        let lng = coordinate.longitude
        let tzOffset = Double(timeZone.secondsFromGMT(for: date)) / 3600

        let jDate = Self.julianDate(year: year, month: month, day: day) - lng / (15 * 24)

        // Iterative refinement: each time is computed from the sun's position at that time.
        func sunAngleTime(_ angle: Double, guess: Double, afterNoon: Bool) -> Double? {
            var t = guess
            for _ in 0..<3 {
                let decl = Self.sunDeclination(jDate + t / 24)
                let noon = Self.midDay(jDate + t / 24)
                let numerator = -sin(Self.rad(angle)) - sin(Self.rad(decl)) * sin(Self.rad(lat))
                let denominator = cos(Self.rad(decl)) * cos(Self.rad(lat))
                let ratio = numerator / denominator
                guard ratio >= -1, ratio <= 1 else { return nil }  // polar day/night
                let hourAngle = Self.deg(acos(ratio)) / 15
                t = afterNoon ? noon + hourAngle : noon - hourAngle
            }
            return t
        }

        func asrTime(factor: Double, guess: Double) -> Double? {
            var t = guess
            for _ in 0..<3 {
                let decl = Self.sunDeclination(jDate + t / 24)
                let angle = -Self.deg(atan(1 / (factor + tan(abs(Self.rad(lat - decl))))))
                guard let next = sunAngleTime(angle, guess: t, afterNoon: true) else { return nil }
                t = next
            }
            return t
        }

        let riseSetAngle = 0.833
        guard let sunriseT = sunAngleTime(riseSetAngle, guess: 6, afterNoon: false),
              let maghribT = sunAngleTime(riseSetAngle, guess: 18, afterNoon: true),
              let asrT     = asrTime(factor: asr.shadowFactor, guess: 13)
        else { return nil }  // true polar day or night — no sunrise or sunset at all

        // Above roughly 48° the sun never reaches the Fajr/Isha depression angle around
        // midsummer, so the geometric solution does not exist — London loses 64 nights a
        // year, Berlin 74. Fall back to the One-Seventh of the Night rule
        // (تقدير بسُبع الليل): split night into seven parts, give one to each end.
        let nightLength = (24 - maghribT) + sunriseT
        let seventh = nightLength / 7

        var estimated = false
        let fajrT: Double
        if let t = sunAngleTime(method.fajrAngle, guess: 5, afterNoon: false) {
            fajrT = t
        } else {
            fajrT = sunriseT - seventh
            estimated = true
        }

        // الظهر: لحظة الزوال نفسها؛ التقريب إلى الدقيقة التالية أدناه يضمن أن الوقت المعروض بعد الزوال.
        let dhuhrT = Self.midDay(jDate + 0.5)
        let ishaT: Double
        if method.ishaAngle == nil {
            ishaT = maghribT + method.ishaInterval / 60
        } else if let angle = method.ishaAngle,
                  let t = sunAngleTime(angle, guess: 19, afterNoon: true) {
            ishaT = t
        } else {
            ishaT = maghribT + seventh
            estimated = true
        }

        func stamp(_ hours: Double) -> Date {
            let local = hours + tzOffset - lng / 15
            return midnight.addingTimeInterval(local * 3600)
        }

        self.usedHighLatitudeRule = estimated
        self.date = midnight

        // التقريب إلى الدقيقة كما تفعل التقاويم الرسمية: الصلوات إلى الدقيقة التالية (احتياطًا لدخول
        // الوقت) والشروق إلى الدقيقة السابقة (احتياطًا لخروج وقت الفجر). كان العرض يقصّ الثواني
        // فيسبق الأذانُ التقويمَ بدقيقة. وفجر أم القرى الرسمي يتأخّر عن حساب 18.5° بنحو نصف دقيقة
        // (قورن بتقويم أم القرى لثلاث عشرة مدينة في 5 سبتمبر 2026: 12 من 13 مطابقة بعد هذا الضبط)،
        // والعشاء فيه 90 دقيقة بعد المغرب المقرَّب لا الخام.
        let fajrLead: TimeInterval = method == .ummAlQura ? 30 : 0
        let fajr = Self.rounded(stamp(fajrT).addingTimeInterval(fajrLead), up: true)
        let sunrise = Self.rounded(stamp(sunriseT), up: false)
        let dhuhr = Self.rounded(stamp(dhuhrT), up: true)
        let asr = Self.rounded(stamp(asrT), up: true)
        let maghrib = Self.rounded(stamp(maghribT), up: true)
        let isha = method.ishaAngle == nil ? maghrib.addingTimeInterval(method.ishaInterval * 60)
                                           : Self.rounded(stamp(ishaT), up: true)
        self.times = [.fajr: fajr, .sunrise: sunrise, .dhuhr: dhuhr, .asr: asr, .maghrib: maghrib, .isha: isha]
    }

    /// إلى الدقيقة التالية (`up`) أو السابقة؛ ما كان على رأس الدقيقة يبقى.
    private static func rounded(_ date: Date, up: Bool) -> Date {
        let t = date.timeIntervalSinceReferenceDate
        let m = up ? ceil(t / 60) : floor(t / 60)
        return Date(timeIntervalSinceReferenceDate: m * 60)
    }

    subscript(prayer: Prayer) -> Date? { times[prayer] }

    var ordered: [(prayer: Prayer, date: Date)] {
        Prayer.allCases.compactMap { p in times[p].map { (p, $0) } }
    }

    /// ثلث الليل الآخر — أفضل أوقات القيام. الليل من المغرب إلى الفجر.
    /// يحتاج فجر الغد لأن الليل يمتد عبر منتصف الليل.
    func qiyam(tomorrowFajr: Date) -> (lastThird: Date, midnight: Date, end: Date)? {
        guard let maghrib = times[.maghrib], tomorrowFajr > maghrib else { return nil }
        let night = tomorrowFajr.timeIntervalSince(maghrib)
        return (lastThird: maghrib.addingTimeInterval(night * 2 / 3),
                midnight:  maghrib.addingTimeInterval(night / 2),
                end:       tomorrowFajr)
    }

    /// The next entry in today's timetable — including الشروق, which is not a prayer.
    func next(after now: Date = Date()) -> (prayer: Prayer, date: Date)? {
        ordered.first { $0.date > now }
    }

    /// الصلاة القادمة فعليًا — يتخطّى الشروق لأنه ليس صلاة ولا يُذكَّر به.
    /// هذا ما تعرضه الشاشات والويدجت تحت عنوان «الصلاة القادمة».
    func nextPrayer(after now: Date = Date()) -> (prayer: Prayer, date: Date)? {
        ordered.first { $0.prayer.isPrayer && $0.date > now }
    }

    /// The prayer whose time has most recently entered.
    func current(at now: Date = Date()) -> (prayer: Prayer, date: Date)? {
        ordered.last { $0.date <= now }
    }

    // MARK: Astronomy

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }

    private static func fixAngle(_ a: Double) -> Double {
        let x = a.truncatingRemainder(dividingBy: 360)
        return x < 0 ? x + 360 : x
    }

    private static func fixHour(_ a: Double) -> Double {
        let x = a.truncatingRemainder(dividingBy: 24)
        return x < 0 ? x + 24 : x
    }

    static func julianDate(year: Int, month: Int, day: Int) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(Double(y) / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1))
            + Double(day) + b - 1524.5
    }

    /// Sun declination in degrees.
    private static func sunDeclination(_ jd: Double) -> Double {
        let d = jd - 2451545.0
        let g = fixAngle(357.529 + 0.98560028 * d)
        let q = fixAngle(280.459 + 0.98564736 * d)
        let l = fixAngle(q + 1.915 * sin(rad(g)) + 0.020 * sin(rad(2 * g)))
        let e = 23.439 - 0.00000036 * d
        return deg(asin(sin(rad(e)) * sin(rad(l))))
    }

    /// Local solar noon in hours.
    private static func midDay(_ jd: Double) -> Double {
        let d = jd - 2451545.0
        let g = fixAngle(357.529 + 0.98560028 * d)
        let q = fixAngle(280.459 + 0.98564736 * d)
        let l = fixAngle(q + 1.915 * sin(rad(g)) + 0.020 * sin(rad(2 * g)))
        let e = 23.439 - 0.00000036 * d
        let ra = fixHour(deg(atan2(cos(rad(e)) * sin(rad(l)), cos(rad(l)))) / 15)
        let eqt = q / 15 - ra
        return fixHour(12 - eqt)
    }
}

// MARK: - Cities

struct City: Identifiable, Hashable {
    let id: String
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    /// IANA identifier. Prayer times are meaningless without it: the maths needs the
    /// city's own UTC offset, not whatever zone the device happens to be in.
    let tz: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone { TimeZone(identifier: tz) ?? .current }

    static let all: [City] = [
        City(id: "makkah",   name: "مكة المكرمة",  country: "السعودية", latitude: 21.4225, longitude: 39.8262, tz: "Asia/Riyadh"),
        City(id: "madinah",  name: "المدينة المنورة", country: "السعودية", latitude: 24.4672, longitude: 39.6111, tz: "Asia/Riyadh"),
        // إحداثيات تقويم أم القرى المرجعية للرياض (24°38′ ش، 46°43′ ق)؛ إحداثيات مركز المدينة الأخرى كانت تُزحزح الظهر دقيقة.
        City(id: "riyadh",   name: "الرياض",       country: "السعودية", latitude: 24.633, longitude: 46.717, tz: "Asia/Riyadh"),
        City(id: "jeddah",   name: "جدة",          country: "السعودية", latitude: 21.4858, longitude: 39.1925, tz: "Asia/Riyadh"),
        City(id: "dammam",   name: "الدمام",       country: "السعودية", latitude: 26.3927, longitude: 49.9777, tz: "Asia/Riyadh"),
        City(id: "abha",     name: "أبها",         country: "السعودية", latitude: 18.2465, longitude: 42.5117, tz: "Asia/Riyadh"),
        City(id: "tabuk",    name: "تبوك",         country: "السعودية", latitude: 28.3835, longitude: 36.5662, tz: "Asia/Riyadh"),
        City(id: "buraydah", name: "بريدة",        country: "السعودية", latitude: 26.3260, longitude: 43.9750, tz: "Asia/Riyadh"),
        City(id: "hail",     name: "حائل",         country: "السعودية", latitude: 27.5114, longitude: 41.7208, tz: "Asia/Riyadh"),
        City(id: "jazan",    name: "جازان",        country: "السعودية", latitude: 16.8892, longitude: 42.5511, tz: "Asia/Riyadh"),
        // بقيّة مناطق المملكة ومحافظاتها الكبرى: من لم يجد مدينته اختار أقرب مدينةٍ
        // إليها فاختلفت مواقيته دقائق — والفجر والمغرب أشدّ ما يتأثّر بفارق الطول.
        City(id: "hofuf",    name: "الأحساء (الهفوف)", country: "السعودية", latitude: 25.3647, longitude: 49.5686, tz: "Asia/Riyadh"),
        City(id: "khobar",   name: "الخبر",        country: "السعودية", latitude: 26.2794, longitude: 50.2083, tz: "Asia/Riyadh"),
        City(id: "dhahran",  name: "الظهران",      country: "السعودية", latitude: 26.2886, longitude: 50.1150, tz: "Asia/Riyadh"),
        City(id: "qatif",    name: "القطيف",       country: "السعودية", latitude: 26.5196, longitude: 49.9962, tz: "Asia/Riyadh"),
        City(id: "jubail",   name: "الجبيل",       country: "السعودية", latitude: 27.0174, longitude: 49.6225, tz: "Asia/Riyadh"),
        City(id: "khafji",   name: "الخفجي",       country: "السعودية", latitude: 28.4390, longitude: 48.4910, tz: "Asia/Riyadh"),
        City(id: "hafar",    name: "حفر الباطن",   country: "السعودية", latitude: 28.4342, longitude: 45.9636, tz: "Asia/Riyadh"),
        City(id: "taif",     name: "الطائف",       country: "السعودية", latitude: 21.2703, longitude: 40.4158, tz: "Asia/Riyadh"),
        City(id: "yanbu",    name: "ينبع",         country: "السعودية", latitude: 24.0895, longitude: 38.0637, tz: "Asia/Riyadh"),
        City(id: "rabigh",   name: "رابغ",         country: "السعودية", latitude: 22.7986, longitude: 39.0349, tz: "Asia/Riyadh"),
        City(id: "qunfudhah", name: "القنفذة",     country: "السعودية", latitude: 19.1264, longitude: 41.0787, tz: "Asia/Riyadh"),
        City(id: "layth",    name: "الليث",        country: "السعودية", latitude: 20.1500, longitude: 40.2667, tz: "Asia/Riyadh"),
        City(id: "khamis",   name: "خميس مشيط",    country: "السعودية", latitude: 18.3000, longitude: 42.7333, tz: "Asia/Riyadh"),
        City(id: "mahayil",  name: "محايل عسير",   country: "السعودية", latitude: 18.5500, longitude: 42.0500, tz: "Asia/Riyadh"),
        City(id: "bisha",    name: "بيشة",         country: "السعودية", latitude: 19.9946, longitude: 42.5910, tz: "Asia/Riyadh"),
        City(id: "najran",   name: "نجران",        country: "السعودية", latitude: 17.4924, longitude: 44.1277, tz: "Asia/Riyadh"),
        City(id: "baha",     name: "الباحة",       country: "السعودية", latitude: 20.0129, longitude: 41.4677, tz: "Asia/Riyadh"),
        City(id: "baljurashi", name: "بلجرشي",     country: "السعودية", latitude: 19.8586, longitude: 41.5650, tz: "Asia/Riyadh"),
        City(id: "sabya",    name: "صبيا",         country: "السعودية", latitude: 17.1494, longitude: 42.6258, tz: "Asia/Riyadh"),
        City(id: "abuarish", name: "أبو عريش",     country: "السعودية", latitude: 16.9689, longitude: 42.8325, tz: "Asia/Riyadh"),
        City(id: "sakaka",   name: "سكاكا",        country: "السعودية", latitude: 29.9697, longitude: 40.2064, tz: "Asia/Riyadh"),
        City(id: "arar",     name: "عرعر",         country: "السعودية", latitude: 30.9753, longitude: 41.0381, tz: "Asia/Riyadh"),
        City(id: "qurayyat", name: "القريات",      country: "السعودية", latitude: 31.3320, longitude: 37.3428, tz: "Asia/Riyadh"),
        City(id: "unaizah",  name: "عنيزة",        country: "السعودية", latitude: 26.0844, longitude: 43.9944, tz: "Asia/Riyadh"),
        City(id: "rass",     name: "الرس",         country: "السعودية", latitude: 25.8697, longitude: 43.4972, tz: "Asia/Riyadh"),
        City(id: "majmaah",  name: "المجمعة",      country: "السعودية", latitude: 25.9039, longitude: 45.3453, tz: "Asia/Riyadh"),
        City(id: "zulfi",    name: "الزلفي",       country: "السعودية", latitude: 26.2833, longitude: 44.8000, tz: "Asia/Riyadh"),
        City(id: "kharj",    name: "الخرج",        country: "السعودية", latitude: 24.1554, longitude: 47.3346, tz: "Asia/Riyadh"),
        City(id: "dawadmi",  name: "الدوادمي",     country: "السعودية", latitude: 24.5069, longitude: 44.3925, tz: "Asia/Riyadh"),
        City(id: "shaqra",   name: "شقراء",        country: "السعودية", latitude: 25.2400, longitude: 45.2500, tz: "Asia/Riyadh"),
        City(id: "wadidawasir", name: "وادي الدواسر", country: "السعودية", latitude: 20.4667, longitude: 44.8000, tz: "Asia/Riyadh"),
        City(id: "afif",     name: "عفيف",         country: "السعودية", latitude: 23.9065, longitude: 42.9174, tz: "Asia/Riyadh"),
        City(id: "diriyah",  name: "الدرعية",      country: "السعودية", latitude: 24.7333, longitude: 46.5750, tz: "Asia/Riyadh"),
        City(id: "alula",    name: "العلا",        country: "السعودية", latitude: 26.6089, longitude: 37.9218, tz: "Asia/Riyadh"),
        City(id: "duba",     name: "ضباء",         country: "السعودية", latitude: 27.3493, longitude: 35.6960, tz: "Asia/Riyadh"),
        City(id: "neom",     name: "نيوم (شرما)",  country: "السعودية", latitude: 28.0206, longitude: 35.2340, tz: "Asia/Riyadh"),
        City(id: "kuwait",   name: "الكويت",       country: "الكويت",   latitude: 29.3759, longitude: 47.9774, tz: "Asia/Kuwait"),
        City(id: "doha",     name: "الدوحة",       country: "قطر",      latitude: 25.2854, longitude: 51.5310, tz: "Asia/Qatar"),
        City(id: "manama",   name: "المنامة",      country: "البحرين",  latitude: 26.2285, longitude: 50.5860, tz: "Asia/Bahrain"),
        City(id: "muscat",   name: "مسقط",         country: "عُمان",    latitude: 23.5859, longitude: 58.4059, tz: "Asia/Muscat"),
        City(id: "dubai",    name: "دبي",          country: "الإمارات", latitude: 25.2048, longitude: 55.2708, tz: "Asia/Dubai"),
        City(id: "abudhabi", name: "أبوظبي",       country: "الإمارات", latitude: 24.4539, longitude: 54.3773, tz: "Asia/Dubai"),
        City(id: "amman",    name: "عمّان",        country: "الأردن",   latitude: 31.9454, longitude: 35.9284, tz: "Asia/Amman"),
        City(id: "quds",     name: "القدس",        country: "فلسطين",   latitude: 31.7683, longitude: 35.2137, tz: "Asia/Hebron"),
        City(id: "cairo",    name: "القاهرة",      country: "مصر",      latitude: 30.0444, longitude: 31.2357, tz: "Africa/Cairo"),
        City(id: "khartoum", name: "الخرطوم",      country: "السودان",  latitude: 15.5007, longitude: 32.5599, tz: "Africa/Khartoum"),
        City(id: "baghdad",  name: "بغداد",        country: "العراق",   latitude: 33.3152, longitude: 44.3661, tz: "Asia/Baghdad"),
        City(id: "beirut",   name: "بيروت",        country: "لبنان",    latitude: 33.8938, longitude: 35.5018, tz: "Asia/Beirut"),
        City(id: "damascus", name: "دمشق",         country: "سوريا",    latitude: 33.5138, longitude: 36.2765, tz: "Asia/Damascus"),
        City(id: "sanaa",    name: "صنعاء",        country: "اليمن",    latitude: 15.3694, longitude: 44.1910, tz: "Asia/Aden"),
        City(id: "casa",     name: "الدار البيضاء", country: "المغرب",  latitude: 33.5731, longitude: -7.5898, tz: "Africa/Casablanca"),
        City(id: "algiers",  name: "الجزائر",      country: "الجزائر",  latitude: 36.7538, longitude: 3.0588, tz: "Africa/Algiers"),
        City(id: "tunis",    name: "تونس",         country: "تونس",     latitude: 36.8065, longitude: 10.1815, tz: "Africa/Tunis"),
        City(id: "istanbul", name: "إسطنبول",      country: "تركيا",    latitude: 41.0082, longitude: 28.9784, tz: "Europe/Istanbul"),
        City(id: "london",   name: "لندن",         country: "بريطانيا", latitude: 51.5074, longitude: -0.1278, tz: "Europe/London"),
        City(id: "paris",    name: "باريس",        country: "فرنسا",    latitude: 48.8566, longitude: 2.3522, tz: "Europe/Paris"),
        City(id: "berlin",   name: "برلين",        country: "ألمانيا",  latitude: 52.5200, longitude: 13.4050, tz: "Europe/Berlin"),
        City(id: "newyork",  name: "نيويورك",      country: "أمريكا",   latitude: 40.7128, longitude: -74.0060, tz: "America/New_York"),
        City(id: "toronto",  name: "تورنتو",       country: "كندا",     latitude: 43.6532, longitude: -79.3832, tz: "America/Toronto"),
        City(id: "kualalumpur", name: "كوالالمبور", country: "ماليزيا", latitude: 3.1390, longitude: 101.6869, tz: "Asia/Kuala_Lumpur"),
        City(id: "jakarta",  name: "جاكرتا",       country: "إندونيسيا", latitude: -6.2088, longitude: 106.8456, tz: "Asia/Jakarta")
    ]

    static func named(_ id: String) -> City? { all.first { $0.id == id } }
}
