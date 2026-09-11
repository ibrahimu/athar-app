import UIKit
import CarPlay
import Combine

/// لقطةُ ما نُزّل على القرص: أرقامُ السور المحفوظة لكل قارئ.
///
/// كانت كلُّ إعادةِ بناءٍ لقوائم CarPlay تسأل نظامَ الملفّات عن كل سورةٍ لكل قارئ —
/// ألفان وأربعمئةٍ وسبعةٌ وخمسون نداءً، على الممثّل الرئيس، والسيارةُ أسوأُ موضعٍ
/// للتلعثم. فتُقرأ اللقطةُ مرّةً بمسحٍ واحدٍ للمجلّدات (ثمانيةَ عشرَ نداءً)، ثمّ
/// تُبنى القوائمُ من الذاكرة بلا مساسٍ بالقرص.
struct CarPlayDownloads: Equatable, Sendable {
    /// معرّفُ القارئ ← أرقامُ سوره المحمَّلة.
    var sets: [String: Set<Int>] = [:]

    func surahs(_ reciter: String) -> Set<Int> { sets[reciter] ?? [] }
    func count(_ reciter: String) -> Int { sets[reciter]?.count ?? 0 }

    /// يُبنى من أسماء الملفّات وحدها — فيُختبر بلا قرصٍ ولا سيارة. والاسمُ الذي لا
    /// يوافق «ثلاثُ خاناتٍ ثمّ mp3.» لسورةٍ من المصحف يُطرح: ملفٌّ غريبٌ لا يُعدّ سورة.
    static func make(_ listing: [String: [String]]) -> CarPlayDownloads {
        var sets: [String: Set<Int>] = [:]
        for (reciter, names) in listing {
            var ids: Set<Int> = []
            for name in names where name.hasSuffix(".mp3") {
                guard let n = Int(name.dropLast(4)), (1...114).contains(n) else { continue }
                ids.insert(n)
            }
            sets[reciter] = ids
        }
        return CarPlayDownloads(sets: sets)
    }

    /// مسحٌ واحدٌ لجذر التلاوات: مجلّدُ كل قارئ يُقرأ مرّةً بدل سؤالٍ عن كل ملف.
    static func read(root: URL = RecitationLibrary.root) -> CarPlayDownloads {
        let fm = FileManager.default
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil,
                                                options: [.skipsHiddenFiles])) ?? []
        var listing: [String: [String]] = [:]
        for dir in dirs {
            listing[dir.lastPathComponent] = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
        }
        return make(listing)
    }

    /// ويُقرأ خارج الممثّل الرئيس: انتظارُ القرص وأنت تسوق يُرى تلعثمًا في الشاشة.
    static func readOffMain() async -> CarPlayDownloads {
        await Task.detached(priority: .utility) { read() }.value
    }
}

