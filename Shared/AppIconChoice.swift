import Foundation

// MARK: - أيقونة التطبيق
//
// الأيقونة على الشاشة الرئيسية أوّل ما يُرى من التطبيق وآخر ما يُنسى، وليس كل أحدٍ
// يرضى الأخضر. فتُعرض عليه القطرة نفسها بأوراق الطوابع — الشكل واحد واللون له.

enum AppIconChoice: String, CaseIterable, Identifiable {
    /// الأصل: أيقونة المتجر بحرفها. اسمها في مجموعة الأصول «AppIcon» ولا اسم بديل لها
    /// عند النظام — ولذلك تُمثَّل بـnil في `setAlternateIconName`.
    case original
    case night, sand, sea, rose, indigo, charcoal, plum, olive, mint, honey, violet

    var id: String { rawValue }

    /// اسم مجموعة الأصول — وهو ما يُسلَّم للنظام، عدا الأصل فبلا اسم.
    var assetName: String? { self == .original ? nil : "AppIcon-" + rawValue }

    /// المعاينة داخل التطبيق تُقرأ من الحزمة بالاسم الكامل، والأصل باسمه هو.
    var previewAsset: String { self == .original ? "AppIcon-1024" : "AppIcon-" + rawValue + "-1024" }

    var title: String {
        switch self {
        case .original: return loc("الأصل")
        case .night:    return loc("ليلي")
        case .sand:     return loc("رملي")
        case .sea:      return loc("بحري")
        case .rose:     return loc("وردي")
        case .indigo:   return loc("نيلي")
        case .charcoal: return loc("فحمي")
        case .plum:     return loc("برقوقي")
        case .olive:    return loc("زيتوني")
        case .mint:     return loc("نعناعي")
        case .honey:    return loc("عسلي")
        case .violet:   return loc("بنفسجي")
        }
    }

    /// ما يوافق طابع التطبيق الحالي — يُقترح على من بدّل طابعه ولم يبدّل أيقونته.
    /// المطابقة بالاسم الخام وحدها كانت تُسقط طابعين من اثني عشر إلى «الأصل» صامتةً:
    /// «عسليّ» (amber) وأيقونته موجودة باسم honey، و«إردوازيّ» (slate) ولا أيقونة باسمه.
    /// فيَعِد «تتبع الطابع» بما لا يقع، ويُلحّ على صاحبهما بالعودة إلى الخضراء.
    static func matching(_ theme: AppTheme) -> AppIconChoice {
        switch theme {
        case .amber: return .honey
        case .slate: return .charcoal
        default:     return AppIconChoice(rawValue: theme.rawValue) ?? .original
        }
    }

    init(assetName: String?) {
        guard let assetName, assetName.hasPrefix("AppIcon-"),
              let c = AppIconChoice(rawValue: String(assetName.dropFirst("AppIcon-".count)))
        else { self = .original; return }
        self = c
    }
}

// MARK: - كيف تُختار الأيقونة

/// إمّا أن تمشي الأيقونة مع الطابع فلا يُشغل بها المستخدم باله، وإمّا أن يخصّها باختيار.
/// المفتاح في دفاتر التطبيق لا في النظام: النظام يحفظ الأيقونة الحاضرة، لا سببَ حضورها.
enum AppIconMode: String, CaseIterable, Identifiable {
    case theme, custom
    var id: String { rawValue }
    var title: String { self == .theme ? loc("تتبع الطابع") : loc("مستقلة") }
}

extension AtharStore {
    private static let iconModeKey = "athar.appIconMode"

    var appIconMode: AppIconMode {
        get { AppIconMode(rawValue: defaults.string(forKey: Self.iconModeKey) ?? "") ?? .custom }
        set { defaults.set(newValue.rawValue, forKey: Self.iconModeKey); objectWillChange.send() }
    }
}
