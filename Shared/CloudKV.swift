import Foundation

// MARK: - مزامنة التفضيلات والمفضّلة عبر iCloud (مخزن القيم الصغير)
//
// محاولة سابقة بمزامنة كاملة أفقدت بيانات؛ فهذه تقتصر على ما يُؤمَن فقدانه:
// التفضيلات والمفضّلة والعلامات والتظليل — لا العدّادات ولا الإحصاءات.
//
// وفي المفاتيح المفردة آخرُ كاتبٍ يغلب (سياسة المخزن نفسه). أمّا ما كان قائمةً
// أو معجمًا — العلامات والتظليل والمفضّلة والتدبّرات — فالنسخ الكامل عليها جنايةٌ:
// جهازان لكلٍّ منهما ما ليس عند الآخر، فيدفع أحدهما فيمحو ما عند صاحبه. فهذه
// تُدمج اتحادًا لا استبدالًا، والتدبّرات أشدّ: لها أرشيف نسخٍ برؤوسٍ وشواهد حذف.

protocol CloudKeyValueStorage: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    func removeObject(forKey key: String)
    @discardableResult func synchronize() -> Bool
}
extension NSUbiquitousKeyValueStore: CloudKeyValueStorage {}

// MARK: - دمج القوائم والمعاجم

/// دوالّ خالصة لا تمسّ تخزينًا ولا سحابة — تُقرأ وتُختبر وحدها.
enum CloudMerge {

    /// اتحاد قائمة نصوص: ترتيب صاحب الأولوية أوّلًا، ثم ما انفرد به الآخر.
    static func strings(_ preferred: Any?, over other: Any?) -> [String]? {
        let a = preferred as? [String] ?? []
        let b = other as? [String] ?? []
        guard !(a.isEmpty && b.isEmpty) else { return nil }
        var seen = Set(a)
        var out = a
        for s in b where !seen.contains(s) { seen.insert(s); out.append(s) }
        return out
    }

    /// اتحاد علامات المصحف. العلامة مجموعةٌ لا سجلّ، والاتحاد أمينُ الدمج فيها:
    /// علامةٌ تعود بعد رفعها أهون من مئة علامة تُمحى دفعةً واحدة.
    static func refs(_ preferred: Any?, over other: Any?) -> Data? {
        let a = decodeRefs(preferred), b = decodeRefs(other)
        guard !(a.isEmpty && b.isEmpty) else { return nil }
        return try? JSONEncoder().encode(a.union(b).sorted())
    }

    /// اتحاد معجم التظليل: كل آيةٍ انفرد بها طرفٌ تبقى، والمشتركةُ لصاحب الأولوية
    /// — آخر من زامن يغلب في لونها وحدها، لا في القائمة كلّها.
    static func map(_ preferred: Any?, over other: Any?) -> Data? {
        let a = decodeMap(preferred), b = decodeMap(other)
        guard !(a.isEmpty && b.isEmpty) else { return nil }
        var merged = b
        for (k, v) in a { merged[k] = v }
        return try? JSONEncoder().encode(merged)
    }

    private static func decodeRefs(_ value: Any?) -> Set<AyahRef> {
        guard let d = value as? Data,
              let v = try? JSONDecoder().decode([AyahRef].self, from: d) else { return [] }
        return Set(v)
    }

    private static func decodeMap(_ value: Any?) -> [String: String] {
        guard let d = value as? Data,
              let v = try? JSONDecoder().decode([String: String].self, from: d) else { return [:] }
        return v
    }
}

final class CloudKV {
    static let shared = CloudKV()
    private let kv: CloudKeyValueStorage
    private let notifications: NotificationCenter
    private var observer: NSObjectProtocol?
    private var pulling = false
    /// يُحتفظ به ليُخبَر التطبيق حين يبدّل الدفعُ نفسُه قيمةً محلية (بضمّ ما في السحابة).
    private var onChange: (() -> Void)?

