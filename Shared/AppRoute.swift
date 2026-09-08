import Foundation

/// وجهة داخل التطبيق يطلبها بحث iOS أو اختصار الأيقونة أو Siri.
enum AppRoute: Equatable, Identifiable {
    var id: String {
        switch self {
        case .tab(let t): return "tab:\(t.rawValue)"
        case .surah(let n): return "surah:\(n)"
        case .name(let n): return "name:\(n)"
        case .ahkam(let t, let i): return "ahkam:\(t):\(i)"
        case .adhkar(let c): return "adhkar:\(c)"
        }
    }

    case tab(AppTab)
    case surah(Int)
    case name(Int)
    case ahkam(topic: String, item: String)
    case adhkar(String)

    /// من معرّف Spotlight «surah:18» ونحوه.
    init?(spotlightId id: String) {
        let parts = id.split(separator: ":").map(String.init)
        guard let kind = parts.first else { return nil }
        switch kind {
        case "surah": guard parts.count == 2, let n = Int(parts[1]) else { return nil }; self = .surah(n)
        case "name":  guard parts.count == 2, let n = Int(parts[1]) else { return nil }; self = .name(n)
        case "ahkam": guard parts.count == 3 else { return nil }; self = .ahkam(topic: parts[1], item: parts[2])
        case "adhkar": guard parts.count == 2 else { return nil }; self = .adhkar(parts[1])
        case "tab":   guard parts.count == 2, let t = AppTab(rawValue: parts[1]) else { return nil }; self = .tab(t)
        default: return nil
        }
    }

    /// من رابط الودجة athar://open/<tab> أو اختصار الأيقونة.
    init?(url: URL) {
        guard url.scheme == "athar" else { return nil }
        let path = url.host.map { [$0] + url.pathComponents.filter { $0 != "/" } } ?? url.pathComponents.filter { $0 != "/" }
        guard path.first == "open", path.count >= 2 else { return nil }
        // الأطول أوّلًا: «adhkar» اسم تبويبٍ أيضًا، فلو سُئل التبويب قبله لابتلع
        // «adhkar/morning» وأنزل صاحب الودجة على رأس الأذكار يبحث عمّا كان يراه.
        // (هذه وجهات يعرفها الجذر أصلًا من بحث iOS — وإنما فُتح لها باب الروابط.)
        if path.count >= 3 {
            if path[1] == "surah", let n = Int(path[2]) { self = .surah(n); return }
            if path[1] == "adhkar" { self = .adhkar(path[2]); return }
            if path[1] == "name", let n = Int(path[2]) { self = .name(n); return }
        }
        // «الجمعة» شاشةٌ تدفعها بطاقةُ «اليوم»، لا تبويبٌ في الشريط ولا وجهةٌ قائمة
        // بذاتها — فطريقها هو طريقها في التطبيق نفسه: يُطلب «اليوم» ويُرفع لها علَمٌ
        // تستهلكه شاشته فتدفع الشاشة. وهي قبل سؤال التبويب كسائر المسارات الأخصّ.
        if path[1] == "friday" { AtharStore.shared.pendingFriday = true; self = .tab(.home); return }
        if let t = AppTab(rawValue: path[1]) { self = .tab(t); return }
        return nil
    }
}

private var pendingRoutes: [ObjectIdentifier: AppRoute] = [:]
private var pendingFridays: Set<ObjectIdentifier> = []
extension AtharStore {
    /// وجهة معلّقة يستهلكها الجذر — في الذاكرة لا في التفضيلات.
    var pendingRoute: AppRoute? {
        get { pendingRoutes[ObjectIdentifier(self)] }
        set { pendingRoutes[ObjectIdentifier(self)] = newValue; objectWillChange.send() }
    }

    /// طلبٌ معلّق لفتح «الجمعة» تستهلكه شاشة «اليوم» مرّة واحدة — في الذاكرة
    /// كأخيه، فالطلب يموت مع الجلسة ولا يفتح الشاشة في إقلاعٍ بعد أسبوع.
    var pendingFriday: Bool {
        get { pendingFridays.contains(ObjectIdentifier(self)) }
        set {
            if newValue { pendingFridays.insert(ObjectIdentifier(self)) }
            else { pendingFridays.remove(ObjectIdentifier(self)) }
            objectWillChange.send()
        }
    }
}
