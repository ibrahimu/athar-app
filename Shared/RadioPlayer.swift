import Foundation
import AVFoundation
import MediaPlayer
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - مشغّل إذاعة القرآن الكريم
//
// بثّ حيّ بلا بداية ولا نهاية: «الإيقاف» يقطع الاتصال، و«التشغيل» يعود إلى اللحظة الحيّة
// (لا إلى ما تجمّع في الذاكرة المؤقّتة فيتأخّر عن الهواء). يستمرّ في الخلفية وعلى شاشة القفل
// كالتلاوة، ولا يتداخل مع مشغّلَي التلاوة والآية.

@MainActor
final class RadioPlayer: ObservableObject {
    static let shared = RadioPlayer()

    /// المصدر الجاري — nil حين يكون المشغّل خاملًا (لا زرّ إنهاء ولا شاشة قفل).
    @Published private(set) var source: LiveSource?
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    /// نصّ خطأ يُعرض تحت الزرّ؛ يُمسح مع كل محاولة جديدة.
    @Published private(set) var error: String?

    private var player: AVPlayer?
    private var rateTask: Task<Void, Never>?
    private var statusObserver: NSKeyValueObservation?
    private var failObserver: NSObjectProtocol?
    private var sessionObservers: [NSObjectProtocol] = []
    private var cancellables: Set<AnyCancellable> = []
    private var remoteReady = false

    private init() {
        observeAudioSession()
        // التلاوة أو الآية لا تعرفان الإذاعة (ملفاهما ليسا لنا)، فنراقبهما نحن:
        // متى بدأ أحدهما أُنهي البثّ حتى لا يُسمع صوتان معًا.
        Recitation.shared.$isPlaying
            .dropFirst()
            .sink { [weak self] playing in
                guard playing else { return }
                Task { @MainActor in self?.stopIfActive() }
            }
            .store(in: &cancellables)
        AyahAudio.shared.$isPlaying
            .dropFirst()
            .sink { [weak self] playing in
                guard playing else { return }
                Task { @MainActor in self?.stopIfActive() }
            }
            .store(in: &cancellables)
    }

    /// مكالمة أو «سيري» توقف الصوت: نقطع الاتصال، ونعود للهواء إن أذن النظام بالاستئناف.
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
                guard self.source != nil else { return }
                switch type {
                case .began:
                    self.pause()
                case .ended:
                    let opts = AVAudioSession.InterruptionOptions(
                        rawValue: n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
                    if opts.contains(.shouldResume) { self.resume() }
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
            MainActor.assumeIsolated { if self.source != nil { self.pause() } }   // نُزعت السمّاعة: لا نفاجئه بالمكبّر
        })
    }

    // MARK: التحكّم

    /// يبدأ بثّ الإذاعة. يُنهي التلاوة والآية أولًا (لا إيقافًا مؤقّتًا: الإيقاف المؤقّت يُبقي
    /// التلاوة تستجيب لزرّ «تشغيل» في شاشة القفل ولنهاية المكالمة، فتعود فوق الإذاعة).
    func play(_ src: LiveSource = .radio) {
        guard let url = src.streamURL else { return }
        Recitation.shared.stop()
        AyahAudio.shared.stop()
        NotificationCenter.default.post(name: .atharAudioStarted, object: nil)   // مشغّل YouTube يوقف فيديوه
        teardown()
        source = src
        error = nil

        activateSession()
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.automaticallyWaitsToMinimizeStalling = true
        player = p
        isBuffering = true

        // الحقيقة من المشغّل نفسه: انقطاع الشبكة أو توقّف النظام يظهران في الواجهة فورًا.
        rateTask = Task { [weak self] in
            for await st in p.publisher(for: \.timeControlStatus).values {
                guard let self, self.player === p else { return }
                self.isPlaying = st != .paused
                self.isBuffering = st == .waitingToPlayAtSpecifiedRate
                self.updateNowPlayingRate()
            }
        }
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, item.status == .failed else { return }
                self.fail()
            }
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.fail() }
        }

        p.play()
        isPlaying = true
        setupRemoteCommands()
        updateNowPlayingInfo()
    }

    /// يقطع الاتصال ويُبقي المصدر: شاشة القفل تعرض الإذاعة متوقّفة، والعودة بـ resume().
    func pause() {
        teardown()
        isPlaying = false
        isBuffering = false
        updateNowPlayingRate()
    }

    /// عودة إلى الهواء: إعادة اتصال لا استكمالٌ لما تجمّع قبل الإيقاف.
    func resume() {
        guard let src = source else { return }
        play(src)
    }

    func toggle() {
        if isPlaying { pause() } else if source != nil { resume() } else { play() }
    }

    /// إنهاء كامل: لا اتصال ولا شاشة قفل ولا جلسة صوت.
    func stop() {
        teardown()
        source = nil
        isPlaying = false
        isBuffering = false
        error = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        if !Recitation.shared.isPlaying, !AyahAudio.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private func stopIfActive() {
        guard source != nil else { return }
        teardown()
        source = nil
        isPlaying = false
        isBuffering = false
        error = nil
        // لا نُطفئ الجلسة ولا شاشة القفل: من بدأ الصوت الآخر يملكهما.
    }

    private func fail() {
        teardown()
        isPlaying = false
        isBuffering = false
        error = loc("تعذّر الاتصال بالإذاعة. تحقّق من الإنترنت وحاول مجددًا.")
        updateNowPlayingRate()
    }

    private func teardown() {
        rateTask?.cancel(); rateTask = nil
        statusObserver = nil
        if let o = failObserver { NotificationCenter.default.removeObserver(o); failObserver = nil }
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default)
        try? s.setActive(true)
    }

    // MARK: شاشة القفل

    private func setupRemoteCommands() {
        guard !remoteReady else { return }
        remoteReady = true
        let c = MPRemoteCommandCenter.shared()
        // أهداف التلاوة تبقى مسجّلة معنا؛ نستجيب فقط حين تكون الإذاعة هي الجارية.
        c.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.source != nil else { return .noActionableNowPlayingItem }
                self.resume(); return .success
            }
        }
        c.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.source != nil else { return .noActionableNowPlayingItem }
                self.pause(); return .success
            }
        }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            return MainActor.assumeIsolated {
                guard self.source != nil else { return .noActionableNowPlayingItem }
                self.toggle(); return .success
            }
        }
    }

    private func updateNowPlayingInfo() {
        guard let src = source else { return }
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = src.title
        info[MPMediaItemPropertyArtist] = "هيئة الإذاعة والتلفزيون السعودية"
        info[MPMediaItemPropertyAlbumTitle] = "البث المباشر — أثر"
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        #if canImport(UIKit)
        if let art = UIImage(named: "NowPlayingArt") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        #endif
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func updateNowPlayingRate() {
        guard source != nil, var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
