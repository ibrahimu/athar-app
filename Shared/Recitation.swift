import Foundation
import AVFoundation
import MediaPlayer
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - القارئ

/// قارئ من موقع «MP3Quran.net» — تلاوات متاحة للعموم بلا اشتراك ولا ترخيص،
/// وكلها برواية حفص عن عاصم مرتّلة. الملف يُبنى: العنوان + رقم السورة بثلاث خانات.
struct Reciter: Identifiable, Hashable, Codable {
    let id: String        // مفتاح المجلّد على الخادم — ثابت لا يتغيّر
    let name: String      // الاسم كما يُعرف به
    let base: String      // عنوان المجلّد، منتهٍ بشرطة مائلة

    func url(surah: Int) -> URL? {
        guard (1...114).contains(surah) else { return nil }
        return URL(string: base + String(format: "%03d", surah) + ".mp3")
    }
}

enum RecitationLibrary {
    /// قائمة مختارة، تحقّقنا من عمل روابطها لكل السور.
    static let reciters: [Reciter] = [
        .init(id: "afs",    name: "مشاري العفاسي",        base: "https://server8.mp3quran.net/afs/"),
        .init(id: "a_jbr",  name: "علي جابر",              base: "https://server11.mp3quran.net/a_jbr/"),
        .init(id: "husr",   name: "محمود خليل الحصري",     base: "https://server13.mp3quran.net/husr/"),
        .init(id: "minsh",  name: "محمد صديق المنشاوي",    base: "https://server10.mp3quran.net/minsh/"),
        .init(id: "basit",  name: "عبدالباسط عبدالصمد",    base: "https://server7.mp3quran.net/basit/"),
        .init(id: "sds",    name: "عبدالرحمن السديس",      base: "https://server11.mp3quran.net/sds/"),
        .init(id: "shur",   name: "سعود الشريم",           base: "https://server7.mp3quran.net/shur/"),
        .init(id: "maher",  name: "ماهر المعيقلي",         base: "https://server12.mp3quran.net/maher/"),
        .init(id: "yasser", name: "ياسر الدوسري",          base: "https://server11.mp3quran.net/yasser/"),
        .init(id: "shatri", name: "أبو بكر الشاطري",       base: "https://server11.mp3quran.net/shatri/"),
        .init(id: "qtm",    name: "ناصر القطامي",          base: "https://server6.mp3quran.net/qtm/"),
        .init(id: "hthfi",  name: "علي الحذيفي",           base: "https://server9.mp3quran.net/hthfi/"),
        .init(id: "abkr",   name: "إدريس أبكر",            base: "https://server6.mp3quran.net/abkr/"),
        .init(id: "ajm",    name: "أحمد العجمي",           base: "https://server10.mp3quran.net/ajm/"),
        .init(id: "ayyub",  name: "محمد أيوب",             base: "https://server8.mp3quran.net/ayyub/"),
    ]

    static func reciter(id: String) -> Reciter? { reciters.first { $0.id == id } }

    static let `default` = reciters[0]

    /// جذر تخزين التلاوات المحمَّلة — خارج «المستندات» فلا يظهر للمستخدم كملفات،
    /// ومستثنى من نسخ iCloud لأنه قابل للتنزيل من جديد.
    static var root: URL {
        let fm = FileManager.default
        let dir = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                               appropriateFor: nil, create: true))
            ?? fm.temporaryDirectory
        let out = dir.appendingPathComponent("Recitations", isDirectory: true)
        if !fm.fileExists(atPath: out.path) {
            try? fm.createDirectory(at: out, withIntermediateDirectories: true)
            var u = out
            var rv = URLResourceValues()
            rv.isExcludedFromBackup = true
            try? u.setResourceValues(rv)
        }
        return out
    }

    static func localURL(reciter: String, surah: Int) -> URL {
        root.appendingPathComponent(reciter, isDirectory: true)
            .appendingPathComponent(String(format: "%03d", surah) + ".mp3")
    }

    static func isDownloaded(reciter: String, surah: Int) -> Bool {
        FileManager.default.fileExists(atPath: localURL(reciter: reciter, surah: surah).path)
    }
}

