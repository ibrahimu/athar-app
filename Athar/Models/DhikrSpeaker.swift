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
    /// النطق الجاري: إلغاءُ نطقٍ سابق يصل متأخرًا بعد بدء جلسة جديدة فلا يُطفئها.
    private var currentUtterance: AVSpeechUtterance?

    private override init() { super.init(); synth.delegate = self }

    /// أجود ما في الجهاز من أصوات العربية: المميّز ثم المحسّن ثم المضغوط. والمضغوط
    /// هو «البححة» التي تُسمع على جهازٍ لم يُنزَّل فيه صوتٌ أجود — فيُعرف حاله ليُقال للمستخدم.
    private var voice: AVSpeechSynthesisVoice? {
        let ar = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("ar") }
        return ar.first { $0.quality == .premium }
            ?? ar.first { $0.quality == .enhanced }
            ?? ar.first
            ?? AVSpeechSynthesisVoice(language: "ar-SA")
    }

    /// هل في الجهاز صوتٌ عربيٌّ جيّد؟ إن لم يكن فالنطق مضغوطٌ خشن، ويُنبَّه صاحبه
    /// إلى أنّ في إعدادات النظام صوتًا أجود يُنزَّل مرّة.
    var hasGoodVoice: Bool {
        AVSpeechSynthesisVoice.speechVoices()
            .contains { $0.language.hasPrefix("ar") && $0.quality != .default }
    }

    /// يقرأ النص `times` مرة؛ بعد كل مرة يُستدعى onEach (للعدّ)، وفي النهاية onDone.
    func start(_ text: String, times: Int, onEach: @escaping () -> Void, onDone: @escaping () -> Void) {
        stop()
        Recitation.shared.pause()
        AyahAudio.shared.stop()
        RadioPlayer.shared.pause()                    // وإلا نُطق الذكر فوق البثّ الحيّ
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
        currentUtterance = u
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
            guard self.speaking, utterance === self.currentUtterance else { return }
            self.onEach?()
            self.remaining -= 1
            if self.remaining > 0 { self.speakOnce() } else { self.speaking = false; self.onDone?() }
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in if utterance === self.currentUtterance { self.speaking = false } }
    }
}
