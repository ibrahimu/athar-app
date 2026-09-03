import Foundation

/// التبويبات المتاحة في الشريط السفلي. المستخدم يختار أيّها يظهر وبأي ترتيب،
/// وكل قسم في التطبيق تبويبٌ محتمل — فمن أراد «الختمة» أو «الحديث» أسفل الشاشة وضعه.
enum AppTab: String, CaseIterable, Identifiable, Codable {
    case home, mushaf, adhkar, prayer, tasbih, hajj, qibla, hifz, recitation,
         khatmah, wird, hadith, names, ahkam, prayerLog, calendar, zakat, settings

    var id: String { rawValue }

    /// مجموعات شاشة «الأقسام» — أربع عائلات بدل قائمة واحدة طويلة.
    enum Group: String, CaseIterable, Identifiable {
        case quran, worship, knowledge, tools
        var id: String { rawValue }
        var title: String {
            switch self {
            case .quran:     return loc("القرآن")
            case .worship:   return loc("الصلاة والعبادة")
            case .knowledge: return loc("الذكر والعلم")
            case .tools:     return loc("أدوات")
            }
        }
    }

    var group: Group {
        switch self {
        case .mushaf, .recitation, .khatmah, .wird, .hifz: return .quran
        case .prayer, .qibla, .prayerLog, .hajj:            return .worship
        case .adhkar, .tasbih, .hadith, .names, .ahkam:     return .knowledge
        case .calendar, .zakat, .home, .settings:           return .tools
        }
    }

    var title: String {
        switch self {
        case .home:       return loc("today")
        case .mushaf:     return loc("mushaf")
        case .adhkar:     return loc("adhkar")
        case .prayer:     return loc("prayer")
        case .tasbih:     return loc("tasbih")
        case .hajj:       return loc("hajj")
        case .qibla:      return loc("qibla")
        case .hifz:       return loc("hifz")
        case .recitation: return loc("التلاوة")
        case .khatmah:    return loc("khatmah")
        case .wird:       return loc("الورد")
        case .hadith:     return loc("الحديث")
        case .names:      return loc("الأسماء الحسنى")
        case .ahkam:      return loc("الأحكام")
        case .prayerLog:  return loc("سجل الصلاة")
        case .calendar:   return loc("التقويم")
        case .zakat:      return loc("الزكاة")
        case .settings:   return loc("settings")
        }
    }

    var icon: String {
        switch self {
        case .home:       return "sun.horizon.fill"
        case .mushaf:     return "book.closed.fill"       // مصحف
        case .adhkar:     return "text.book.closed.fill"
        case .prayer:     return "moon.stars.fill"        // بديل — الفعلي سجّادة مخصّصة
        case .tasbih:     return "circle.hexagongrid.fill"
        case .hajj:       return "cube.fill"              // احتياط فقط — الظاهر دائمًا كعبة مرسومة
        case .qibla:      return "location.north.line.fill"
        case .hifz:       return "brain.head.profile"
        case .recitation: return "waveform"
        case .khatmah:    return "books.vertical.fill"
        case .wird:       return "bookmark.fill"
        case .hadith:     return "quote.opening"
        case .names:      return "sparkle"
        case .ahkam:      return "list.bullet.clipboard.fill"
        case .prayerLog:  return "checkmark.circle.fill"
        case .calendar:   return "calendar"
        case .zakat:      return "banknote.fill"
        case .settings:   return "gearshape.fill"
        }
    }

    /// لون القسم — تُصبغ به بطاقته في شاشة «الأقسام».
    var accentKey: String {
        switch self {
        case .home:       return "dawn"
        case .mushaf:     return "green"
        case .adhkar:     return "sea"
        case .prayer:     return "night"
        case .tasbih:     return "calm"
        case .hajj:       return "gold"
        case .qibla:      return "maghrib"
        case .hifz:       return "hifz"
        case .recitation: return "dusk"
        case .khatmah:    return "gold"
        case .wird:       return "dawn"
        case .hadith:     return "sea"
        case .names:      return "dusk"
        case .ahkam:      return "green"
        case .prayerLog:  return "night"
        case .calendar:   return "noon"
        case .zakat:      return "calm"
        case .settings:   return "green"
        }
    }

