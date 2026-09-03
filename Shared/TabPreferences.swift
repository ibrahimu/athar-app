import Foundation

/// التبويبات المتاحة في الشريط السفلي. المستخدم يختار أيّها يظهر وبأي ترتيب.
enum AppTab: String, CaseIterable, Identifiable, Codable {
    case home, mushaf, adhkar, prayer, tasbih, hajj, qibla, hifz, recitation, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return loc("today")
        case .mushaf:   return loc("mushaf")
        case .adhkar:   return loc("adhkar")
        case .prayer:   return loc("prayer")
        case .tasbih:   return loc("tasbih")
        case .hajj:     return loc("hajj")
        case .qibla:    return loc("qibla")
        case .hifz:     return loc("hifz")
        case .recitation: return loc("التلاوة")
        case .settings: return loc("settings")
        }
    }

    var icon: String {
        switch self {
        case .home:     return "sun.horizon.fill"
        case .mushaf:   return "book.closed.fill"       // مصحف
        case .adhkar:   return "text.book.closed.fill"
        case .prayer:   return "moon.stars.fill"        // بديل — الفعلي سجّادة مخصّصة
        case .tasbih:   return "circle.hexagongrid.fill"
        case .hajj:     return "cube.fill"              // احتياط فقط — الظاهر دائمًا كعبة مرسومة
        case .qibla:    return "location.north.line.fill"
        case .hifz:     return "brain.head.profile"
        case .recitation: return "waveform"
        case .settings: return "gearshape.fill"
        }
    }

    /// التبويبات ذات الأيقونة المرسومة (لا SF): سجّادة الصلاة وكعبة الحج.
    var usesCustomIcon: Bool { self == .prayer || self == .hajj }

    /// «اليوم» ثابت دائمًا — هو مدخل التطبيق.
    var isPinned: Bool { self == .home }

    static let defaultOrder: [AppTab] = [.home, .mushaf, .adhkar, .prayer, .tasbih]
    static let maxVisible = 5
}

extension AtharStore {
    private enum TKey {
        static let tabs       = "athar.tabs.visible"
        static let theme      = "athar.theme"
        static let appearance = "athar.appearance"
        static let language   = "athar.language"
        static let bgPattern  = "athar.bgPattern"
        static let unifyIcons = "athar.unifyIcons"
    }

    /// التبويبات الظاهرة بترتيب المستخدم.
    var visibleTabs: [AppTab] {
        get {
            guard let raw = defaults.stringArray(forKey: TKey.tabs) else { return AppTab.defaultOrder }
            let tabs = raw.compactMap(AppTab.init(rawValue:))
            guard !tabs.isEmpty else { return AppTab.defaultOrder }
            // «اليوم» لا يُحذف أبدًا.
            return tabs.contains(.home) ? tabs : [.home] + tabs
        }
        set {
            var v = newValue
            if !v.contains(.home) { v.insert(.home, at: 0) }
            defaults.set(Array(v.prefix(AppTab.maxVisible)).map(\.rawValue), forKey: TKey.tabs)
            objectWillChange.send()
        }
    }

    var hiddenTabs: [AppTab] {
        AppTab.allCases.filter { !visibleTabs.contains($0) }
    }

    var appTheme: AppTheme {
        get { AppTheme(rawValue: defaults.string(forKey: TKey.theme) ?? "") ?? .green }
        set {
            defaults.set(newValue.rawValue, forKey: TKey.theme)
            Theme.current = newValue
            objectWillChange.send()
        }
    }

    var appearance: AppearanceMode {
        get { AppearanceMode(rawValue: defaults.string(forKey: TKey.appearance) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: TKey.appearance); objectWillChange.send() }
    }

    /// لغة الواجهة — النص الشرعي يبقى عربيًا دائمًا.
    var appLanguage: AppLanguage {
        get { AppLanguage(rawValue: defaults.string(forKey: TKey.language) ?? "") ?? .system }
        set { defaults.set(newValue.rawValue, forKey: TKey.language); objectWillChange.send() }
    }

    /// توحيد ألوان الأيقونات على اللون المميّز (بدل ألوان الأقسام المتعدّدة).
    var unifyIcons: Bool {
        get { defaults.bool(forKey: TKey.unifyIcons) }
        set {
            defaults.set(newValue, forKey: TKey.unifyIcons)
            Theme.unifyIcons = newValue
            objectWillChange.send()
        }
    }

    /// نقش خلفية التطبيق.
    var backgroundPattern: BackgroundPattern {
        get { BackgroundPattern(rawValue: defaults.string(forKey: TKey.bgPattern) ?? "") ?? .stars }
        set {
            defaults.set(newValue.rawValue, forKey: TKey.bgPattern)
            BackgroundPattern.current = newValue
            objectWillChange.send()
        }
    }

    /// تُستدعى مرة عند الإقلاع لمزامنة الطابع والنقش مع الحالة العامة.
    func applyStoredTheme() {
        Theme.current = appTheme
        BackgroundPattern.current = backgroundPattern
    }
}
