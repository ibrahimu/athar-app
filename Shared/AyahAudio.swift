import Foundation
import AVFoundation
import MediaPlayer
import Combine

// MARK: - تلاوة آية بآية (everyayah.com)
//
// مقاطع صوتية لكل آية على حدة، فيُظلَّل موضع القراءة مع الصوت، وتُكرَّر الآية للحفظ.
// الشبكة لا تُمسّ إلا حين يضغط المستخدم «تشغيل».

struct AyahReciter: Identifiable, Hashable {
    let id: String        // مجلّد everyayah
    let name: String
    var url: String { "https://everyayah.com/data/\(id)/" }
}

enum AyahReciters {
    static let all: [AyahReciter] = [
        .init(id: "Alafasy_128kbps", name: "مشاري العفاسي"),
        .init(id: "Husary_128kbps", name: "محمود خليل الحصري"),
        .init(id: "Abdul_Basit_Murattal_192kbps", name: "عبد الباسط عبد الصمد"),
        .init(id: "Minshawy_Murattal_128kbps", name: "محمد صدّيق المنشاوي"),
        .init(id: "Saood_ash-Shuraym_128kbps", name: "سعود الشريم"),
        .init(id: "Abdurrahmaan_As-Sudais_192kbps", name: "عبد الرحمن السديس"),
        .init(id: "Hudhaify_128kbps", name: "علي الحذيفي"),
        .init(id: "Ghamadi_40kbps", name: "سعد الغامدي"),
    ]
    static func reciter(id: String) -> AyahReciter { all.first { $0.id == id } ?? all[0] }
}

@MainActor
final class AyahAudio: NSObject, ObservableObject {
    static let shared = AyahAudio()

    /// الآية الجارية — يظلّلها المصحف.
    @Published private(set) var current: AyahRef?
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    /// تعذّر التشغيل — المقطع يُجلب من الشبكة ولا يُنزَّل، فأوّل ما يقع فيه المستخدم
    /// في الطائرة. كان الفشل يُبتلع صامتًا: يسكت الصوت، ويبقى الشريط يقول اسم القارئ،
    /// ويقلب ▶ نفسَه إلى ⏸ على مشغّلٍ ميّت. فصار يُنشَر ليُقال.
    @Published private(set) var failed = false
    /// عدد تكرار كل آية (١ = بلا تكرار). للحفظ ٣ أو ٥ أو ١٠.
    @Published var repeatCount: Int = 1 { didSet { UserDefaults.standard.set(repeatCount, forKey: "athar.ayahAudio.repeat") } }
    @Published var reciterId: String = AyahReciters.all[0].id { didSet { UserDefaults.standard.set(reciterId, forKey: "athar.ayahAudio.reciter") } }
    /// مدى التشغيل: يقف عند آخر آية فيه (nil = يتابع إلى آخر السورة).
    @Published var stopAt: AyahRef?

    private var player: AVPlayer?
    private var failObserver: NSObjectProtocol?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var playedTimes = 0
    private var onAdvance: ((AyahRef) -> Void)?
    private var onFinish: (() -> Void)?

    var isActive: Bool { current != nil }
    var reciter: AyahReciter { AyahReciters.reciter(id: reciterId) }

