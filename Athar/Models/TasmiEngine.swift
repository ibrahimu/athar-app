import Foundation
import Speech
import AVFoundation

/// التسميع: يستمع لقراءتك ويعيد النصّ المتعرَّف عليه لحظيًّا — على الجهاز حين يتوفّر ذلك.
@MainActor
final class TasmiEngine: NSObject, ObservableObject {
    static let shared = TasmiEngine()

    @Published private(set) var transcript = ""
    @Published private(set) var listening = false
    @Published private(set) var authorized = false
    @Published private(set) var onDevice = false
    @Published var error: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ar-SA"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var available: Bool { recognizer?.isAvailable ?? false }

    func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { c in SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) } }
        guard speech == .authorized else { authorized = false; error = "لم يُسمح بالتعرّف على الكلام — من إعدادات الجهاز ← أثر."; return false }
        let mic = await AVAudioApplication.requestRecordPermission()
        guard mic else { authorized = false; error = "لم يُسمح بالميكروفون."; return false }
        authorized = true
        return true
    }

    func start() {
        guard !listening, let recognizer, recognizer.isAvailable else { error = "التعرّف على العربية غير متاح على هذا الجهاز الآن."; return }
        error = nil; transcript = ""
        Recitation.shared.pause(); AyahAudio.shared.stop()
        let session = AVAudioSession.sharedInstance()
        do {
            // فئة التسجيل لا تقبل duckOthers (تخصّ فئات التشغيل) فكان الضبط يفشل على بعض الأجهزة.
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { self.error = "تعذّر فتح الميكروفون."; return }

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true; onDevice = true } else { onDevice = false }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in self?.request?.append(buffer) }
        engine.prepare()
        do { try engine.start() } catch {
            // لا نترك اللاقط مثبَّتًا والجلسة مفتوحة إن فشل التشغيل.
            input.removeTap(onBus: 0); request = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            self.error = "تعذّر تشغيل الصوت."; return
        }
        listening = true
        task = recognizer.recognitionTask(with: req) { [weak self] result, err in
            Task { @MainActor in
                guard let self else { return }
                if let result { self.transcript = result.bestTranscription.formattedString }
                if err != nil || (result?.isFinal ?? false) { self.stop() }
            }
        }
    }

    /// يمسح النصّ والخطأ قبل آية جديدة، وإلا حُوسبت الآية التالية على ما نُطق في السابقة.
    func reset() {
        stop()
        transcript = ""; error = nil
    }

    func stop() {
        guard listening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        request?.endAudio()
        task?.cancel(); task = nil; request = nil
        listening = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
