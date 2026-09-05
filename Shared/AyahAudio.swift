import Foundation
import AVFoundation
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
    /// عدد تكرار كل آية (١ = بلا تكرار). للحفظ ٣ أو ٥ أو ١٠.
    @Published var repeatCount: Int = 1 { didSet { UserDefaults.standard.set(repeatCount, forKey: "athar.ayahAudio.repeat") } }
    @Published var reciterId: String = AyahReciters.all[0].id { didSet { UserDefaults.standard.set(reciterId, forKey: "athar.ayahAudio.reciter") } }
    /// مدى التشغيل: يقف عند آخر آية فيه (nil = يتابع إلى آخر السورة).
    @Published var stopAt: AyahRef?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: NSKeyValueObservation?
    private var playedTimes = 0
    private var onAdvance: ((AyahRef) -> Void)?

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
        case .began: isPlaying = false
        case .ended:
            let opts = AVAudioSession.InterruptionOptions(rawValue: n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            if opts.contains(.shouldResume) { try? AVAudioSession.sharedInstance().setActive(true); player?.play(); isPlaying = true }
        @unknown default: break
        }
    }

    private func url(for ref: AyahRef) -> URL? {
        URL(string: reciter.url + String(format: "%03d%03d.mp3", ref.surah, ref.ayah))
    }

    /// يبدأ من آية ويتابع آيةً آية حتى نهاية السورة أو حدّ الوقوف.
    func play(from ref: AyahRef, onAdvance: ((AyahRef) -> Void)? = nil) {
        self.onAdvance = onAdvance
        Recitation.shared.pause()                     // لا يتداخل صوتان
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
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self else { return }
                if item.status == .readyToPlay { self.isLoading = false }
                if item.status == .failed { self.isLoading = false; self.isPlaying = false }
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.finishedOne() }
        }
        p.play()
        isPlaying = true
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
        if let stopAt, ref >= stopAt { stop(); return }
        guard let next = Quran.next(after: ref), next.surah == ref.surah else { stop(); return }
        load(next)
    }

    func toggle() {
        guard let p = player else { return }
        if isPlaying { p.pause(); isPlaying = false } else { p.play(); isPlaying = true }
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
        tearDown()
        current = nil
        isPlaying = false
        isLoading = false
        stopAt = nil
        if !Recitation.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func tearDown() {
        if let o = endObserver { NotificationCenter.default.removeObserver(o); endObserver = nil }
        statusObserver = nil
        player?.pause()
        player = nil
    }
}