    private override init() {
        super.init()
        let d = UserDefaults.standard
        if d.object(forKey: "athar.ayahAudio.repeat") != nil { repeatCount = max(1, d.integer(forKey: "athar.ayahAudio.repeat")) }
        if let r = d.string(forKey: "athar.ayahAudio.reciter") { reciterId = r }
        // مكالمة أو سيري تقطع الصوت: يعكس الشريط التوقّف، ويستأنف إن أذن النظام.
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            Task { @MainActor in self?.handleInterruption(n) }
        }
    }

    private func handleInterruption(_ n: Notification) {
        guard player != nil, let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began: isPlaying = false; updateNowPlayingRate()
        case .ended:
            let opts = AVAudioSession.InterruptionOptions(rawValue: n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            if opts.contains(.shouldResume) {
                try? AVAudioSession.sharedInstance().setActive(true); player?.play(); isPlaying = true
                updateNowPlayingRate()
            }
        @unknown default: break
        }
    }

    // MARK: شاشة القفل

    private var remoteReady = false

    /// أزرار شاشة القفل وسمّاعة الأذن — تُسجَّل مرّة واحدة كما في Recitation، وتُهمَل
    /// ما لم تكن تلاوة الآيات جارية حتى لا تنازع تلاوة السور على الأوامر نفسها.
    private func setupRemoteCommands() {
        guard !remoteReady else { return }
        remoteReady = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.player != nil, !self.isPlaying else { return .noActionableNowPlayingItem }
                self.toggle(); return .success
            }
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.player != nil, self.isPlaying else { return .noActionableNowPlayingItem }
                self.toggle(); return .success
            }
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.player != nil else { return .noActionableNowPlayingItem }
                self.toggle(); return .success
            }
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.player != nil else { return .noActionableNowPlayingItem }
                self.next(); return .success
            }
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.player != nil else { return .noActionableNowPlayingItem }
                self.previous(); return .success
            }
        }
    }

    /// «سورة X · الآية N» على شاشة القفل ومركز التحكّم، بغلاف التطبيق — وإلا بقيت
    /// الشاشة فارغة والتطبيق مغلق مع أنّ الصوت يعمل.
    private func updateNowPlayingInfo(for ref: AyahRef) {
        var info: [String: Any] = [:]
        let surahName = Quran.surah(ref.surah)?.name ?? ""
        info[MPMediaItemPropertyTitle] = "سورة " + surahName + " · الآية " + ref.ayah.counterText
        info[MPMediaItemPropertyArtist] = reciter.name
        info[MPMediaItemPropertyAlbumTitle] = "القرآن الكريم — أثر"
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        if let art = Recitation.nowPlayingArtwork { info[MPMediaItemPropertyArtwork] = art }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// يعكس الإيقاف والاستئناف على زرّ شاشة القفل دون إعادة بناء المعلومات كلّها.
    private func updateNowPlayingRate() {
        guard current != nil, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func url(for ref: AyahRef) -> URL? {
        URL(string: reciter.url + String(format: "%03d%03d.mp3", ref.surah, ref.ayah))
    }

    /// يبدأ من آية ويتابع آيةً آية حتى نهاية السورة أو حدّ الوقوف.
    /// `onFinish` يُنادى حين ينتهي المقطع من تلقائه لا حين يوقفه المستخدم — به تعرف
    /// جلسةُ الأذكار أن التلاوة تمّت فتعدّ مرّةً وتعيد إن بقي من عددها شيء.
    func play(from ref: AyahRef, onAdvance: ((AyahRef) -> Void)? = nil, onFinish: (() -> Void)? = nil) {
        self.onAdvance = onAdvance
        self.onFinish = onFinish
        Recitation.shared.pause()                     // لا يتداخل صوتان
        NotificationCenter.default.post(name: .atharAudioStarted, object: nil)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        playedTimes = 0
        load(ref)
    }

    private func load(_ ref: AyahRef) {
        guard let url = url(for: ref) else { return }
        tearDown()
        current = ref
        isLoading = true
        failed = false
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.status == .readyToPlay { self.isLoading = false; self.failed = false }
                if item.status == .failed { self.isLoading = false; self.isPlaying = false; self.fail() }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.finishedOne() }
        }
        // انقطاع الشبكة أثناء التشغيل يصل من هذا الطريق لا من status — وهو ما ترصده
        // تلاوة السورة والإذاعة، ولم يكن يرصده هذا وحده.
        failObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.fail() }
        }
        p.play()
        isPlaying = true
        setupRemoteCommands()
        updateNowPlayingInfo(for: ref)
        onAdvance?(ref)
    }

    private func finishedOne() {
        guard let ref = current else { return }
        playedTimes += 1
        if playedTimes < repeatCount {
            player?.seek(to: .zero)
            player?.play()
            return
        }
        playedTimes = 0
        if let stopAt, ref >= stopAt { let done = onFinish; stop(); done?(); return }
        guard let next = Quran.next(after: ref), next.surah == ref.surah else {
            let done = onFinish; stop(); done?(); return
        }
        load(next)
    }

    /// هل بعد الآية الجارية آيةٌ في سورتها؟ (وقبلها؟) — الزرّان كانا حيَّين في
    /// المظهر ميّتين في العمل عند طرفَي السورة، فيظنّهما القارئ معطوبين.
    var canGoNext: Bool {
        guard let ref = current, let n = Quran.next(after: ref) else { return false }
        return n.surah == ref.surah
    }
    var canGoPrevious: Bool {
        guard let ref = current, let p = Quran.previous(before: ref) else { return false }
        return p.surah == ref.surah
    }

    func toggle() {
        guard let p = player else { return }
        // على مشغّلٍ فاشل لا يُرفع علم التشغيل: الرمز لا يقول ما ليس بواقع.
        if isPlaying { p.pause(); isPlaying = false }
        else if !failed { p.play(); isPlaying = true }
        updateNowPlayingRate()
    }

    /// يُعلن الفشل ويطوي ما بُني عليه: التلاوة لن تتمّ، فمن ينتظر تمامها (جلسةُ
    /// الأذكار) يُنادى لينتهي بدل أن يبقى معلّقًا على آيةٍ لا تُقرأ.
    private func fail() {
        guard !failed else { return }
        failed = true
        isLoading = false
        isPlaying = false
        let done = onFinish
        onFinish = nil
        done?()
    }

    func next() {
        guard let ref = current, let n = Quran.next(after: ref), n.surah == ref.surah else { return }
        playedTimes = 0; load(n)
    }

    func previous() {
        guard let ref = current, ref.ayah > 1 else { return }
        playedTimes = 0; load(AyahRef(surah: ref.surah, ayah: ref.ayah - 1))
    }

    func stop() {
        onFinish = nil
        tearDown()
        current = nil
        isPlaying = false
        isLoading = false
        stopAt = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        // يُستدعى بلا شرط عند إغلاق القارئ والتفسير، فلا نُطفئ الجلسة تحت التلاوة ولا الإذاعة.
        if !Recitation.shared.isPlaying, !RadioPlayer.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func tearDown() {
        if let o = endObserver { NotificationCenter.default.removeObserver(o); endObserver = nil }
        if let o = failObserver { NotificationCenter.default.removeObserver(o); failObserver = nil }
        statusObserver = nil
        player?.pause()
        player = nil
    }
}
