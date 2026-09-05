import Foundation
import AVFoundation

/// قراءة التفسير بصوت الجهاز (AVSpeechSynthesizer) — بلا إنترنت. أقواس الاستشهاد تُحذف من النطق.
@MainActor
final class TafsirSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    static let shared = TafsirSpeaker()

    @Published private(set) var speaking = false
    private let synth = AVSpeechSynthesizer()
    private var token = 0

    private override init() {
        super.init()
        synth.delegate = self
    }

    /// أفضل صوت عربي متاح على الجهاز (المحسَّن إن وُجد).
    private var voice: AVSpeechSynthesisVoice? {
        let arabic = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ar") }
        return arabic.first { $0.quality == .enhanced } ?? arabic.first ?? AVSpeechSynthesisVoice(language: "ar-SA")
    }

    func speak(_ text: String, marks: (open: Character, close: Character)) {
        stop()
        Recitation.shared.pause()
        AyahAudio.shared.stop()
        var clean = text
        clean.removeAll { $0 == marks.open || $0 == marks.close }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        let u = AVSpeechUtterance(string: clean)
        u.voice = voice
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        u.postUtteranceDelay = 0.2
        token &+= 1
        synth.speak(u)
        speaking = true
    }

    func toggle(_ text: String, marks: (open: Character, close: Character)) {
        if speaking { stop() } else { speak(text, marks: marks) }
    }

    func stop() {
        guard speaking || synth.isSpeaking else { return }
        synth.stopSpeaking(at: .immediate)
        speaking = false
        if !Recitation.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.speaking = false }
    }
}