// MARK: - وضع التكرار

/// ما يفعله المشغّل حين تنتهي السورة.
enum RepeatMode: String, CaseIterable, Identifiable {
    case next   // ينتقل إلى السورة التالية
    case one    // يعيد السورة نفسها
    case once   // يقف عند نهايتها

    var id: String { rawValue }

    var title: String {
        switch self {
        case .next: return loc("متابعة السور")
        case .one:  return loc("تكرار السورة")
        case .once: return loc("سورة واحدة")
        }
    }

    var icon: String {
        switch self {
        case .next: return "repeat"
        case .one:  return "repeat.1"
        case .once: return "1.circle"
        }
    }

    var next_: RepeatMode {
        switch self {
        case .next: return .one
        case .one:  return .once
        case .once: return .next
        }
    }
}

// MARK: - مؤقّت النوم

/// إيقافٌ مؤجَّل للتلاوة — لمن يسمع حتى ينام.
enum SleepTimer: Equatable, Identifiable, Hashable {
    case off
    case endOfSurah
    case minutes(Int)

    static let choices: [SleepTimer] = [.off, .minutes(5), .minutes(10), .minutes(15),
                                        .minutes(30), .minutes(45), .minutes(60), .endOfSurah]

    var id: String {
        switch self {
        case .off:        return "off"
        case .endOfSurah: return "surah"
        case .minutes(let m): return "m\(m)"
        }
    }

    var title: String {
        switch self {
        case .off:        return loc("بلا مؤقّت")
        case .endOfSurah: return loc("عند نهاية السورة")
        case .minutes(let m):
            // تمييز العدد: من ٣ إلى ١٠ «دقائق»، وما عداه «دقيقة».
            return (3...10).contains(m) ? loc("بعد %1$@ دقائق", m.counterText)
                                        : loc("بعد %1$@ دقيقة", m.counterText)
        }
    }

    var isOn: Bool { self != .off }
}

// MARK: - حالة التنزيل

enum DownloadState: Equatable {
    case idle
    case waiting
    case downloading(Double)   // ٠..١
    case done
    case failed
}

// MARK: - المشغّل والمنزّل

/// يشغّل سورة كاملة — من الملف المحمَّل إن وُجد، وإلا بثًّا من الشبكة.
/// كل اتصال بالشبكة هنا لا يقع إلا بضغطة المستخدم على «تشغيل» أو «تنزيل».
@MainActor
final class Recitation: NSObject, ObservableObject {
    static let shared = Recitation()

    @Published private(set) var surah: Int?
    @Published private(set) var reciterId: String = RecitationLibrary.default.id
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var progress: Double = 0     // ٠..١
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var failed = false
    /// حالات التنزيل بمفتاح "قارئ/سورة".
    @Published private(set) var downloads: [String: DownloadState] = [:]

    /// ما يفعله المشغّل عند نهاية السورة.
    @Published var repeatMode: RepeatMode = .next
    /// سرعة التلاوة — بعضهم يستأنس بالإبطاء في الحفظ.
    @Published var rate: Float = 1.0 { didSet { if isPlaying { player?.rate = rate } } }
    /// مؤقّت النوم ولحظة انطفائه (للعدّ التنازلي في الواجهة).
    @Published private(set) var sleep: SleepTimer = .off
    @Published private(set) var sleepEndsAt: Date?
    /// آخر ما استُمع إليه — لعرض «متابعة الاستماع» بعد إغلاق التطبيق.
    @Published private(set) var lastPlayed: Int?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusTask: Task<Void, Never>?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()
    private var tasks: [Int: String] = [:]   // taskIdentifier -> key
    private var running: [Int: URLSessionDownloadTask] = [:]   // لإلغائها عند الحذف
    private var sleepTask: Task<Void, Never>?
    /// يعكس حالة المشغّل الحقيقية (توقّف النظام له في مكالمة مثلًا) على isPlaying.
    private var rateTask: Task<Void, Never>?
    private var failObserver: NSObjectProtocol?
    private var sessionObservers: [NSObjectProtocol] = []
    #if canImport(UIKit)
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    #endif

