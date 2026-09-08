import Foundation
import CryptoKit

// MARK: - أرشيف التدبّرات
//
// ما يكتبه القارئ على آيةٍ أثمنُ ما في هذا التطبيق، وأقسى ما يقع به أن يمحوه
// جهازٌ آخر وهو لا يدري. فلا تُستبدل التدبّرات استبدالًا: تُكتب نسخًا لا تُبدَّل
// بعد كتابتها، كلٌّ تذكر أباها، فإذا التقى جهازان جُمعت نسخهما ولم تُمحَ واحدةٌ
// لأجل أخرى. والاتحاد وحده لا يكفي — فالحذف خبرٌ لا بدّ أن يسري — فجُعل للمحو
// شاهدٌ ينسخ ما قبله كما تنسخ الكتابة.

/// نسخةٌ واحدة من تدبّرٍ على آية، لا تُبدَّل بعد كتابتها.
struct NoteRevision: Codable, Identifiable, Equatable {
    let id: String
    let reference: String
    /// nil شاهدُ حذف: به يسري خبر المحو إلى بقية الأجهزة بدل أن يبقى سرًّا محليًّا.
    let text: String?
    let date: Date
    /// ما نسختْه هذه النسخة — بها يُعرف الرأس من المطويّ.
    let parents: [String]
    /// أين كُتبت. تُعرف بها مسوّدةُ هذا الجهاز فتُطوى مكانها لا تُكدَّس فوقها.
    var origin: String?
    /// مسوّدةُ حفظٍ تلقائي: يجوز أن تحلّ التالية محلّها ما دامتا في مجلسٍ واحد.
    var draft: Bool?
}

struct NoteArchive: Codable {
    static let key = "athar.mushaf.notes.v2"
    /// الصيغة المشحونة في المتجر ([String:String]). تُقرأ مرّةً لتُستوعب، ثم لا
    /// تزال تُكتب أبدًا: DataExport والبناءات الأقدم لا تعرف غيرها.
    static let legacyKey = "athar.mushaf.notes"
    /// هوية هذا التنصيب لا هوية صاحبه. ببادئة cloudSync لأن DataExport يستثنيها،
    /// ولو انتقلت في نسخةٍ احتياطية لحسب جهازٌ مسوّدةَ غيره مسوّدتَه فطواها.
    static let originKey = "athar.cloudSync.origin"

    /// سقف النسخ. مخزن iCloud للقيم الصغيرة مليونُ بايتٍ للتطبيق كلّه لا لمفتاح
    /// واحد، والتدبّرات جارةُ التفضيلات والعلامات فيه؛ فحسبُها ربعُه. وبمتوسّط
    /// تدبّرٍ نحو مئتي حرف تسع أربعمئة نسخةٍ في نحو مئةٍ وخمسين ألف بايت.
    static let maxRevisions = 400
    /// ما يُبقى لكل آية من المطويّات: ستٌّ تحفظ مجالس تحريرٍ عدّة للتراجع، ولا
    /// تملأ «المحذوف والنسخ السابقة» بأنصاف جُمَل.
    static let supersededPerReference = 6
    /// نافذة طيّ الحفظ التلقائي: ما كُتب في مجلسٍ واحد نسخةٌ واحدة، لا نسخةً عن
    /// كل سكتةٍ بين كلمتين.
    static let coalesceWindow: TimeInterval = 5 * 60
    /// سقف البصمات المحفوظة للصيغة القديمة — أكثر مما يبلغه مهاجرٌ بمراحل.
    static let maxAbsorbed = 200

    var revisions: [String: NoteRevision] = [:]
    /// بصمات ما استُوعب من الصيغة القديمة ولو طواه التقليم بعدُ. لولاها لعاد
    /// المحذوف حيًّا كلما التقى الأرشيفُ نسخةً قديمة في السحابة لم يبلغها الخبر.
    var absorbed: [String] = []

    init() {}

