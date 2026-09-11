import XCTest
import AVFoundation
import MediaPlayer
@testable import Athar

/// أربعة محرّكات في التطبيق تُصدر صوتًا — تلاوةُ السورة، وتلاوةُ الآية، والإذاعة،
/// وسماعُ الأذان — وجلسةُ الصوت وبطاقةُ شاشة القفل بينها مشتركة. هذه الاختبارات
/// تحرس تسليم أحدها لصاحبه: ألّا يعود المقطوع إلا إن كان هو المقطوع، وألّا يمسح
/// الخاملُ بطاقةَ العامل.
final class AudioEnginesHandoffTests: XCTestCase {

    // MARK: أدوات

    private var session: AVAudioSession { AVAudioSession.sharedInstance() }

    private func postInterruption(_ type: AVAudioSession.InterruptionType, shouldResume: Bool = false) {
        var info: [AnyHashable: Any] = [AVAudioSessionInterruptionTypeKey: type.rawValue]
        if shouldResume {
            info[AVAudioSessionInterruptionOptionKey] = AVAudioSession.InterruptionOptions.shouldResume.rawValue
        }
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
                                        object: session, userInfo: info)
    }

    /// ملفّ صوت صامت صالح للتشغيل: نختبر منطق المشغّل لا صوته، فلا شبكةَ في
    /// الاختبار ولا أذانَ يُرفع في وجه من يُشغّله.
    private func silentAudio(seconds: Int) -> Data {
        let rate = 8000, channels = 1, bits = 16
        let bytes = seconds * rate * channels * bits / 8
        var d = Data()
        func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8));     u32(36 + bytes)
        d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16)
        u16(1); u16(channels); u32(rate)
        u32(rate * channels * bits / 8); u16(channels * bits / 8); u16(bits)
        d.append(contentsOf: Array("data".utf8));     u32(bytes)
        d.append(Data(count: bytes))
        return d
    }

    private func settle() async {
        try? await Task.sleep(nanoseconds: 250_000_000)
    }

    // MARK: بطاقة شاشة القفل مشتركة

    /// تلاوةُ الآية تُستدعى `stop()` عليها دفاعًا من كل محرّكٍ قبل أن يبدأ صوته،
    /// وممّن يُغلق القارئ أو التفسير. وكانت تمسح بطاقةَ شاشة القفل في الحالين،
    /// فمن أوقف السورة ليسمع ذكرًا أو تفسيرًا وجد بطاقتها اختفت من الشاشة ولا
    /// يعيدها من أوقفها. فما لم تكن هي المشغّلة فلا تمسّ شيئًا.
    @MainActor
    func testIdleAyahAudioStopLeavesTheSharedNowPlayingCardAlone() {
        XCTAssertFalse(AyahAudio.shared.isActive, "الاختبار يفترض مشغّل آيةٍ خاملًا")

        let center = MPNowPlayingInfoCenter.default()
        let saved = center.nowPlayingInfo
        defer { center.nowPlayingInfo = saved }

        center.nowPlayingInfo = [MPMediaItemPropertyTitle: "سورة الفاتحة",
                                 MPNowPlayingInfoPropertyPlaybackRate: 0.0]
        AyahAudio.shared.stop()

        XCTAssertEqual(center.nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "سورة الفاتحة",
                       "الخامل لا يمسح بطاقةَ غيره")
    }

    // MARK: من قُطع هو من يعود

    /// نهايةُ المكالمة كانت تستأنف السورة أيًّا كان الذي أوقفها: تلاوةُ الآية توقف
    /// السورة مؤقّتًا لا تُنهيها، فيعود صوتها فوق الآية؛ ومؤقّت النوم يوقفها ثم تعود
    /// بعد مكالمةٍ عابرة. فصار الاستئناف مشروطًا بأن تكون هي التي قُطعت وهي تعمل.
    @MainActor
    func testInterruptionResumesOnlyWhatItActuallyInterrupted() async throws {
        let rec = Recitation.shared
        let surah = 1
        let file = RecitationLibrary.localURL(reciter: rec.reciter.id, surah: surah)
        let fm = FileManager.default

        // تنزيلات المستخدم أمانة: نُنحّي ملفَّه إن وُجد ونردّه كما كان.
        let backup = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp3")
        let hadFile = fm.fileExists(atPath: file.path)
        if hadFile { try? fm.moveItem(at: file, to: backup) }
        try? fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try silentAudio(seconds: 20).write(to: file)

        let defaults = UserDefaults(suiteName: AtharStore.appGroup)
        let savedLast = defaults?.object(forKey: "athar.recitation.lastSurah")
        let savedMode = rec.repeatMode
        defer {
            rec.stop()
            rec.repeatMode = savedMode
            try? fm.removeItem(at: file)
            if hadFile { try? fm.moveItem(at: backup, to: file) }
            if let savedLast { defaults?.set(savedLast, forKey: "athar.recitation.lastSurah") }
            else { defaults?.removeObject(forKey: "athar.recitation.lastSurah") }
        }

        rec.repeatMode = .once      // لا ينتقل إلى سورةٍ تالية تُجلب من الشبكة
        rec.play(surah: surah)
        await settle()
        try XCTSkipIf(rec.failed, "تعذّر تشغيل ملفٍّ محلّي في هذه البيئة")
        XCTAssertTrue(rec.isPlaying)

        // ١) قُطعت وهي تعمل: تعود إن أذن النظام.
        postInterruption(.began)
        await settle()
        XCTAssertFalse(rec.isPlaying, "القطع يوقفها")
        postInterruption(.ended, shouldResume: true)
        await settle()
        XCTAssertTrue(rec.isPlaying, "ما قُطع وهو يعمل يعود")

        // ٢) أوقفها صاحبها (أو تلاوةُ الآية) قبل المكالمة: لا تعود بنهايتها.
        rec.pause()
        postInterruption(.began)
        postInterruption(.ended, shouldResume: true)
        await settle()
        XCTAssertFalse(rec.isPlaying, "ما أوقفه غيرُ المكالمة لا تعيده نهايتُها")

        // ٣) انطفأ مؤقّت النوم في أثناء المكالمة: النومُ أولى من إذن الاستئناف.
        rec.resume()
        await settle()
        XCTAssertTrue(rec.isPlaying)
        postInterruption(.began)
        await settle()
        rec.setSleep(.minutes(0))   // مؤقّتٌ ينطفئ فورًا — نبلغ به لحظةَ النوم بلا انتظار
        await settle()
        postInterruption(.ended, shouldResume: true)
        await settle()
        XCTAssertFalse(rec.isPlaying, "ما أنهاه النوم لا يعود بعد المكالمة")
    }

    // MARK: من بدأ صوتًا أعلن

    /// مشغّل «البث المباشر» فيديو من أصلٍ آخر لا يعرفه محرّكٌ منّا، ولا يسكت إلا
    /// بإشعار `atharAudioStarted`. وسماعُ الأذان لم يكن يُرسله، فيبقى بثّ الحرمين
    /// الشريفين يُسمع تحته.
    @MainActor
    func testAthanPreviewAnnouncesItselfSoTheLiveStreamGoesQuiet() throws {
        let sound = AthanSound.nabawi
        let name = try XCTUnwrap(sound.fileName)
        try XCTSkipIf(Bundle.main.url(forResource: name + "-full", withExtension: "m4a") == nil,
                      "تسجيل الأذان الكامل ليس في الحزمة")

        let heard = expectation(forNotification: .atharAudioStarted, object: nil, handler: nil)
        AthanPreview.shared.play(sound)
        AthanPreview.shared.stop()      // الخبر يُرسل عند البدء، فلا حاجة لسماع الأذان كلّه
        wait(for: [heard], timeout: 1)
    }
}
