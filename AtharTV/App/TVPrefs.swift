import Foundation
import SwiftUI
import Combine

// MARK: - دفاترُ التلفاز
//
// تخزينُ tvOS الدائم خمسُمئة كيلوبايت لا غير، وكلُّ ما عداه يمحوه النظام متى شاء
// والتطبيقُ مغلق. فلا يُحفظ هنا إلا ما لا غنى عنه: المدينةُ التي تُحسب بها
// المواقيت، والمصدرُ الأخير، والقارئ. والقرآنُ كلُّه في الحزمة (١٫٣٦ ميغابايت من
// أصل أربعة غيغابايت مسموحة) فلا يحتاج تنزيلًا ولا شبكة ليُعرض.
@MainActor
final class TVPrefs: ObservableObject {
    static let shared = TVPrefs()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let city = "athar.tv.city"
        static let method = "athar.tv.method"
        static let asr = "athar.tv.asr"
        static let theme = "athar.tv.theme"
        static let pattern = "athar.tv.pattern"
        static let pickedTheme = "athar.tv.pickedTheme"
    }

    /// لا مدينةَ افتراضية. الأجهزةُ المحمولة تسأل الموقعَ فتعرف، وApple TV لا
    /// خدماتِ موقعٍ فيها أصلًا — فالسؤالُ يُطرح مرّةً صراحةً، ولا يُخمَّن.
    /// ومدينةٌ خاطئة في المواقيت خطأٌ في الدين لا في الواجهة.
    @Published var city: City? {
        didSet { defaults.set(city?.id, forKey: Key.city) }
    }

    @Published var method: CalculationMethod {
        didSet { defaults.set(method.rawValue, forKey: Key.method) }
    }

    @Published var asr: AsrMethod {
        didSet { defaults.set(asr.rawValue, forKey: Key.asr) }
    }

    /// الطابع. `Theme.current` متغيّرٌ ساكن يقرأه كلُّ لونٍ في الملفّات المشتركة،
    /// فيُضبط هنا عند كل تغيير — ولا `AtharStore` في التلفاز يفعلها عنّا.
    @Published var theme: AppTheme {
        didSet {
            Theme.current = theme
            defaults.set(theme.rawValue, forKey: Key.theme)
        }
    }

    /// النقش. كالطابع: متغيّرٌ ساكن تقرؤه الأرض، فيُضبط عند كل تغيير.
    @Published var pattern: BackgroundPattern {
        didSet {
            BackgroundPattern.current = pattern
            defaults.set(pattern.rawValue, forKey: Key.pattern)
        }
    }

    /// هل اختار صاحبُ الجهاز لونَه؟ يُسأل مرّةً في أوّل تشغيل ثمّ لا يُسأل.
    @Published var pickedTheme: Bool {
        didSet { defaults.set(pickedTheme, forKey: Key.pickedTheme) }
    }

    private init() {
        let id = defaults.string(forKey: Key.city)
        city = City.all.first { $0.id == id }
        method = CalculationMethod(rawValue: defaults.string(forKey: Key.method) ?? "") ?? .ummAlQura
        asr = AsrMethod(rawValue: defaults.string(forKey: Key.asr) ?? "") ?? .standard
        let saved = AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .green
        theme = saved
        Theme.current = saved
        let nakch = BackgroundPattern(rawValue: defaults.string(forKey: Key.pattern) ?? "") ?? .stars
        pattern = nakch
        BackgroundPattern.current = nakch
        pickedTheme = defaults.bool(forKey: Key.pickedTheme)
    }

    /// مواقيتُ اليوم في المدينة المختارة، بمنطقتها هي لا بمنطقة الجهاز:
    /// تلفازٌ في الرياض قد يكون على توقيت آخر، والحسابُ فلكيٌّ لا يقبل التقريب.
    func times(on date: Date = Date()) -> PrayerTimes? {
        guard let city else { return nil }
        return PrayerTimes(date: date, coordinate: city.coordinate, timeZone: city.timeZone,
                           method: method, asr: asr)
    }

    /// الصلاةُ القادمة، ولو كانت فجرَ الغد.
    func upcoming(now: Date = Date()) -> (prayer: Prayer, date: Date)? {
        guard let city else { return nil }
        if let n = times(on: now)?.next(after: now) { return n }
        let tomorrow = now.addingTimeInterval(24 * 3600)
        return times(on: tomorrow)?.next(after: now)
    }
}
