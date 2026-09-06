import Foundation

// MARK: - مزامنة التفضيلات والمفضّلة عبر iCloud (مخزن القيم الصغير)
//
// محاولة سابقة بمزامنة كاملة أفقدت بيانات؛ فهذه تقتصر على ما يُؤمَن فقدانه:
// التفضيلات والمفضّلة والعلامات والتظليل — لا العدّادات ولا الإحصاءات.
// آخر كاتبٍ يغلب (سياسة المخزن نفسه)، والمفتاح يُنسخ كما هو إلى التفضيلات المحلية.

protocol CloudKeyValueStorage: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}
extension NSUbiquitousKeyValueStore: CloudKeyValueStorage {}

final class CloudKV {
    static let shared = CloudKV()
    private let kv: CloudKeyValueStorage
    private let notifications: NotificationCenter
    private var observer: NSObjectProtocol?
    private var pulling = false

    /// المفاتيح المتزامنة — قيمٌ صغيرة يُحتمل فقدانها بلا ضرر.
    static let keys: [String] = [
        "athar.tabs.visible", "athar.home.cards", "athar.home.cards.hidden",
        "athar.theme", "athar.appearance", "athar.bgPattern", "athar.unifyIcons",
        "athar.hadith.favorites", "athar.bookmarks", "athar.highlights",
        "athar.stopMark", "athar.lastRead",
        "athar.athanSound", "athar.preAthanMinutes", "athar.iqamahMinutes",
        "athar.readingTheme", "athar.readingMode", "athar.mushafFontScale", "athar.fontScale",
        "athar.tasbihPhrase", "athar.tasbihTarget", "athar.secondaryCityId",
    ]

    init(kv: CloudKeyValueStorage = NSUbiquitousKeyValueStore.default, notifications: NotificationCenter = .default) {
        self.kv = kv; self.notifications = notifications
    }

    deinit { if let observer { notifications.removeObserver(observer) } }

    /// يُشغَّل عند الإقلاع حين يفعّل المستخدم المزامنة: يسحب ما في السحابة، ثم يراقب تغيّرها.
    func start(defaults: UserDefaults, onChange: @escaping () -> Void) {
        guard observer == nil else { return }
        observer = notifications.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv, queue: .main) { [weak self] n in
            guard let self, self.observer != nil else { return }
            let changed = (n.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]) ?? Self.keys
            // لا نحذف قيمة محلية لأن iCloud لا يعرفها: عند تبديل الحساب أو قبل أول تنزيل
            // تكون المفاتيح غائبة كلها، وحذفها يمسح المفضّلة على كل الأجهزة.
            self.pull(keys: changed, into: defaults, removeMissing: false)
            onChange()
        }
        kv.synchronize()
        pull(keys: Self.keys, into: defaults)
        onChange()
    }

    func stop() {
        if let o = observer { notifications.removeObserver(o); observer = nil }
    }

    /// يدفع المفاتيح المحلية إلى السحابة (عند الذهاب للخلفية وعند كل تغيير مهم).
    func push(from defaults: UserDefaults) {
        guard observer != nil, !pulling else { return }
        for key in Self.keys {
            let local = defaults.object(forKey: key)
            if let local, Self.isPlist(local) { kv.set(local, forKey: key) }
            else if local == nil { kv.removeObject(forKey: key) }
        }
        kv.synchronize()
    }

    private func pull(keys: [String], into defaults: UserDefaults, removeMissing: Bool = false) {
        pulling = true; defer { pulling = false }
        for key in keys where Self.keys.contains(key) {
            if let remote = kv.object(forKey: key) { defaults.set(remote, forKey: key) }
            else if removeMissing { defaults.removeObject(forKey: key) }
        }
    }

    private static func isPlist(_ v: Any) -> Bool {
        v is String || v is NSNumber || v is [String] || v is [String: String] || v is Data || v is Date || v is [Any] || v is [String: Any]
    }
}

extension AtharStore {
    private static let cloudKey = "athar.cloudSync"

    /// مزامنة التفضيلات والمفضّلة عبر iCloud — اختيارية ومطفأة افتراضيًّا.
    var cloudSyncEnabled: Bool {
        get { defaults.bool(forKey: Self.cloudKey) }
        set {
            defaults.set(newValue, forKey: Self.cloudKey)
            objectWillChange.send()
            if newValue { startCloudSync() } else { CloudKV.shared.stop() }
        }
    }

    func startCloudSync() {
        guard cloudSyncEnabled else { return }
        CloudKV.shared.start(defaults: defaults) { [weak self] in
            self?.applyStoredTheme()
            self?.objectWillChange.send()
        }
    }

    func pushCloudSync() {
        guard cloudSyncEnabled else { return }
        CloudKV.shared.push(from: defaults)
    }
}