    /// راية «ضاقت السحابة بالتدبّرات» — تُقرأ في الواجهة عبر notesNearCloudLimit.
    static let notesCapacityKey = "athar.cloudSync.notesCapacity"

    /// حصّة التدبّرات من مخزن iCloud: ربعُ المليون المتاح للتطبيق كلّه، والباقي
    /// للتفضيلات والعلامات. حارسٌ أخيرٌ لا خطة — الأرشيف يقلّم نفسه قبل بلوغها.
    static let notesByteBudget = 256 * 1024

    /// المفاتيح المتزامنة — قيمٌ صغيرة يُحتمل فقدانها بلا ضرر.
    static let keys: [String] = [
        "athar.tabs.visible", "athar.home.cards", "athar.home.cards.hidden",
        "athar.theme", "athar.appearance", "athar.bgPattern", "athar.unifyIcons",
        "athar.hadith.favorites", "athar.mushaf.bookmarks", "athar.mushaf.highlights",
        // التدبّرات تُزامَن كما تُزامَن العلامة والتظليل: ما كتبه القارئ على آيته أولى بالبقاء.
        NoteArchive.key,
        "athar.mushaf.stopMark", "athar.mushaf.lastRead",
        "athar.athanSound", "athar.preAthanMinutes", "athar.iqamahMinutes",
        "athar.mushaf.theme", "athar.mushaf.readingMode", "athar.mushaf.fontScale", "athar.fontScale",
        "athar.tasbihPhrase", "athar.tasbihTarget", "athar.secondaryCityId",
    ]

    /// ما يُدمج اتحادًا بدل النسخ الكامل — علّته في رأس الملف.
    static let unionKeys: Set<String> = [
        "athar.hadith.favorites", "athar.mushaf.bookmarks", "athar.mushaf.highlights",
    ]

    /// الدمج بحسب شكل القيمة؛ `preferred` صاحب الأولوية عند تنازع المفتاح الواحد.
    static func union(_ key: String, preferred: Any?, over other: Any?) -> Any? {
        // كلٌّ يُفكّ صراحةً: ردُّ اختياريٍّ في مكان Any ينشئ اختياريًّا داخل اختياري
        // فيُكتب في التفضيلات «قيمةٌ» لا شيء فيها.
        switch key {
        case "athar.hadith.favorites":
            if let v = CloudMerge.strings(preferred, over: other) { return v }
        case "athar.mushaf.bookmarks":
            if let v = CloudMerge.refs(preferred, over: other) { return v }
        case "athar.mushaf.highlights":
            if let v = CloudMerge.map(preferred, over: other) { return v }
        default: break
        }
        return nil
    }

    init(kv: CloudKeyValueStorage = NSUbiquitousKeyValueStore.default, notifications: NotificationCenter = .default) {
        self.kv = kv; self.notifications = notifications
    }

    deinit { if let observer { notifications.removeObserver(observer) } }

    /// يُشغَّل عند الإقلاع حين يفعّل المستخدم المزامنة: يسحب ما في السحابة، ثم يراقب تغيّرها.
    func start(defaults: UserDefaults, onChange: @escaping () -> Void) {
        guard observer == nil else { return }
        self.onChange = onChange
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
        // السحب وحده يكفي: التدبّرات مفتاحٌ من مفاتيحه، فدمجُها فيه لا قبله.
        pull(keys: Self.keys, into: defaults)
        onChange()
    }

    func stop() {
        if let o = observer { notifications.removeObserver(o); observer = nil }
        onChange = nil
    }

