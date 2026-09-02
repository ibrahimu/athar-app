import Foundation

/// مزامنة تقدّم المستخدم وإعداداته عبر أجهزته باستخدام iCloud Key‑Value Store.
/// خفيفة ومجانية: تُرسل كل مفاتيح «athar.*» إلى السحابة وتسحب تغييرات الأجهزة الأخرى.
/// آخر كاتب يفوز — كافٍ لتقدّم أذكار وحفظ وختمة وإعدادات.
final class CloudSync {
    static let shared = CloudSync()

    private let kv = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults(suiteName: AtharStore.appGroup) ?? .standard
    private let prefix = "athar."

    /// يُستدعى عند وصول تغييرات من جهاز آخر — ليعيد المتجر بناء الواجهة.
    var onExternalChange: (() -> Void)?

    private init() {}

    func start() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(externalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv)
        kv.synchronize()
        pull()   // عند الإقلاع: خذ أحدث حالة من السحابة
    }

    /// السحابة ← المحلّي (عند الإقلاع أو وصول تغيير خارجي).
    func pull() {
        for (k, v) in kv.dictionaryRepresentation where k.hasPrefix(prefix) {
            defaults.set(v, forKey: k)
        }
    }

    /// المحلّي ← السحابة (عند الخلفية/التغيير) — يرفع كل مفاتيح athar.*.
    func push() {
        for (k, v) in defaults.dictionaryRepresentation() where k.hasPrefix(prefix) {
            kv.set(v, forKey: k)
        }
        kv.synchronize()
    }

    @objc private func externalChange(_ note: Notification) {
        pull()
        DispatchQueue.main.async { [weak self] in self?.onExternalChange?() }
    }
}