    /// سطر تعريفيّ قصير في شاشة «الأقسام».
    var blurb: String {
        switch self {
        case .home:       return loc("صلاتك القادمة وذِكرك اليوم")
        case .mushaf:     return loc("المصحف كاملًا بالرسم العثماني")
        case .adhkar:     return loc("أذكار اليوم بتخريجها")
        case .prayer:     return loc("مواقيت الصلاة وتنبيهاتها")
        case .tasbih:     return loc("مسبحة تعدّ لك أورادك")
        case .hajj:       return loc("مناسك العمرة والحج خطوةً خطوة")
        case .qibla:      return loc("اتجاه القبلة من مكانك")
        case .hifz:       return loc("حفظ الآيات ومراجعتها بمواعيدها")
        case .recitation: return loc("استمع للقرآن أو نزّله")
        case .khatmah:    return loc("ختمة القرآن بخطّة تناسبك")
        case .wird:       return loc("وردك اليومي من الآيات")
        case .hadith:     return loc("رياض الصالحين والأربعون النووية")
        case .names:      return loc("أسماء الله الحسنى وشرحها")
        case .ahkam:      return loc("الطهارة والصلاة والصيام بدليلها")
        case .prayerLog:  return loc("تتبّع صلواتك وقضاء ما فات")
        case .calendar:   return loc("التقويم الهجري ومناسبات السنّة")
        case .zakat:      return loc("حاسبة زكاة المال بلا إنترنت")
        case .settings:   return loc("تفضيلاتك وتنبيهاتك")
        }
    }

    /// التبويبات ذات الأيقونة المرسومة (لا SF): سجّادة الصلاة وكعبة الحج.
    var usesCustomIcon: Bool { self == .prayer || self == .hajj }

    /// «اليوم» ثابت دائمًا — هو مدخل التطبيق.
    var isPinned: Bool { self == .home }

    /// ما يُعرض في «الأقسام» وقوائم الاختيار: كل شيء عدا «اليوم» (ثابت) و«الإعدادات» (لها ترسها).
    static let sections: [AppTab] = allCases.filter { $0 != .home && $0 != .settings }

    static let defaultOrder: [AppTab] = [.home, .mushaf, .adhkar, .prayer, .tasbih]
    static let maxVisible = 5
}

// MARK: - بطاقات شاشة «اليوم»

/// ما يظهر في شاشة «اليوم» وبأي ترتيب — «اليوم على كيفي».
enum HomeCard: String, CaseIterable, Identifiable, Codable {
    case prayer, stats, suggestion, dailyDhikr, dailyHadith, occasion, quickGrid, sections, sadaqah

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prayer:      return loc("الصلاة القادمة")
        case .stats:       return loc("أرقامي")
        case .suggestion:  return loc("وقتها الآن")
        case .dailyDhikr:  return loc("ذكر اليوم")
        case .dailyHadith: return loc("حديث اليوم")
        case .occasion:    return loc("المناسبة القادمة")
        case .quickGrid:   return loc("ابدأ الآن")
        case .sections:    return loc("أقسام أخرى")
        case .sadaqah:     return loc("الصدقة")
        }
    }

    var icon: String {
        switch self {
        case .prayer:      return "moon.stars.fill"
        case .stats:       return "chart.bar.fill"
        case .suggestion:  return "clock.badge.checkmark.fill"
        case .dailyDhikr:  return "text.quote"
        case .dailyHadith: return "quote.opening"
        case .occasion:    return "calendar.badge.clock"
        case .quickGrid:   return "square.grid.2x2.fill"
        case .sections:    return "rectangle.grid.2x2.fill"
        case .sadaqah:     return "heart.fill"
        }
    }

    static let defaultOrder: [HomeCard] = [.prayer, .stats, .suggestion, .dailyDhikr, .dailyHadith,
                                           .occasion, .quickGrid, .sections, .sadaqah]
}

extension AtharStore {
    private enum TKey {
        static let tabs       = "athar.tabs.visible"
        static let homeCards  = "athar.home.cards"
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

    /// بطاقات «اليوم» الظاهرة بترتيب المستخدم. المخزون القديم (قبل إضافة بطاقات جديدة)
    /// لا يُخفيها: كل بطاقة لم تُذكر في المخزون ولم تُخفَ صراحةً تُلحق في موضعها الافتراضي.
    var homeCards: [HomeCard] {
        get {
            guard let raw = defaults.stringArray(forKey: TKey.homeCards) else { return HomeCard.defaultOrder }
            let known = raw.compactMap(HomeCard.init(rawValue:))
            let hidden = Set(defaults.stringArray(forKey: TKey.homeCards + ".hidden") ?? [])
            var result = known
            for card in HomeCard.defaultOrder where !result.contains(card) && !hidden.contains(card.rawValue) {
                result.append(card)
            }
            return result
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: TKey.homeCards)
            let hidden = HomeCard.allCases.filter { !newValue.contains($0) }.map(\.rawValue)
            defaults.set(hidden, forKey: TKey.homeCards + ".hidden")
            objectWillChange.send()
        }
    }

    var hiddenHomeCards: [HomeCard] {
        HomeCard.defaultOrder.filter { !homeCards.contains($0) }
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