    var reciter: Reciter { RecitationLibrary.reciter(id: reciterId) ?? RecitationLibrary.default }

    private static let reciterKey = "athar.recitation.reciter"
    private static let lastKey = "athar.recitation.lastSurah"

    private override init() {
        super.init()
        if let saved = UserDefaults(suiteName: AtharStore.appGroup)?.string(forKey: Self.reciterKey),
           RecitationLibrary.reciter(id: saved) != nil {
            reciterId = saved
        }
        let last = UserDefaults(suiteName: AtharStore.appGroup)?.integer(forKey: Self.lastKey) ?? 0
        if (1...114).contains(last) { lastPlayed = last }
        observeAudioSession()
    }

    /// مكالمة أو «سيري» توقف الصوت من خارجنا، ونزع السمّاعة كذلك — نتابع ذلك
    /// حتى لا تبقى الواجهة تقول «يُتلى الآن» والصوت صامت.
    private func observeAudioSession() {
        let nc = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        sessionObservers.append(nc.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] n in
            guard let self,
                  let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            MainActor.assumeIsolated {
                switch type {
                case .began:
                    self.pause()
                case .ended:
                    let opts = AVAudioSession.InterruptionOptions(
                        rawValue: n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                    if opts.contains(.shouldResume), self.surah != nil { self.resume() }
                @unknown default:
                    break
                }
            }
        })
        sessionObservers.append(nc.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] n in
            guard let self,
                  let raw = n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable else { return }
            MainActor.assumeIsolated { self.pause() }   // نُزعت السمّاعة: لا نفاجئه بالمكبّر
        })
    }

    // MARK: القارئ

    func select(_ r: Reciter) {
        guard r.id != reciterId else { return }
        let wasPlaying = isPlaying
        let s = surah
        reciterId = r.id
        UserDefaults(suiteName: AtharStore.appGroup)?.set(r.id, forKey: Self.reciterKey)
        // نعيد تحميل السورة نفسها بصوت القارئ الجديد، ونبقيها متوقّفة إن كانت كذلك.
        // لا نمرّ بـ stop() حتى لا يضيع مؤقّت النوم ولا تُفرغ الصفحة.
        guard let s else { return }
        play(surah: s)
        if !wasPlaying { pause() }
    }

    // MARK: التشغيل

    static func key(_ reciter: String, _ surah: Int) -> String { "\(reciter)/\(surah)" }

    func state(reciter: String, surah: Int) -> DownloadState {
        if RecitationLibrary.isDownloaded(reciter: reciter, surah: surah) { return .done }
        return downloads[Self.key(reciter, surah)] ?? .idle
    }

    /// يشغّل السورة، أو يوقف/يستأنف إن كانت هي الجارية.
    func toggle(surah s: Int) {
        if surah == s, player != nil, !failed {
            isPlaying ? pause() : resume()
        } else {
            play(surah: s)   // جديدة، أو فشل تحميلها فنعيد المحاولة (ربما نُزّلت الآن)
        }
    }

    func play(surah s: Int) {
        teardown()
        failed = false
        surah = s

        let local = RecitationLibrary.localURL(reciter: reciterId, surah: s)
        let url: URL?
        if FileManager.default.fileExists(atPath: local.path) {
            url = local
        } else {
            url = reciter.url(surah: s)
        }
        guard let url else { failed = true; return }

        lastPlayed = s
        UserDefaults(suiteName: AtharStore.appGroup)?.set(s, forKey: Self.lastKey)

        activateSession()
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        isBuffering = !url.isFileURL

        // الحقيقة من المشغّل نفسه: لو أوقفه النظام (مكالمة) أو تعثّر البثّ، تتبعه الواجهة.
        rateTask = Task { [weak self] in
            for await st in p.publisher(for: \.timeControlStatus).values {
                guard let self else { return }
                self.isPlaying = st != .paused
                self.isBuffering = st == .waitingToPlayAtSpecifiedRate
                self.updateNowPlayingTime()
            }
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.failed = true
                self.isPlaying = false
                self.isBuffering = false
            }
        }

        timeObserver = p.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.4, preferredTimescale: 600), queue: .main
        ) { [weak self] t in
            guard let self else { return }
            MainActor.assumeIsolated {
                let d = item.duration.seconds
                self.duration = (d.isFinite && d > 0) ? d : self.duration
                self.elapsed = t.seconds
                self.progress = self.duration > 0 ? min(1, max(0, t.seconds / self.duration)) : 0
                if self.isBuffering, t.seconds > 0 { self.isBuffering = false }
                self.updateNowPlayingTime()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                // مؤقّت «عند نهاية السورة» له الأسبقية على وضع التكرار.
                if self.sleep == .endOfSurah { self.cancelSleep(); self.stop(); return }
                switch self.repeatMode {
                case .one:
                    p.seek(to: .zero); p.play()
                    p.rate = self.rate      // play() يعيد السرعة إلى ١، فنثبّت المختارة
                case .next:
                    if let cur = self.surah, cur < 114 { self.play(surah: cur + 1) } else { self.stop() }
                case .once:
                    p.seek(to: .zero)
                    self.isPlaying = false
                    self.progress = 0; self.elapsed = 0
                    self.updateNowPlayingTime()
                }
            }
        }

        // فشل التحميل (لا إنترنت مثلًا) — أظهر الخطأ بدل صمتٍ غامض.
        statusTask = Task { [weak self] in
            for await status in item.publisher(for: \.status).values {
                guard let self else { return }
                if status == .failed {
                    self.failed = true
                    self.isBuffering = false
                    self.isPlaying = false
                    return
                }
                if status == .readyToPlay { return }
            }
        }

        p.play()
        p.rate = rate
        isPlaying = true
        setupRemoteCommands()
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingTime()
    }

    func resume() {
        // بلا مشغّل، أو مشغّل مات بفشل التحميل: أعد التحميل بدل «استئناف» صامت.
        guard player != nil, !failed else { if let s = surah { play(surah: s) }; return }
        activateSession()
        player?.play()
        player?.rate = rate
        isPlaying = true
        updateNowPlayingTime()
    }

    func stop() {
        teardown()
        sleepTask?.cancel(); sleepTask = nil
        sleep = .off; sleepEndsAt = nil
        surah = nil
        isPlaying = false
        isBuffering = false
        progress = 0; elapsed = 0; duration = 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func seek(to fraction: Double) {
        guard let p = player, duration > 0 else { return }
        let t = CMTime(seconds: duration * min(1, max(0, fraction)), preferredTimescale: 600)
        p.seek(to: t)
    }

    /// تقديم/ترجيع بعدد ثوانٍ — قيمة سالبة ترجع للخلف.
    func seek(by seconds: Double) {
        guard let p = player else { return }
        let target = max(0, min(duration > 0 ? duration : .greatestFiniteMagnitude,
                                elapsed + seconds))
        p.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func next() { if let s = surah, s < 114 { play(surah: s + 1) } }
    func previous() {
        // كزرّ الأغاني: يرجع لبداية السورة أولًا، وإن كان في أوّلها فإلى ما قبلها.
        if elapsed > 3 { player?.seek(to: .zero); return }
        if let s = surah, s > 1 { play(surah: s - 1) }
    }

    // MARK: مؤقّت النوم

    func setSleep(_ t: SleepTimer) {
        sleepTask?.cancel(); sleepTask = nil
        sleep = t
        switch t {
        case .off, .endOfSurah:
            sleepEndsAt = nil
        case .minutes(let m):
            let ends = Date().addingTimeInterval(Double(m) * 60)
            sleepEndsAt = ends
            sleepTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(Double(m) * 60 * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self else { return }
                    self.pause()
                    self.sleep = .off
                    self.sleepEndsAt = nil
                }
            }
        }
    }

    func cancelSleep() { setSleep(.off) }

    private func teardown() {
        statusTask?.cancel(); statusTask = nil
        rateTask?.cancel(); rateTask = nil
        if let o = failObserver { NotificationCenter.default.removeObserver(o); failObserver = nil }
        if let o = timeObserver { player?.removeTimeObserver(o); timeObserver = nil }
        if let o = endObserver { NotificationCenter.default.removeObserver(o); endObserver = nil }
        player?.pause()
        player = nil
    }

    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio)
        try? s.setActive(true)
    }

    // MARK: شاشة القفل

    private var remoteReady = false

    private func setupRemoteCommands() {
        guard !remoteReady else { return }
        remoteReady = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated { self.resume(); return .success }
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated { self.pause(); return .success }
        }
        c.nextTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated { self.next(); return .success }
        }
        c.previousTrackCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated { self.previous(); return .success }
        }
    }

    private func updateNowPlayingInfo() {
        guard let s = surah, let su = Quran.surah(s) else { return }
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "سورة \(su.name)"
        info[MPMediaItemPropertyArtist] = reciter.name
        info[MPMediaItemPropertyAlbumTitle] = "القرآن الكريم — أثر"
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingTime() {
        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: التنزيل

    /// أقصى تنزيلات متزامنة — نبقيها قليلة حتى لا نُثقل الشبكة ولا الخادم.
    private static let maxParallel = 3
    /// طابور الانتظار لتنزيل جماعي (تنزيل الكل أو المحدَّد).
    private var queue: [(reciter: Reciter, surah: Int)] = []

    /// عدد ما ينتظر أو يُنزَّل الآن — لعرض تقدّم التنزيل الجماعي.
    /// نعدّ الطابور والمهامّ الجارية فقط؛ فعلامات «ينتظر» في `downloads` تُكتب
    /// لما في الطابور أيضًا، وعدّها هنا كان يوقف الضخّ قبل أن يبدأ.
    var pendingCount: Int { queue.count + tasks.count }

    private var activeCount: Int { tasks.count }

    /// يضيف سورًا إلى طابور التنزيل ثم يبدأ ما يتّسع له.
    func downloadMany(_ surahs: [Int], reciter r: Reciter? = nil) {
        let rec = r ?? reciter
        for s in surahs where !RecitationLibrary.isDownloaded(reciter: rec.id, surah: s) {
            let k = Self.key(rec.id, s)
            if case .downloading = downloads[k] { continue }
            if downloads[k] == .waiting { continue }
            if queue.contains(where: { $0.reciter.id == rec.id && $0.surah == s }) { continue }
            queue.append((rec, s))
            downloads[k] = .waiting
        }
        pump()
    }

    /// يلغي الطابور المنتظر (ما بدأ فعلًا يُترك ليكمل).
    func cancelQueue() {
        for item in queue { downloads.removeValue(forKey: Self.key(item.reciter.id, item.surah)) }
        queue.removeAll()
    }

    private func pump() {
        while activeCount < Self.maxParallel, !queue.isEmpty {
            let item = queue.removeFirst()
            start(surah: item.surah, reciter: item.reciter)
        }
    }

    /// تنزيل سورة واحدة — يمرّ بالطابور نفسه فلا يتجاوز حدّ التوازي.
    func download(surah s: Int, reciter r: Reciter? = nil) {
        downloadMany([s], reciter: r)
    }

    private func start(surah s: Int, reciter rec: Reciter) {
        guard let url = rec.url(surah: s) else {
            downloads[Self.key(rec.id, s)] = .failed
            return
        }
        let k = Self.key(rec.id, s)
        downloads[k] = .waiting
        let task = session.downloadTask(with: url)
        tasks[task.taskIdentifier] = k
        running[task.taskIdentifier] = task
        task.resume()
        updateBackgroundAssertion()
    }

    /// يطلب من النظام مهلةً لإتمام التنزيلات الجارية بعد الخروج من التطبيق.
    /// (مهلة محدودة لا خلفية دائمة — تكفي لبضع سور، وما بقي يُستأنف عند العودة.)
    private func updateBackgroundAssertion() {
        #if canImport(UIKit)
        if tasks.isEmpty {
            if bgTask != .invalid { UIApplication.shared.endBackgroundTask(bgTask); bgTask = .invalid }
        } else if bgTask == .invalid {
            bgTask = UIApplication.shared.beginBackgroundTask(withName: "athar.recitation.download") { [weak self] in
                guard let self else { return }
                MainActor.assumeIsolated {
                    UIApplication.shared.endBackgroundTask(self.bgTask)
                    self.bgTask = .invalid
                }
            }
        }
        #endif
    }

    /// يلغي تنزيل سورة واحدة — من الطابور إن كانت تنتظر، أو المهمّة إن كانت جارية.
    func cancel(surah s: Int, reciter r: Reciter? = nil) {
        let rec = r ?? reciter
        let k = Self.key(rec.id, s)
        queue.removeAll { $0.reciter.id == rec.id && $0.surah == s }
        if let tid = tasks.first(where: { $0.value == k })?.key {
            tasks.removeValue(forKey: tid)          // المندوب يجد المفتاح غائبًا فيتجاهل الإلغاء
            running.removeValue(forKey: tid)?.cancel()
        }
        downloads.removeValue(forKey: k)
        updateBackgroundAssertion()
        pump()
    }

    /// يلغي المهامّ الجارية والطابور لقارئٍ معيّن (أو للكل) دون أن تُعلَّم فاشلة.
    private func cancelDownloads(reciter id: String?) {
        queue.removeAll { id == nil || $0.reciter.id == id }
        for (tid, key) in tasks where id == nil || key.hasPrefix(id! + "/") {
            tasks.removeValue(forKey: tid)          // المندوب يجد المفتاح غائبًا فيتجاهل الإلغاء
            running.removeValue(forKey: tid)?.cancel()
            downloads.removeValue(forKey: key)
        }
        updateBackgroundAssertion()
    }

    func delete(surah s: Int, reciter r: Reciter? = nil) {
        let rec = r ?? reciter
        let wasLocalAndCurrent = surah == s && reciterId == rec.id
            && RecitationLibrary.isDownloaded(reciter: rec.id, surah: s)
        try? FileManager.default.removeItem(at: RecitationLibrary.localURL(reciter: rec.id, surah: s))
        downloads.removeValue(forKey: Self.key(rec.id, s))
        // كانت تُتلى من الملف المحذوف؟ نتابعها بثًّا من الشبكة بدل قطع التلاوة.
        if wasLocalAndCurrent {
            let wasPlaying = isPlaying
            play(surah: s)
            if !wasPlaying { pause() }
        }
        objectWillChange.send()
    }

    /// عدد السور المحمَّلة وحجمها الكلي لقارئ معيّن (أو لكل القرّاء).
    func downloadedSummary(reciter id: String? = nil) -> (count: Int, bytes: Int64) {
        let fm = FileManager.default
        let roots: [URL]
        if let id {
            roots = [RecitationLibrary.root.appendingPathComponent(id, isDirectory: true)]
        } else {
            roots = (try? fm.contentsOfDirectory(at: RecitationLibrary.root,
                                                 includingPropertiesForKeys: nil)) ?? []
        }
        var count = 0
        var bytes: Int64 = 0
        for dir in roots {
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
            for f in files where f.pathExtension == "mp3" {
                count += 1
                bytes += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
        }
        return (count, bytes)
    }

    func deleteAll(reciter id: String? = nil) {
        // أوقف ما يخصّ هذا القارئ من طابور ومهامّ، وإلا أعادت ملء المجلّد الذي حُذف للتوّ.
        cancelDownloads(reciter: id)
        let affectsCurrent = (id == nil || id == reciterId) && surah != nil
        let wasLocal = surah.map { RecitationLibrary.isDownloaded(reciter: reciterId, surah: $0) } ?? false
        let fm = FileManager.default
        if let id {
            try? fm.removeItem(at: RecitationLibrary.root.appendingPathComponent(id, isDirectory: true))
            downloads = downloads.filter { !$0.key.hasPrefix(id + "/") }
        } else {
            try? fm.removeItem(at: RecitationLibrary.root)
            downloads.removeAll()
        }
        // الجارية كانت من ملف حُذف الآن؟ نتابعها بثًّا؛ وما عدا ذلك لا نمسّ التلاوة.
        if affectsCurrent, wasLocal, let s = surah {
            let wasPlaying = isPlaying
            play(surah: s)
            if !wasPlaying { pause() }
        }
        objectWillChange.send()
    }
}

// MARK: - مندوب التنزيل

extension Recitation: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // انقل الملف الآن — يُحذف المؤقّت فور رجوع هذه الدالة.
        let id = downloadTask.taskIdentifier
        let fm = FileManager.default
        let staged = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        let moved = (try? fm.moveItem(at: location, to: staged)) != nil
        let ok = (downloadTask.response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false

        Task { @MainActor [weak self] in
            self?.running.removeValue(forKey: id)
            guard let self, let key = self.tasks.removeValue(forKey: id) else {
                try? fm.removeItem(at: staged); return
            }
            defer { self.updateBackgroundAssertion() }
            let parts = key.split(separator: "/")
            guard moved, ok, parts.count == 2, let s = Int(parts[1]) else {
                try? fm.removeItem(at: staged)
                self.downloads[key] = .failed
                return
            }
            let dest = RecitationLibrary.localURL(reciter: String(parts[0]), surah: s)
            try? fm.createDirectory(at: dest.deletingLastPathComponent(),
                                    withIntermediateDirectories: true)
            try? fm.removeItem(at: dest)
            do {
                try fm.moveItem(at: staged, to: dest)
                self.downloads[key] = .done
            } catch {
                try? fm.removeItem(at: staged)
                self.downloads[key] = .failed
            }
            self.pump()
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let f = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let id = downloadTask.taskIdentifier
        Task { @MainActor [weak self] in
            guard let self, let key = self.tasks[id] else { return }
            self.downloads[key] = .downloading(min(1, max(0, f)))
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard error != nil else { return }
        let id = task.taskIdentifier
        Task { @MainActor [weak self] in
            self?.running.removeValue(forKey: id)
            guard let self, let key = self.tasks.removeValue(forKey: id) else { return }
            self.downloads[key] = .failed
            self.pump()
            self.updateBackgroundAssertion()
        }
    }
}

// MARK: - عرض الحجم

extension Int64 {
    /// حجم بوحدة عربية — «٨٣٨ ك.ب» بدل «KB 838»، فالوحدة اللاتينية
    /// ينقلها ترتيب النص ثنائي الاتجاه إلى ما قبل الرقم فتُقرأ مقلوبة.
    var fileSizeText: String {
        let mb = Double(self) / 1_048_576
        if mb >= 1 {
            let v = (mb * 10).rounded() / 10
            return "\(v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)) م.ب"
        }
        return "\(Swift.max(1, Int((Double(self) / 1024).rounded()))) ك.ب"
    }
}