    /// مفتاحٌ غائب في مدوّنةٍ سابقة لا يُبطل قراءتها: الأرشيف يُقرأ على ما فيه.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        revisions = try c.decodeIfPresent([String: NoteRevision].self, forKey: .revisions) ?? [:]
        absorbed = try c.decodeIfPresent([String].self, forKey: .absorbed) ?? []
    }

    private enum CodingKeys: String, CodingKey { case revisions, absorbed }

    // MARK: القراءة والكتابة في التفضيلات

    /// مدوّنةٌ لا تُفكّ ترجعُ فارغةً لا خطأً — وهذا آمن: الدمج يضيف ولا يحذف،
    /// فمدوّنةٌ فاسدة تُتجاهل ولا تمحو حرفًا مما عند القارئ.
    /// ترميزٌ قانونيّ: مفاتيح مرتَّبة وبايتاتٌ لا تتبدّل بين تشغيلٍ وآخر. مُعجم Swift
    /// يُرتّب مفاتيحه عشوائيًّا في كل عملية، فأرشيفان متطابقان يُنتجان بايتين مختلفين —
    /// ولو رُفع أحدهما لظنّه الجهاز الآخر تغيّرًا فسحب ورفع، فدارت المزامنة على نفسها
    /// بلا حرفٍ جديد. فالمقارنة والرفع لا يكونان إلا بهذا.
    static func canonicalEncode(_ value: NoteArchive) -> Data? {
        var v = value
        v.absorbed.sort()                     // المصفوفة تتفرّق بالدمج، فتُرتَّب قبل الوزن
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try? e.encode(v)
    }

    func canonicalData() -> Data? { Self.canonicalEncode(self) }

    static func decode(_ data: Data?) -> NoteArchive {
        guard let data, let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self() }
        return value
    }

    /// آخر ما فُكّ من التفضيلات، مقيَّدًا ببايتاته لا بزمنه. الفكّ يتكرّر عشرات
    /// المرّات في رسمةٍ واحدة — قائمة التدبّرات تسأل عن كل صفّ — وفكّ الأرشيف
    /// كلّه أثقل من مقارنة بايتاته. والقفل لأن Shared يُقرأ من خيوطٍ شتّى.
    private static var cached: (v2: Data?, legacy: Data?, archive: NoteArchive)?
    private static let cacheLock = NSLock()

    private static func cachedArchive(_ v2: Data?, _ legacy: Data?) -> NoteArchive? {
        cacheLock.lock(); defer { cacheLock.unlock() }
        guard let c = cached, c.v2 == v2, c.legacy == legacy else { return nil }
        return c.archive
    }

    private static func remember(_ v2: Data?, _ legacy: Data?, _ archive: NoteArchive) {
        cacheLock.lock(); defer { cacheLock.unlock() }
        cached = (v2, legacy, archive)
    }

    static func load(_ defaults: UserDefaults) -> NoteArchive {
        let v2 = defaults.data(forKey: key)
        let legacy = defaults.data(forKey: legacyKey)
        if let hit = cachedArchive(v2, legacy) { return hit }
        var value = decode(v2)
        value.importLegacy(legacy)
        remember(v2, legacy, value)
        return value
    }

    mutating func save(_ defaults: UserDefaults) {
        prune()
        guard let data = Self.canonicalEncode(self) else { return }
        let projection = (try? JSONEncoder().encode(notes)) ?? Data("{}".utf8)
        defaults.set(data, forKey: Self.key)
        // الإسقاطة تُكتب دائمًا ولا تُصحَّح بها: الأرشيف يصحّحها، لا هي إيّاه.
        defaults.set(projection, forKey: Self.legacyKey)
        Self.remember(data, projection, self)
    }

    /// رقمٌ عشوائي يُولد مرّةً لهذا التنصيب. لا يُزامَن ولا يُصدَّر ولا يدلّ على صاحبه.
    static func origin(_ defaults: UserDefaults) -> String {
        if let existing = defaults.string(forKey: originKey), !existing.isEmpty { return existing }
        let token = UUID().uuidString
        defaults.set(token, forKey: originKey)
        return token
    }

    // MARK: الهجرة من الصيغة المشحونة

    /// معرّفٌ من بصمة النصّ لا من عشوائيّة: جهازان هاجرا بالنصّ نفسه يتّفقان
    /// على المعرّف عينه، فلا يُستورد التدبّر الواحد مرّتين حين يلتقيان.
    static func legacyID(reference: String, text: String) -> String {
        let digest = SHA256.hash(data: Data((reference + "\n" + text).utf8))
        return "legacy-" + digest.map { String(format: "%02x", $0) }.joined()
    }

    /// القديمة لا تاريخ لها، فتدخل بتاريخٍ سحيق حتى لا تسبق شيئًا كُتب بعدها:
    /// لو زاحمت شاهدَ حذفٍ حديثًا على رأسٍ واحد غلبها الشاهد فبقي المحذوف محذوفًا.
    mutating func importLegacy(_ data: Data?) {
        guard let data, let old = try? JSONDecoder().decode([String: String].self, from: data) else { return }
        var seen = Set(absorbed)
        for (ref, raw) in old {
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            // ما يعرفه الأرشيف نصًّا لا يُستورد: هذه إسقاطتنا نحن عادت إلينا.
            if revisions.values.contains(where: { $0.reference == ref && $0.text == text }) { continue }
            let id = Self.legacyID(reference: ref, text: text)
            // استُوعب مرّةً ثم طواه التقليم أو نسخه القارئ: لا يُبعث ثانيةً.
            if seen.contains(id) { continue }
            seen.insert(id)
            absorbed.append(id)
            revisions[id] = NoteRevision(id: id, reference: ref, text: text,
                                         date: .distantPast, parents: [], origin: nil, draft: nil)
        }
        if absorbed.count > Self.maxAbsorbed { absorbed.removeFirst(absorbed.count - Self.maxAbsorbed) }
    }

    // MARK: الدمج

    /// الدمج يضيف ولا يحذف؛ وهذا أصل الضمان كلّه: ما دخل الأرشيف لا يخرج منه
    /// بلقاء جهازٍ آخر، وإنما يُنسخ بنسخةٍ أحدث تذكره أبًا.
    mutating func merge(_ other: NoteArchive) {
        for (id, revision) in other.revisions where revisions[id] == nil { revisions[id] = revision }
        var seen = Set(absorbed)
        for id in other.absorbed where !seen.contains(id) { seen.insert(id); absorbed.append(id) }
        if absorbed.count > Self.maxAbsorbed { absorbed.removeFirst(absorbed.count - Self.maxAbsorbed) }
    }

    // MARK: الرؤوس

    /// كل معرّفٍ ذكره ابنٌ حاضر أبًا. يُحسب للأرشيف كلّه مرّةً لا لكل آية مرّة.
    private func supersededIDs() -> Set<String> {
        var s = Set<String>()
        for r in revisions.values { s.formUnion(r.parents) }
        return s
    }

    /// الأحدث أوّلًا، وعند تساوي التاريخ يُرجَّح المعرّف — ترتيبٌ كليٌّ يتّفق
    /// عليه جهازان بلا تشاور، فيقرآن التدبّر الواحد سواءً ويُقلّمان سواءً.
    static func newerFirst(_ a: NoteRevision, _ b: NoteRevision) -> Bool {
        a.date == b.date ? a.id > b.id : a.date > b.date
    }

    /// أولى المنسوخات بالبقاء عند التقليم: ما استقرّ عليه صاحبه قبل مسوّدةٍ آليّة،
    /// ثم الأحدث قبل الأقدم. وهو ترتيبٌ كليٌّ أيضًا، فالتقليم يبقى قطعيًّا.
    static func worthKeeping(_ a: NoteRevision, _ b: NoteRevision) -> Bool {
        if (a.draft == true) != (b.draft == true) { return b.draft == true }
        return newerFirst(a, b)
    }

    func heads(for ref: String) -> [NoteRevision] {
        let superseded = supersededIDs()
        return revisions.values
            .filter { $0.reference == ref && !superseded.contains($0.id) }
            .sorted(by: Self.newerFirst)
    }

    /// رؤوس الآيات كلّها في مسحةٍ واحدة.
    func allHeads() -> [String: [NoteRevision]] {
        let superseded = supersededIDs()
        var byRef: [String: [NoteRevision]] = [:]
        for r in revisions.values where !superseded.contains(r.id) {
            byRef[r.reference, default: []].append(r)
        }
        return byRef.mapValues { $0.count > 1 ? $0.sorted(by: Self.newerFirst) : $0 }
    }

    /// ما يقرؤه القارئ اليوم: رأسُ كل آية، وشاهدُ الحذف يعني ألّا شيء.
    var notes: [String: String] {
        var result: [String: String] = [:]
        for (ref, heads) in allHeads() {
            if let text = heads.first?.text { result[ref] = text }
        }
        return result
    }

    /// المحذوف والمطويّ — ما كُتب يومًا ولم يعد ظاهرًا. الرأس الحاضر يُستثنى وحده،
    /// فرأسٌ ثانٍ نشأ عن تحريرين متزامنين يبقى معروضًا لصاحبه ليختار.
    ///
    /// والمسوّدة المنسوخة لا تُعرض: هي نصفُ جملةٍ خلّفها الحفظ التلقائي، وقد تبلغ
    /// جهازًا آخر إن زُومن أثناء الكتابة. صفحة الاستعادة موضعُ ما استقرّ عليه
    /// صاحبه ثم بدّله أو محاه، لا سِجلّ ضغطاتٍ على لوحة المفاتيح.
    var recovery: [NoteRevision] {
        let current = Set(allHeads().values.compactMap { $0.first?.id })
        return revisions.values
            .filter { $0.text != nil && $0.draft != true && !current.contains($0.id) }
            .sorted(by: Self.newerFirst)
    }

    // MARK: الكتابة

    /// نسخةٌ جديدة على الآية.
    ///
    /// `draft` للحفظ التلقائي أثناء الكتابة: إن كان الرأسُ مسوّدةَ هذا الجهاز في
    /// مجلسه طُويت مكانها بدل أن تُذيَّل بها السلسلة — عشر سكتاتٍ بين الكلمات لا
    /// تُخلّف عشر نسخ دائمة. وتبقى المطويّة أبًا للجديدة كي يعرف الجهاز الآخر —
    /// لو كان خبرها بلغه — أنها نُسخت فلا تُعدّ رأسًا عنده.
    @discardableResult
    mutating func set(_ text: String?, for ref: String, origin: String? = nil,
                      draft: Bool = false, now: Date = Date()) -> Bool {
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let clean = trimmed?.isEmpty == false ? trimmed : nil
        let heads = heads(for: ref)
        let sole = heads.count == 1 ? heads.first : nil

        // حفظٌ صريح بنصّ المسوّدة عينه: تُرقّى المسوّدة مكانها فتستقرّ، ولا يطويها
        // مجلسٌ لاحق في نافذته. والرايةُ دفترُ هذا الجهاز لا محتوى النسخة، فتبديلها
        // لا يمسّ نصًّا ولا تاريخًا ولا نسبًا — والدمج إنما يعرف النسخ بمعرّفاتها.
        if !draft, let head = sole, head.draft == true, head.text == clean {
            revisions[head.id] = NoteRevision(id: head.id, reference: head.reference, text: head.text,
                                              date: head.date, parents: head.parents,
                                              origin: head.origin, draft: nil)
            return true
        }
        // لا جديد ولا رأسان يُجمعان: لا نسخة.
        guard heads.count > 1 || heads.first?.text != clean else { return false }

        var parents = heads.map(\.id)
        if let head = sole, head.draft == true,
           let origin, head.origin == origin,
           now >= head.date, now.timeIntervalSince(head.date) <= Self.coalesceWindow {
            // لا يُحمل من آباء المسوّدة إلا ما قد يكون بلغ جهازًا آخر: آخرُ مستقرٍّ
            // نُسخ، والمسوّدةُ التي تُطوى الآن. ولولا هذا الحدّ لتضخّم النسب مع كل
            // سكتةٍ في مجلسٍ طويل — النافذة تتجدّد بتاريخ الرأس فلا تنغلق أثناء الكتابة.
            let stable = head.parents.filter { revisions[$0]?.draft != true }
            parents = Array(Set(stable).union([head.id])).sorted()
            revisions.removeValue(forKey: head.id)
        }
        let revision = NoteRevision(id: UUID().uuidString, reference: ref, text: clean,
                                    date: now, parents: parents.sorted(), origin: origin,
                                    draft: draft ? true : nil)
        revisions[revision.id] = revision
        return true
    }

    // MARK: التقليم

    /// الرؤوس لا تُمسّ أبدًا — هي التدبّرات الحيّة وشواهد المحو. ويُبقى لكل آية
    /// عددٌ من المطويّات للتراجع، ثم سقفٌ عامّ يُسقط الأقدم أوّلًا. بغير هذا يتجاوز
    /// الأرشيفُ حصّة السحابة فتقف المزامنة صامتة، ووقوفها أفدح من فقد مسوّدةٍ
    /// عمرها شهر. والقاعدة قطعيّة لا عشوائيّة، فجهازان بالنسخ عينها يُقلّمان سواءً
    /// ولا يظلّان يتقاذفان ما أسقطه أحدهما.
    mutating func prune(maxTotal: Int = NoteArchive.maxRevisions,
                        perReference: Int = NoteArchive.supersededPerReference) {
        if absorbed.count > Self.maxAbsorbed { absorbed.removeFirst(absorbed.count - Self.maxAbsorbed) }
        let superseded = supersededIDs()
        var keep = Set(revisions.values.lazy.filter { !superseded.contains($0.id) }.map(\.id))
        guard keep.count < revisions.count else { return }

        var byRef: [String: [NoteRevision]] = [:]
        for r in revisions.values where superseded.contains(r.id) {
            byRef[r.reference, default: []].append(r)
        }
        var candidates: [NoteRevision] = []
        for (_, list) in byRef {
            candidates.append(contentsOf: list.sorted(by: Self.worthKeeping).prefix(perReference))
        }
        let room = max(0, maxTotal - keep.count)
        for r in candidates.sorted(by: Self.worthKeeping).prefix(room) { keep.insert(r.id) }

        guard keep.count < revisions.count else { return }
        revisions = revisions.filter { keep.contains($0.key) }
    }

    /// الرؤوس وحدها. تُطلب حين تضيق السحابة: تُرفع نُسخ التراجع من المرفوع وتبقى
    /// التدبّرات الحيّة وشواهد المحو تُزامَن — فانقطاع المزامنة أفدح من فقد سجلّ.
    mutating func dropHistory() {
        let superseded = supersededIDs()
        revisions = revisions.filter { !superseded.contains($0.key) }
    }

    /// يضيق الأرشيف إلى ما يسع الحصّة، ويردّ هل بقي شيءٌ يُرفع.
    ///
    /// الترتيب: تُطرح نُسخ التراجع أوّلًا، ثم تُستبقى شواهدُ المحو كلّها — خبر
    /// الحذف لا يُحتبس، وهي أخفّ ما في الأرشيف — ثم يُملأ الباقي بأحدث التدبّرات
    /// فالأقدم. ورفعُ بعضها أولى من ألّا يُرفع شيء: الدمج يضيف ولا يحذف، فالناقصُ
    /// لا يمحو عند الجهاز الآخر حرفًا، وما تخلّف اليوم يُرفع غدًا إن اتّسع.
    /// والقياس بالوزن لا بالعدّ، والبحث ثنائيٌّ لأن الترميز على كل خطوةٍ ثقيل.
    mutating func fit(byteBudget: Int) -> Bool {
        dropHistory()
        if let d = canonicalData(), d.count <= byteBudget { return true }

        let ordered = revisions.values.sorted(by: Self.newerFirst)
        let tombstones = ordered.filter { $0.text == nil }
        let live = ordered.filter { $0.text != nil }
        var lo = 0, hi = live.count
        var best: [String: NoteRevision]?
        while lo <= hi {
            let mid = (lo + hi) / 2
            var trial = self
            trial.revisions = Dictionary(uniqueKeysWithValues: (tombstones + live.prefix(mid)).map { ($0.id, $0) })
            if let d = Self.canonicalEncode(trial), d.count <= byteBudget {
                best = trial.revisions; lo = mid + 1
            } else { hi = mid - 1 }
        }
        guard let best else { return false }
        revisions = best
        return true
    }
}