/// CarPlay: القرآنُ في الطريق.
///
/// المبدأ: السائقُ لا يقرأ قائمةً طويلة ولا يتصفّح — يمدّ يده فيبدأ الصوت. فأوّلُ
/// تبويبٍ هو «الآن»: ما كان يستمع إليه، والإذاعة، وسورٌ يطلبها الناس في سيارتهم.
/// وما وراءه للباحث: كلّ السور، وما نُزّل منها (يعمل بلا شبكة — وهذا أهمّ ما في
/// السيارة)، والقرّاء.
///
/// ولا يُشغَّل هنا إلا ما يُسمع: البثّ المباشر للحرمين يمرّ بمشغّل يوتيوب فلا مكان
/// له في CarPlay، والإذاعة تيّارُ صوتٍ مباشر فتصلح.
///
/// يلزمه استحقاق com.apple.developer.carplay-audio من Apple.
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interface: CPInterfaceController?
    /// قوائمُ تُعاد صياغتها حين يتبدّل ما يُشغَّل — فالمؤشّر يقف على السورة الجارية.
    private var nowTemplate: CPListTemplate?
    private var surahsTemplate: CPListTemplate?
    private var downloadedTemplate: CPListTemplate?
    private var recitersTemplate: CPListTemplate?
    private var observers: [NSObjectProtocol] = []
    private var refreshTask: Task<Void, Never>?
    /// مهامٌّ مؤقّتة تُمسك بمقبضها لتُلغى عند فصل السيارة — وإلا بقيت تنبض بعد أن
    /// تُطفأ الشاشة، ولا أحد ينظر.
    private var nudgeTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var downloadWatch: AnyCancellable?
    /// ما على القرص محفوظًا: تُبنى منه القوائمُ الأربع بلا نداءٍ واحدٍ لنظام الملفّات.
    private var disk = CarPlayDownloads()
    /// تبدّل القرصُ أثناء مسحه؟ يُعاد المسحُ جولةً أخرى بدل أن تبقى اللقطة قديمة.
    private var diskDirty = false

    // MARK: الاتصال

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        interface = interfaceController
        // أوّلُ مسحٍ يجري هنا مباشرةً: لقطةٌ واحدة تكفي القوائم الأربع، وبناؤها على
        // لقطةٍ فارغة كان سيُري السائق «لم تنزّل شيئًا بعد» ثمّ يبدّلها بعد لحظة.
        disk = .read()
        interfaceController.setRootTemplate(rootTemplate(), animated: false, completion: nil)
        watchPlayback()
        // وصلت السيارة والصوتُ يعمل: تُعرض شاشةُ التشغيل مباشرةً بدل قائمةٍ تُتصفَّح.
        if Recitation.shared.surah != nil || RadioPlayer.shared.source != nil {
            interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: false, completion: nil)
        }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        teardown()
    }

    /// وتُفصل الشاشةُ من طريقٍ آخر أيضًا، فيُجمع الوقفُ في موضعٍ واحدٍ يُستدعى مرّتين
    /// بلا ضرر: نبضةٌ تبقى بعد الفصل توقظ التطبيق كلّ ثانيتين ولا شاشةَ تقرؤها.
    func sceneDidDisconnect(_ scene: UIScene) { teardown() }

    private func teardown() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        downloadWatch = nil
        refreshTask?.cancel(); refreshTask = nil
        nudgeTask?.cancel(); nudgeTask = nil
        scanTask?.cancel(); scanTask = nil
        interface = nil
        nowTemplate = nil; surahsTemplate = nil; downloadedTemplate = nil; recitersTemplate = nil
    }

    // MARK: الجذر

    private func rootTemplate() -> CPTemplate {
        let now = makeNow()
        let surahs = makeSurahs()
        let downloaded = makeDownloaded()
        let reciters = makeReciters()
        nowTemplate = now; surahsTemplate = surahs
        downloadedTemplate = downloaded; recitersTemplate = reciters

        // عددُ التبويبات يقرّره النظام لا نحن — فيُقصّ عليه بدل أن يُرفض القالب.
        let tabs: [CPTemplate] = [now, surahs, downloaded, reciters]
        let allowed = max(1, CPTabBarTemplate.maximumTabCount)
        return CPTabBarTemplate(templates: Array(tabs.prefix(allowed)))
    }

    // MARK: «الآن»

    private func makeNow() -> CPListTemplate {
        let t = CPListTemplate(title: "أثر", sections: nowSections())
        t.tabTitle = "الآن"
        t.tabImage = UIImage(systemName: "play.circle.fill")
        return t
    }

    private func nowSections() -> [CPListSection] {
        var sections: [CPListSection] = []

        // ما كان فيه: أوّلُ ما تمتدّ إليه اليد، فأوّلُ ما يُعرض.
        var resume: [CPListItem] = []
        if let s = Recitation.shared.surah ?? Recitation.shared.lastPlayed, let su = Quran.surah(s) {
            let playing = Recitation.shared.surah == s && Recitation.shared.isPlaying
            let item = CPListItem(text: "سورة \(su.name)",
                                  detailText: playing ? Recitation.shared.reciter.name
                                                      : "تابع — \(Recitation.shared.reciter.name)")
            item.isPlaying = playing
            item.playingIndicatorLocation = .trailing
            item.handler = { [weak self] _, done in
                Task { @MainActor in
                    if Recitation.shared.surah == s { Recitation.shared.resume() }
                    else { Recitation.shared.play(surah: s) }
                    self?.showNowPlaying()
                    done()
                }
            }
            resume.append(item)
        }

        // الإذاعة: بلا اختيارٍ ولا بحث — تيّارٌ يعمل بضغطة، وهي أكثر ما يُطلب سياقةً.
        let radio = CPListItem(text: "إذاعة القرآن الكريم", detailText: "بثّ رسمي متواصل")
        radio.isPlaying = RadioPlayer.shared.isPlaying
        radio.playingIndicatorLocation = .trailing
        radio.handler = { [weak self] _, done in
            Task { @MainActor in
                RadioPlayer.shared.play(.radio)
                self?.showNowPlaying()
                done()
            }
        }
        resume.append(radio)
        sections.append(CPListSection(items: resume, header: "استمع الآن", sectionIndexTitle: nil))

        // سورٌ للطريق — وما يسعه السقفُ بعد صفّي المتابعة والإذاعة.
        let picks = CarPlayMenu.favourites.compactMap { Quran.surah($0) }.map { surahItem($0) }
        if !picks.isEmpty {
            sections.append(CPListSection(items: picks, header: "سورٌ للطريق", sectionIndexTitle: nil))
        }
        return build(sections.map { (header: $0.header ?? "", items: ($0.items as? [CPListItem]) ?? []) })
    }

    // MARK: السور

    private func makeSurahs() -> CPListTemplate {
        let t = CPListTemplate(title: "السور", sections: surahSections())
        t.tabTitle = "السور"
        t.tabImage = UIImage(systemName: "book.closed.fill")
        return t
    }

    /// مئةٌ وأربع عشرة سورة لا تُعرض دفعةً: النظام يقصّ ما زاد على حدّه صامتًا،
    /// فتُقسَّم إلى أقسامٍ معنونة، ويُقصّ الباقي على حدّه المعلن لا على تخمين.
    /// سقفُ القائمة اثنا عشر عنصرًا، والنظام يقصّ ما زاد صامتًا — فمئةٌ وأربع عشرة
    /// سورة لا تُعرض في قائمة. فمستويان: عشرُ مجموعاتٍ تسعها قائمة، وكلٌّ تُفتح على
    /// اثنتي عشرة سورة. وكانت تُعرض دفعةً فلا يرى السائق إلا أوّل اثنتي عشرة.
    private func surahSections() -> [CPListSection] {
        let items = CarPlayMenu.surahGroups().map { g -> CPListItem in
            let names = g.ids.prefix(2).compactMap { Quran.surah($0)?.name }.joined(separator: "، ")
            let item = CPListItem(text: "السور \(g.header)", detailText: names + "…")
            item.accessoryType = .disclosureIndicator
            item.handler = { [weak self] _, done in
                Task { @MainActor in
                    guard let self else { done(); return }
                    let list = CPListTemplate(title: "السور \(g.header)", sections: [
                        CPListSection(items: g.ids.compactMap { Quran.surah($0) }.map { self.surahItem($0) })
                    ])
                    self.interface?.pushTemplate(list, animated: true, completion: nil)
                    done()
                }
            }
            return item
        }
        return build([(header: "", items: items)])
    }

    /// حدّا القائمة يُقرآن من النظام لا من تخمين، والقصّ يقع عندنا بحسابٍ معلوم
    /// (انظر CarPlayMenu.clamp) بدل أن يبتره النظام صامتًا.
    private func build(_ groups: [(header: String, items: [CPListItem])]) -> [CPListSection] {
        CarPlayMenu.clamp(groups,
                          maxSections: CPListTemplate.maximumSectionCount,
                          maxItems: CPListTemplate.maximumItemCount)
            .map { CPListSection(items: $0.items, header: $0.header.isEmpty ? nil : $0.header,
                                 sectionIndexTitle: nil) }
    }

    private func surahItem(_ su: Surah) -> CPListItem {
        let has = disk.surahs(Recitation.shared.reciterId).contains(su.id)
        let item = CPListItem(text: "\(su.id.counterText). سورة \(su.name)",
                              detailText: has ? "محمَّلة — تعمل بلا شبكة" : su.ayahCount.ayahCountText)
        item.isPlaying = Recitation.shared.surah == su.id && Recitation.shared.isPlaying
        item.playingIndicatorLocation = .trailing
        item.handler = { [weak self] _, done in
            Task { @MainActor in
                Recitation.shared.play(surah: su.id)
                self?.showNowPlaying()
                done()
            }
        }
        return item
    }

    // MARK: المحمَّل

    private func makeDownloaded() -> CPListTemplate {
        let t = CPListTemplate(title: "المحمَّل", sections: downloadedSections())
        t.tabTitle = "المحمَّل"
        t.tabImage = UIImage(systemName: "arrow.down.circle.fill")
        return t
    }

    /// ما يعمل بلا شبكة — وهو أنفع ما في السيارة: النفق والطريق الخارجي يقطعان البثّ.
    private func downloadedSections() -> [CPListSection] {
        let id = Recitation.shared.reciterId
        let items = disk.surahs(id).sorted().compactMap { Quran.surah($0) }.map { surahItem($0) }
        guard !items.isEmpty else {
            let empty = CPListItem(text: "لم تنزّل شيئًا بعد",
                                   detailText: "نزّل سورًا من التطبيق لتسمعها في الطريق بلا شبكة")
            empty.handler = { _, done in done() }
            return [CPListSection(items: [empty])]
        }
        return paged(items, title: Recitation.shared.reciter.name)
    }

    // MARK: القرّاء

    private func makeReciters() -> CPListTemplate {
        let t = CPListTemplate(title: "القرّاء", sections: reciterSections())
        t.tabTitle = "القرّاء"
        t.tabImage = UIImage(systemName: "person.wave.2.fill")
        return t
    }

    private func reciterSections() -> [CPListSection] {
        let current = Recitation.shared.reciterId
        let items = RecitationLibrary.reciters.map { r -> CPListItem in
            let count = disk.count(r.id)
            let item = CPListItem(text: r.name,
                                  detailText: count > 0 ? "\(count.counterText) محمَّلة" : nil,
                                  image: nil,
                                  accessoryImage: nil,
                                  accessoryType: r.id == current ? .cloud : .none)
            item.handler = { [weak self] _, done in
                Task { @MainActor in
                    // تبديل القارئ يبدّل ما هو محمَّل وما يُشغَّل، فتُعاد القوائم كلّها.
                    Recitation.shared.select(r)
                    self?.refreshAll()
                    done()
                }
            }
            return item
        }
        return paged(items, title: "القرّاء")
    }

    /// ما زاد عن سقف القائمة يُدفع إلى صفحةٍ تاليةٍ بصفّ «المزيد» — لا يُقصّ صامتًا.
    /// (خمسةَ عشرَ قارئًا كانوا يُعرض منهم اثنا عشر، والباقي لا سبيل إليه.)
    private func paged(_ items: [CPListItem], title: String) -> [CPListSection] {
        let pages = CarPlayMenu.pages(items, size: CPListTemplate.maximumItemCount)
        guard let first = pages.first else { return [] }
        var shown = first
        if pages.count > 1 {
            shown.append(moreItem(pages: Array(pages.dropFirst()), index: 0, title: title))
        }
        return [CPListSection(items: shown)]
    }

    private func moreItem(pages: [[CPListItem]], index: Int, title: String) -> CPListItem {
        let item = CPListItem(text: "المزيد", detailText: nil)
        item.accessoryType = .disclosureIndicator
        item.handler = { [weak self] _, done in
            Task { @MainActor in
                guard let self, index < pages.count else { done(); return }
                var items = pages[index]
                if index + 1 < pages.count {
                    items.append(self.moreItem(pages: pages, index: index + 1, title: title))
                }
                self.interface?.pushTemplate(
                    CPListTemplate(title: title, sections: [CPListSection(items: items)]),
                    animated: true, completion: nil)
                done()
            }
        }
        return item
    }

    // MARK: التتبّع

    private func showNowPlaying() {
        guard let interface else { return }
        guard !(interface.topTemplate is CPNowPlayingTemplate) else { return }
        interface.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
    }

    /// المؤشّر يتبع الصوت: من بدّل السورة من مقود السيارة أو من الجوّال يجد القائمة
    /// تقول ما يُسمع. والتحديث مؤجَّل قليلًا فلا يُعاد بناء القوائم مع كل نبضة.
    private func watchPlayback() {
        let names: [Notification.Name] = [.atharAudioStarted]
        for name in names {
            let o = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRefresh()
            }
            observers.append(o)
        }
        // ودورةُ التنزيل لا إشعارَ لها يُسمع، وحالةُ التنزيلات أقربُ ما يُنبئ عن تبدّل
        // القرص: تُكتب عند تمام السورة، وعند حذفها، وعند حذف القارئ كلّه.
        downloadWatch = Recitation.shared.$downloads
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.invalidateDisk() } }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            // مراقبةُ حالة التشغيل نفسها: الإشعار يُرسل عند البدء لا عند الوقف والاستئناف.
            // ولا تمسّ هذه النبضةُ القرص — تقارن نصًّا في الذاكرة — وتموت بإلغاء المهمّة
            // لا بعد جولةٍ أخرى: النومُ يُترك لخطئه بدل ابتلاعه بـ try?.
            var last = Self.snapshot()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                let now = Self.snapshot()
                if now != last { last = now; self?.refreshAll() }
            }
        }
    }

    /// إعادةُ قراءة القرص تُجمَّع ولا تتكرّر: التنزيل يبثّ تقدّمه عشراتِ المرّات في
    /// الثانية، ومسحٌ لكلّ نبضةٍ عبث. فيُؤخَّر قليلًا حتى يهدأ، ولا يجري إلا مسحٌ واحدٌ
    /// في وقتٍ واحد، وما وقع أثناءه يُجمَع في جولةٍ تالية.
    private func invalidateDisk() {
        guard scanTask == nil else { diskDirty = true; return }
        diskDirty = false
        scanTask = Task { @MainActor [weak self] in
            var again = true
            while again {
                do { try await Task.sleep(for: .milliseconds(400)) } catch { break }
                guard let self, !Task.isCancelled else { break }
                self.diskDirty = false
                let fresh = await CarPlayDownloads.readOffMain()
                guard !Task.isCancelled else { break }
                // ولا تُعاد صياغةُ القوائم إلا إن تبدّل القرصُ فعلًا.
                if fresh != self.disk { self.disk = fresh; self.refreshAll() }
                again = self.diskDirty
            }
            self?.scanTask = nil
        }
    }

    @MainActor
    private static func snapshot() -> String {
        "\(Recitation.shared.surah ?? 0)/\(Recitation.shared.isPlaying)/\(Recitation.shared.reciterId)/\(RadioPlayer.shared.isPlaying)"
    }

    private func scheduleRefresh() {
        // وتُلغى النبضةُ السابقة: إشعاراتٌ متتابعة كانت تخلّف مهامًّا لا مقبضَ لها ولا وقف.
        nudgeTask?.cancel()
        nudgeTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            self?.refreshAll()
        }
    }

    @MainActor
    private func refreshAll() {
        nowTemplate?.updateSections(nowSections())
        surahsTemplate?.updateSections(surahSections())
        downloadedTemplate?.updateSections(downloadedSections())
        recitersTemplate?.updateSections(reciterSections())
    }
}
