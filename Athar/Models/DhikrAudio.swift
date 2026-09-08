import Foundation
import AVFoundation

// MARK: - تسجيل الذكر بصوت قارئ
//
// النطق المركَّب خشنٌ في الأذكار كما هو نشازٌ في القرآن؛ وإنما احتُمل لأن التسجيل
// لم يكن. فهذه الطبقة تُقدّم التسجيل متى وُجد: ملفٌّ باسم الذكر في الحزمة يُشغَّل
// بصوت صاحبه، وإن لم يوجد رجع الأمر إلى النطق كما كان. فمتى سُجّلت الأذكار وأُضيفت
// ملفاتُها عملت بلا تعديل سطرٍ واحد — الاسم وحده هو العقد بيننا وبين التسجيل.
//
// التسمية: dhikr-<القسم>-<الذكر>.m4a  (مثال: dhikr-tasbih-t05.m4a)
@MainActor
final class DhikrAudio: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = DhikrAudio()

    @Published private(set) var playing = false

    private var player: AVAudioPlayer?
    private var remaining = 0
    private var onEach: (() -> Void)?

    private override init() { super.init() }

    /// هل لهذا الذكر تسجيل في الحزمة؟ به تُقرَّر هيئة الزرّ قبل الضغط.
    static func url(category: String, dhikr: String) -> URL? {
        let name = "dhikr-\(category)-\(dhikr)"
        return Bundle.main.url(forResource: name, withExtension: "m4a")
            ?? Bundle.main.url(forResource: name, withExtension: "caf")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
    }

    static func has(category: String, dhikr: String) -> Bool {
        url(category: category, dhikr: dhikr) != nil
    }

    /// يُشغّل التسجيل `times` مرّة، ويُنادى `onEach` عند تمام كل مرّة — كما يفعل النطق،
    /// فيبقى العدّ واحدًا في الطريقين.
    func start(category: String, dhikr: String, times: Int, onEach: @escaping () -> Void) {
        stop()
        guard let url = Self.url(category: category, dhikr: dhikr) else { return }
        // لا يجتمع صوتان: التلاوة والإذاعة والبثّ تُخفَض قبل أن يُرفع هذا.
        Recitation.shared.pause()
        AyahAudio.shared.stop()
        RadioPlayer.shared.pause()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio)
        try? session.setActive(true)
        guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
        p.delegate = self
        player = p
        remaining = max(1, times)
        self.onEach = onEach
        playing = true
        p.play()
    }

    func stop() {
        guard playing || player != nil else { return }
        player?.stop()
        player = nil
        remaining = 0
        onEach = nil
        playing = false
        if !Recitation.shared.isPlaying {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            guard self.playing else { return }
            self.onEach?()
            self.remaining -= 1
            if self.remaining > 0, let p = self.player {
                p.currentTime = 0
                p.play()
            } else {
                self.stop()
            }
        }
    }
}
