import Foundation
import SwiftUI
import Combine

// MARK: - دفاترُ التلفاز
//
// تخزينُ tvOS الدائم خمسُمئة كيلوبايت لا غير، وكلُّ ما عداه يمحوه النظام متى شاء
// والتطبيقُ مغلق. فلا يُحفظ هنا إلا ما لا غنى عنه: اللونُ والنقشُ والقارئ.
//
// ولا مواقيتَ ولا مكان: كانا في التلفاز ثمّ حُذفا بقرار صاحبه — «قروشتها أكثر
// من نفعها». Apple TV بلا خدمات موقع، فكان على المستخدم أن يختار مدينةً من
// إحدى وسبعين قبل أن يسمع شيئًا، لأجل سطرٍ واحد فوق الشاشة. والمواقيتُ على
// جواله وساعته حيث موقعُه معه. والقرآنُ كلُّه في الحزمة (١٫٣٦ ميغابايت من
// أصل أربعة غيغابايت مسموحة) فلا يحتاج تنزيلًا ولا شبكة ليُعرض.
@MainActor
final class TVPrefs: ObservableObject {
    static let shared = TVPrefs()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let theme = "athar.tv.theme"
        static let pattern = "athar.tv.pattern"
        static let pickedTheme = "athar.tv.pickedTheme"
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
        let saved = AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .green
        theme = saved
        Theme.current = saved
        let nakch = BackgroundPattern(rawValue: defaults.string(forKey: Key.pattern) ?? "") ?? .stars
        pattern = nakch
        BackgroundPattern.current = nakch
        pickedTheme = defaults.bool(forKey: Key.pickedTheme)
    }

}
