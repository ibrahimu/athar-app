import Foundation

// MARK: - وضع السفر
//
// ما يصنعه هذا الملف وما لا يصنعه:
//
// يصنع: يُبدّل ما يُعرض ويُنبَّه به — ركعتان مكان أربع في عرض الصلوات، وأذانٌ
// واحدٌ للمجموعتين مكان اثنين. فهو إعدادُ عرضٍ وجدولة، يُشغّله صاحبه بيده.
//
// ولا يصنع: لا يُفتي ولا يقيس مسافةً ولا يقرّر أنّ صاحبه مسافرٌ شرعًا. شروطُ
// القصر والجمع ومسافتُهما أحكامٌ لأهل العلم، والتطبيق لا يحكم بها على أحد —
// كما لا تُفتي حاسبةُ الزكاة. ولذلك لا يُشغَّل من نفسه أبدًا: تبدُّلُ المنطقة
// الزمنية يفتح له بابًا يُعرض، والضغطةُ ضغطةُ صاحبه.
//
// ودليلُه المعروض آيةُ القصر — تُحلّ من quran.json بمرجعها ولا تُكتب هنا.

/// كيف تُجمع المجموعتان — أو لا تُجمعان.
enum TravelJoin: String, CaseIterable, Identifiable, Codable {
    /// قصرٌ بلا جمع: كلُّ صلاةٍ في وقتها.
    case none
    /// جمع تقديم: العصر مع الظهر، والعشاء مع المغرب.
    case advance
    /// جمع تأخير: الظهر مع العصر، والمغرب مع العشاء.
    case delay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:    return loc("بلا جمع")
        case .advance: return loc("جمع تقديم")
        case .delay:   return loc("جمع تأخير")
        }
    }

    var detail: String {
        switch self {
        case .none:    return loc("كل صلاة في وقتها، ركعتين")
        case .advance: return loc("العصر مع الظهر، والعشاء مع المغرب")
        case .delay:   return loc("الظهر مع العصر، والمغرب مع العشاء")
        }
    }

    /// الصلاة التي لا يُؤذَّن لها وحدها لأنها تُصلَّى مع أختها.
    /// ومع «بلا جمع» لا تُطوى صلاةٌ: `nil` لكلّ فرض.
    func merged(into prayer: Prayer) -> Bool {
        switch (self, prayer) {
        case (.advance, .asr), (.advance, .isha):     return true
        case (.delay,   .dhuhr), (.delay, .maghrib):  return true
        default:                                      return false
        }
    }

    /// النداءُ الجامع: أيُّ صلاتين تُذكران معًا عند هذا الفرض.
    func pair(at prayer: Prayer) -> (first: Prayer, second: Prayer)? {
        switch (self, prayer) {
        case (.advance, .dhuhr), (.delay, .asr):       return (.dhuhr, .asr)
        case (.advance, .maghrib), (.delay, .isha):    return (.maghrib, .isha)
        default:                                       return nil
        }
    }
}

enum Travel {
    /// آيةُ القصر: النساء ١٠١ — بمرجعها لا بمتنها.
    static let proof = AyahRef(surah: 4, ayah: 101)

    /// ما يُقال تحت الخيارات: التطبيق يعرض ولا يُفتي — كما في حاسبة الزكاة.
    static let disclaimer = loc("هذا عرضٌ يعينك في سفرك، وليس فتوى؛ وشروط القصر والجمع ومسافتهما يرجع فيها إلى أهل العلم.")

    /// عددُ ركعات الفرض في السفر وفي الحضر.
    /// الفجرُ ركعتان والمغربُ ثلاث لا تُقصران — والقصرُ في الرباعيّة وحدها.
    static func rakaat(_ prayer: Prayer, travelling: Bool) -> Int? {
        switch prayer {
        case .fajr:    return 2
        case .maghrib: return 3
        case .dhuhr, .asr, .isha: return travelling ? 2 : 4
        case .sunrise: return nil
        }
    }
}

// MARK: - المخزن

extension AtharStore {
    private enum TrKey {
        static let mode  = "athar.travel.mode"
        static let join  = "athar.travel.join"
        static let since = "athar.travel.since"
        static let place = "athar.travel.place"
    }

    /// وضع السفر يعمل الآن؟ لا يُشغَّل إلا بيد صاحبه.
    var travelMode: Bool {
        get { defaults.bool(forKey: TrKey.mode) }
        set {
            defaults.set(newValue, forKey: TrKey.mode)
            if newValue {
                defaults.set(Date(), forKey: TrKey.since)
                defaults.set(placeName, forKey: TrKey.place)
            } else {
                defaults.removeObject(forKey: TrKey.since)
                defaults.removeObject(forKey: TrKey.place)
            }
            objectWillChange.send()
        }
    }

    var travelJoin: TravelJoin {
        get { TravelJoin(rawValue: defaults.string(forKey: TrKey.join) ?? "") ?? .none }
        set { defaults.set(newValue.rawValue, forKey: TrKey.join); objectWillChange.send() }
    }

    /// متى شُغّل، والمكانُ الذي شُغّل فيه — يُعرضان في اللافتة ليعرف متى نسيه مفتوحًا.
    var travelSince: Date? { defaults.object(forKey: TrKey.since) as? Date }
    var travelPlace: String? { defaults.string(forKey: TrKey.place) }

    /// كم يومًا مضى على تشغيله (صفرٌ ليومه). من نسيه أسابيع يُقال له.
    var travelDays: Int {
        guard let since = travelSince else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: since),
                                  to: cal.startOfDay(for: Date())).day ?? 0
    }

    /// بدّل المكانَ وقد كان مسافرًا: يُسأل، ولا يُطفأ من تلقاء نفسه — قد يكون
    /// انتقل من مدينةٍ إلى مدينةٍ وهو في سفره بعدُ.
    func rakaatText(_ prayer: Prayer) -> String? {
        guard let n = Travel.rakaat(prayer, travelling: travelMode) else { return nil }
        return n == 2 ? loc("ركعتان") : (n == 3 ? loc("ثلاث ركعات") : loc("أربع ركعات"))
    }
}
