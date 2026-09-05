import Foundation
import AVFoundation

/// يقرأ الذكر بصوت الجهاز عددَ مرّاته ويعدّ مع كل قراءة — للسيارة واليدين المشغولتين. بلا إنترنت.
@MainActor
final class DhikrSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = DhikrSpeaker()

    @Published private(set) var speaking = false
    private let synth = AVSpeechSynthesizer()
    private var remaining = 0
    private var text = ""
    private var onEach: (() -> Void)?
    private var onDone: (() -> Void)?

    private override init() { super.init(); synth.delegate = self }

    private var voice: AVSpeechSynthesisVoice? {
        let ar = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ar") }
        return ar.first { $0.quality == .enhanced } ?? ar.first ?? AVSpeechSynthesisVoice(language: "ar-SA")
    }

    /// يقرأ النص `times` مرة؛ بعد كل مرة يُستدعى onEach (للعدّ)، وفي النهاية onDone.
    func start(_ text: String, times: Int, onEach: @escaping () -> Void, onDone: @escaping () -> Void) {
        stop()
        Recitation.shared.pause()
        AyahAudio.shared.stop()
        self.text = text; remaining = max(1, times); self.onEach = onEach; self.onDone = onDone
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio)
        try? s.setActive(true)
        speaking = true
        speakOnce()
    }

    private func speakOnce() {
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        u.postUtteranceDelay = 0.6
        synth.speak(u)
    }

    func stop() {
        guard speaking || synth.isSpeaking else { return }
        synth.stopSpeaking(at: .immediate)
        speaking = false; remaining = 0; onEach = nil; onDone = nil
        if !Recitation.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.speaking else { return }
            self.onEach?()
            self.remaining -= 1
            if self.remaining > 0 { self.speakOnce() } else { self.speaking = false; self.onDone?() }
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
}