    /// يدفع المفاتيح المحلية إلى السحابة (عند الذهاب للخلفية وعند كل تغيير مهم).
    func push(from defaults: UserDefaults) {
        guard observer != nil, !pulling else { return }
        mergeNotes(into: defaults)
        var touchedLocal = false
        for key in Self.keys {
            // التدبّرات دُفعت في mergeNotes بأرشيفها، لا بنسخ المفتاح كما هو.
            if key == NoteArchive.key { continue }
            let local = defaults.object(forKey: key)
            if Self.unionKeys.contains(key) {
                // الدفع يضمّ ما في السحابة قبل أن يكتب: بغيره يمحو الدفعُ ما لم يبلغه بعد.
                guard let merged = Self.union(key, preferred: local, over: kv.object(forKey: key)) else { continue }
                if !Self.same(merged, local) { defaults.set(merged, forKey: key); touchedLocal = true }
                kv.set(merged, forKey: key)
                continue
            }
            if let local, Self.isPlist(local) { kv.set(local, forKey: key) }
            else if local == nil { kv.removeObject(forKey: key) }
        }
        kv.synchronize()
        if touchedLocal { onChange?() }
    }

    private func pull(keys: [String], into defaults: UserDefaults, removeMissing: Bool = false) {
        pulling = true; defer { pulling = false }
        for key in keys where Self.keys.contains(key) {
            if key == NoteArchive.key { mergeNotes(into: defaults); continue }
            let remote = kv.object(forKey: key)
            if Self.unionKeys.contains(key) {
                if let merged = Self.union(key, preferred: remote, over: defaults.object(forKey: key)) {
                    defaults.set(merged, forKey: key)
                }
                continue
            }
            if let remote { defaults.set(remote, forKey: key) }
            else if removeMissing { defaults.removeObject(forKey: key) }
        }
    }

    /// اللقاء بين أرشيف الجهاز وأرشيف السحابة. الترتيب مقصود: يُقرأ المحلي أوّلًا،
    /// ثم تُستوعب الصيغة القديمة إن بقيت في السحابة من بناءٍ أقدم، ثم يُضمّ أرشيفها.
    /// وكلّها إضافة: مدوّنةٌ فاسدة أو غائبة في السحابة تُقرأ فارغةً فلا تمحو شيئًا.
    private func mergeNotes(into defaults: UserDefaults) {
        var archive = NoteArchive.load(defaults)
        archive.importLegacy(kv.object(forKey: NoteArchive.legacyKey) as? Data)
        archive.merge(NoteArchive.decode(kv.object(forKey: NoteArchive.key) as? Data))
        archive.save(defaults)   // يقلّم قبل أن يكتب

        guard var data = try? JSONEncoder().encode(archive) else { return }
        var near = false
        if data.count > Self.notesByteBudget {
            // ضاقت الحصّة: يُضيَّق المرفوع إلى ما يسعها — سجلّ التراجع أوّلًا ثم
            // أقدم التدبّرات — ويبقى الباقي يُزامَن. وقوف المزامنة صامتةً أفدح.
            near = true
            var live = archive
            guard live.fit(byteBudget: Self.notesByteBudget),
                  let slim = try? JSONEncoder().encode(live) else {
                defaults.set(true, forKey: Self.notesCapacityKey)
                return
            }
            data = slim
        }
        kv.set(data, forKey: NoteArchive.key)
        if near { defaults.set(true, forKey: Self.notesCapacityKey) }
        else { defaults.removeObject(forKey: Self.notesCapacityKey) }
    }

    /// مقارنةٌ تكفي أشكال ما نزامنه — تمنع كتابةً لا تبدّل شيئًا. وما التبس شكله
    /// يُعدّ مختلفًا فيُكتب: كتابةٌ زائدة أهون من قيمةٍ تخلّفت عن أختها.
    private static func same(_ a: Any?, _ b: Any?) -> Bool {
        if let x = a as? Data, let y = b as? Data { return x == y }
        if let x = a as? [String], let y = b as? [String] { return x == y }
        return false
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

    /// بلغت التدبّرات حصّتها من السحابة، فسجلّ التراجع لم يُرفع. تُقرأ في الواجهة
    /// من هنا لا من التفضيلات مباشرةً — جسمُ الشاشة يقرأ المخزن، لا الأقفال.
    var notesNearCloudLimit: Bool { defaults.bool(forKey: CloudKV.notesCapacityKey) }

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
