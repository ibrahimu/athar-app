import Foundation

/// التبويبات المتاحة في الشريط السفلي. المستخدم يختار أيّها يظهر وبأي ترتيب.
enum AppTab: String, CaseIterable, Identifiable, Codable {
    case home, mushaf, adhkar, prayer, tasbih, hajj, qibla, hifz, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:     return "اليوم"
        case .mushaf:   return "المصحف"
        case .adhkar:   return "الأذكار"
        case .prayer:   return "الصلاة"
        case .tasbih:   return "المسبحة"
        case .hajj:     return "الحج والعمرة"
        case .qibla:    return "القبلة"
        case .hifz:     return "الحفظ"
        case .settings: return "الإعدادات"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "sun.horizon.fill"
        case .mushaf:   return "book.pages.fill"
        case .adhkar:   return "text.book.closed.fill"
        case .prayer:   return "moon.stars.fill"
        case .tasbih:   return "circle.hexagongrid.fill"
        case .hajj:     return "building.columns.fill"
        case .qibla:    return "location.north.line.fill"
        case .hifz:     return "brain.head.profile"
        case .settings: return "gearshape.fill"
        }
    }

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

    /// تُستدعى مرة عند الإقلاع لمزامنة الطابع مع Theme.
    func applyStoredTheme() { Theme.current = appTheme }
}
