import Foundation
import AVFoundation

/// يسمع المستخدم الأذان كاملًا قبل اختياره — مشغّل صغير مستقلّ عن التلاوة.
@MainActor
final class AthanPreview: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = AthanPreview()

    @Published private(set) var playing: AthanSound?
    private var player: AVAudioPlayer?

    func toggle(_ sound: AthanSound) {
        if playing == sound { stop() } else { play(sound) }
    }

    func play(_ sound: AthanSound) {
        stop()
        guard let name = sound.fileName,
              let url = Bundle.main.url(forResource: name + "-full", withExtension: "m4a") else { return }
        Recitation.shared.pause()                     // لا يتداخل صوتان
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        p.play()
        player = p
        playing = sound
    }

    func stop() {
        player?.stop()
        player = nil
        playing = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
