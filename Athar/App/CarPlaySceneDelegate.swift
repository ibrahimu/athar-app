import UIKit
import CarPlay

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

    // MARK: الاتصال

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        interface = interfaceController
        interfaceController.setRootTemplate(rootTemplate(), animated: false, completion: nil)
        watchPlayback()
        // وصلت السيارة والصوتُ يعمل: تُعرض شاشةُ التشغيل مباشرةً بدل قائمةٍ تُتصفَّح.
        if Recitation.shared.surah != nil || RadioPlayer.shared.source != nil {
            interfaceController.pushTemplate(CPNowPlayingTemplate.shared, animated: false, completion: nil)
        }
    }

    func templateApplicationScene(_ scene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        refreshTask?.cancel()
        refreshTask = nil
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

        // سورٌ للطريق.
        let picks = CarPlayMenu.favourites.compactMap { Quran.surah($0) }.map { surahItem($0) }
        if !picks.isEmpty {
            sections.append(CPListSection(items: picks, header: "سورٌ للطريق", sectionIndexTitle: nil))
        }
        return sections
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
    private func surahSections() -> [CPListSection] {
        let groups = CarPlayMenu.surahGroups().map { g in
            (header: g.header, items: g.ids.compactMap { Quran.surah($0) }.map { surahItem($0) })
        }
        return build(groups)
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
        let has = RecitationLibrary.isDownloaded(reciter: Recitation.shared.reciterId, surah: su.id)
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
        let items = Quran.surahs
            .filter { RecitationLibrary.isDownloaded(reciter: id, surah: $0.id) }
            .map { surahItem($0) }
        guard !items.isEmpty else {
            let empty = CPListItem(text: "لم تنزّل شيئًا بعد",
                                   detailText: "نزّل سورًا من التطبيق لتسمعها في الطريق بلا شبكة")
            empty.handler = { _, done in done() }
            return [CPListSection(items: [empty])]
        }
        return build([(header: Recitation.shared.reciter.name, items: items)])
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
            let count = Recitation.shared.downloadedSummary(reciter: r.id).count
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
        return build([(header: "", items: items)])
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
        refreshTask = Task { @MainActor [weak self] in
            // مراقبةُ حالة التشغيل نفسها: الإشعار يُرسل عند البدء لا عند الوقف والاستئناف.
            var last = Self.snapshot()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                let now = Self.snapshot()
                if now != last { last = now; self?.refreshAll() }
            }
        }
    }

    @MainActor
    private static func snapshot() -> String {
        "\(Recitation.shared.surah ?? 0)/\(Recitation.shared.isPlaying)/\(Recitation.shared.reciterId)/\(RadioPlayer.shared.isPlaying)"
    }

    private func scheduleRefresh() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
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
