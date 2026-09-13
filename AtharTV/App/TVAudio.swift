import Foundation
import Combine

// MARK: - ما يُسمَع في المجلس
//
// محرّكان في الملفّات المشتركة يعرفان القرآن، والتلفاز يأخذ أحدهما ويدع الآخر:
//
// `AyahAudio` يُسمِع آيةً آية من everyayah، وإنّما بُني ليُظلَّل به موضعُ القراءة
// في المصحف وتُكرَّر الآيةُ للحفظ — اتصالٌ جديد لكلّ آية، ومئتان وستٌّ وثمانون
// اتصالًا في البقرة وحدها. وشاشةٌ تُترك تعمل ساعاتٍ لا تحتمل ذلك، ولا مصحفَ
// هنا يُظلَّل أصلًا.
//
// و`Recitation` يُسمِع السورة كاملةً ملفًّا واحدًا من mp3quran يمتدّ نصفَ ساعةٍ
// ونيّفًا، و`repeatMode == .next` يُتبعه بما بعده حتى يُوقفه صاحبه. فهو محرّك
// التلفاز، وقارئوه خمسةَ عشر في `RecitationLibrary`.
//
// ولا تنزيل هنا البتّة: `Recitation` تعرف التنزيل والحذف، ولا يُنادى منها شيءٌ
// من ذلك في هذا الهدف. تخزينُ tvOS الدائم خمسُمئة كيلوبايت، والسورةُ الواحدة
// تزيد عليه عشراتِ الأضعاف — فالبثّ هو الطريق الوحيد الصادق. و`play(surah:)`
// تلتمس ملفًّا محلّيًّا قبل الشبكة فلا تجده على التلفاز أبدًا، فتبثّ.
//
// وحين تنقطع الشبكة لا يُخفى ذلك ولا يُسكَت عليه: `problem` تقول ما وقع بلفظه،
// وشاشةُ الاختيار نفسها تعمل بلا اتصال — أسماءُ السور من الحزمة وأسماءُ القرّاء
// من الشيفرة، فلا تفرغ قائمةٌ ولا تدور دائرة.
//
// والصوتُ لا يبدأ بلا شاشةٍ تُريه: `play(surah:)` و`playRadio()` تفتحان المشغّل
// (`TVPlayerView`) من هنا لا من الشاشة التي ضُغط فيها الزرّ — فالبدءُ يقع في
// ثلاثة مواضع (مربّعُ الإذاعة، وشاشةُ القرّاء، وزرُّ التشغيل في المِرقاب)، ولو
// عُلّق فتحُ المشغّل بأحدها لبقيت المواضعُ الأخرى تُسمِع بلا أن تُري.
@MainActor
final class TVAudio: ObservableObject {
    static let shared = TVAudio()

    /// ما يُسمَع الآن. الواجهة تسأل هذه وحدها ولا تعرف أنّ خلفها مشغّلَين.
    enum Now: Equatable {
        case silent
        case radio
        case surah(Int)
    }

    private let radio = RadioPlayer.shared
    private let quran = Recitation.shared
    private var bag: Set<AnyCancellable> = []

    /// القارئ وموضعُ السماع يُحفظان هنا لا حيث تحفظهما `Recitation`: هي تكتبهما
    /// في دفاتر المجموعة المشتركة بين التطبيق وودجاته وساعته، ولا مجموعةَ
    /// لتلفاز — فكان الاختيار يسقط صامتًا مع كلّ إقلاع.
    private static let reciterKey = "athar.tv.reciter"
    private static let lastSurahKey = "athar.tv.lastSurah"

    /// هل المشغّلُ على الشاشة؟ يكتبها `TVPlayerView` عند ظهوره وذهابه، وبها
    /// لا يُفتح فوق نفسه: «التالية» و«الاستمرار» من داخله تبدآن صوتًا كما يبدؤه
    /// المجلس، والفرقُ الوحيد أنّ الشاشةَ حاضرة.
    @Published var playerShown = false

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.reciterKey),
           let r = RecitationLibrary.reciter(id: saved) {
            quran.select(r)   // بلا سورةٍ جارية: يُثبِّت الاسم ولا يُشغّل شيئًا
        }

        // لا نسخةَ ثانيةً من الحال هنا: المشغّلان يملكانها، وهذا يُمرّر خبرَ
        // تغيّرها إلى الواجهة فتُقرأ المحسوباتُ أدناه بعد أن تستقرّ القيم.
        radio.objectWillChange
            .merge(with: quran.objectWillChange)
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &bag)

        // موضعُ السماع يُكتب كلّما تحوّل لا حين يُطلب وحده: `repeatMode == .next`
        // يُتبع السورةَ بما بعدها من داخل `Recitation` فلا يمرّ بنا، فمن ترك
        // المصحف يمضي من البقرة إلى الفجر كان يُعرض عليه في الغد «الاستمرار» من
        // البقرة نفسها — كأنّ ليلةً كاملة لم تكن. والصمتُ لا يمحوه: `stop()`
        // تُفرغ السورةَ الجارية، وآخرُ ما سُمع يبقى لأنّه هو المقصود.
        quran.$surah
            .compactMap { $0 }
            .filter { (1...114).contains($0) }
            .sink { UserDefaults.standard.set($0, forKey: Self.lastSurahKey) }
            .store(in: &bag)

        // المصحف يُفكّ من الحزمة مرّةً واحدة عند أوّل سؤالٍ عن اسم سورة (١٫٣٦
        // ميغابايت)، ولو وقع ذلك في أوّل رسمٍ لقائمة السور لتجمّدت حين تُفتح.
        Task.detached(priority: .utility) { _ = Quran.surahs.count }
    }

    // MARK: الحال

    var now: Now {
        if radio.source != nil { return .radio }
        if let s = quran.surah { return .surah(s) }
        return .silent
    }

    var isPlaying: Bool { radio.isPlaying || quran.isPlaying }
    var isBuffering: Bool { radio.isBuffering || quran.isBuffering }

    /// القارئ المختار — من المشغّل نفسه لا من نسخةٍ عندنا تُخالفه.
    var reciter: Reciter { quran.reciter }

    /// اسمُ ما يُسمَع، وتحته مَن يُسمِعه. سطران يكفيان شاشةً لتقول حالها.
    var title: String {
        switch now {
        case .silent: return ""
        case .radio:  return LiveSource.radio.title
        case .surah(let id): return Quran.surah(id).map { loc("سورة %1$@", $0.name) } ?? ""
        }
    }

    var voice: String {
        switch now {
        case .silent: return ""
        case .radio:  return loc("بثّ حيّ")
        case .surah:  return reciter.name
        }
    }

    /// ما يُقال حين يسكت الصوت: البثّ من الشبكة، وانقطاعُها أوّلُ ما يقع فيه من
    /// يترك هذا يعمل في بيتٍ اتصالُه يتقطّع. وصمتٌ بلا سببٍ معلوم أسوأُ من عطل.
    var problem: String? {
        if radio.source != nil { return radio.error }
        if quran.surah != nil, quran.failed {
            return loc("تعذّر جلب التلاوة — الصوت يُبثّ من الشبكة، فتحقّق من الاتصال.")
        }
        return nil
    }

    /// السورةُ التي يُستأنف منها: الجاريةُ إن كانت، وإلّا آخرُ ما سُمع. تعود nil
    /// لمن لم يسمع شيئًا بعد — فلا يُعرض عليه «الاستمرار» ولا شيءَ يستأنفه.
    var resumable: Int? {
        if let s = quran.surah { return s }
        let last = UserDefaults.standard.integer(forKey: Self.lastSurahKey)
        return (1...114).contains(last) ? last : nil
    }

    // MARK: التحكّم

    /// السورة بصوت القارئ المختار. صوتٌ واحد في المجلس: الإذاعةُ تُنهى صراحةً
    /// قبلها — و`RadioPlayer` يُنهي نفسه إذا سمع التلاوةَ تبدأ، لكنّ شرطَ
    /// «صوتٍ واحد» أجلُّ من أن يُترك لأثرٍ جانبيّ في ملفٍّ آخر.
    func play(surah id: Int) {
        guard Quran.surah(id) != nil else { return }
        // ما يُسمَع فعلًا لا يُعاد من أوّله: من ضغط «الاستمرار» والسورةُ نفسُها
        // جارية أراد أن يراها لا أن يقطعها. والمتوقّفةُ تُستأنف من موضعها.
        if now == .surah(id), !quran.failed {
            if !quran.isPlaying { quran.resume() }
            TVPlayerPresenter.present()
            return
        }
        radio.stop()
        // المصحف يتتابع من تلقائه: شاشةٌ تُترك تعمل لا يليق بها أن تصمت بعد
        // نصف ساعةٍ وينتظر أهلُ البيت من يقوم إلى المِرقاب.
        quran.repeatMode = .next
        quran.play(surah: id)
        TVPlayerPresenter.present()
    }

    /// الإذاعة. `RadioPlayer.play` يُنهي التلاوة عنده، ونُصرّح بها للسبب نفسه.
    func playRadio() {
        // البثّ الجاري لا يُعاد وصلُه: مربّعُ الإذاعة في المجلس هو طريقُ العودة
        // إلى المشغّل ما دامت تُسمَع، لا زرَّ إعادةِ اتصالٍ يُسكتها لحظة.
        if now == .radio, radio.error == nil {
            if !radio.isPlaying { radio.resume() }
            TVPlayerPresenter.present()
            return
        }
        quran.stop()
        radio.play(.radio)
        TVPlayerPresenter.present()
    }

    /// زرُّ التشغيل في المِرقاب وفي الشاشة: يُوقف الجاريَ ويُعيده، وإن لم يكن
    /// شيءٌ جاريًا بدأ الإذاعة — فهي ما يُفتح بلا اختيار.
    func toggle() {
        switch now {
        case .radio:  radio.toggle()
        case .surah:  quran.isPlaying ? quran.pause() : quran.resume()
        case .silent: playRadio()
        }
    }

    func stop() {
        radio.stop()
        quran.stop()
    }

    /// تبديلُ القارئ. `Recitation.select` تُعيد تحميل السورة الجارية بصوته
    /// وتُبقيها متوقّفةً إن كانت كذلك، فلا يلزمنا شيءٌ سوى حفظ الاسم.
    func choose(_ r: Reciter) {
        quran.select(r)
        UserDefaults.standard.set(r.id, forKey: Self.reciterKey)
    }

    // MARK: الموضع — للسورة وحدها

    /// السورةُ ملفٌّ له أوّلٌ وآخر فيُقدَّم ويُرجَع فيه، والإذاعةُ بثٌّ حيٌّ لا
    /// موضعَ فيه ولا مدّة — فكلُّ ما تحت هذا العنوان يعود صفرًا أو `false` لها،
    /// والمشغّلُ لا يعرض لها شريطًا ولا يعدُها بما لا يقدر عليه.
    var canSeek: Bool {
        if case .surah = now { return true }
        return false
    }

    var elapsed: Double { canSeek ? quran.elapsed : 0 }
    var duration: Double { canSeek ? quran.duration : 0 }
    var progress: Double { canSeek ? quran.progress : 0 }

    /// عشرُ ثوانٍ: قدرُ آيةٍ عند أكثر القرّاء، فالرجوعُ ضغطةً يُعيد الآيةَ التي
    /// فاتت لا التي قبلها. وهي خطوةُ تطبيق الجوال نفسُها، فيدٌ تعرفه تعرف هذا.
    static let skip: Double = 10

    func seek(by seconds: Double) {
        guard canSeek else { return }
        quran.seek(by: seconds)
    }

    /// المسحُ على شريط الموضع: خطوةٌ من عشرين في طول السورة، لا عشرُ ثوانٍ —
    /// فالشريطُ لمن يريد منتصفَ البقرة (نصفُ ساعةٍ من أوّلها) والزرّان لمن
    /// يريد الآيةَ التي فاتت. وفي السور القصار لا تنزل الخطوةُ عن عشر ثوانٍ
    /// لئلّا تصير المسحةُ ثانيةً لا تُحَسّ.
    func scrub(forward: Bool) {
        guard canSeek else { return }
        let step = max(Self.skip, duration / 20)
        quran.seek(by: forward ? step : -step)
    }

    var canGoNext: Bool {
        if case .surah(let s) = now { return s < 114 }
        return false
    }

    /// كزرّ الأغاني: في أوّل السورة يرجع إلى ما قبلها، وبعد ثلاث ثوانٍ يرجع إلى
    /// أوّلها — فالفاتحةُ بعد ثلاث ثوانٍ لها «سابق» وهو أوّلُها.
    var canGoPrevious: Bool {
        if case .surah(let s) = now { return s > 1 || quran.elapsed > 3 }
        return false
    }

    func next() {
        guard canGoNext else { return }
        quran.next()
    }

    func previous() {
        guard canGoPrevious else { return }
        quran.previous()
    }

    // MARK: السرعة — للسورة وحدها

    /// الأربعُ التي تُدار بضغطةٍ واحدة تتلوها أخرى: العاديّةُ فالأسرعُ (وهو أكثرُ
    /// ما يُطلب) فالأسرعُ منه، ثم الأبطأُ لمن يتابع الحفظَ، ثم العودة. ولا أربعُ
    /// رقائقَ متجاورة: خيارٌ واحد يُقرأ لفظُه أوضحُ على مِرقابٍ من صفٍّ يُتنقّل فيه.
    static let rates: [Float] = [1.0, 1.25, 1.5, 0.75]

    var rate: Float { quran.rate }

    /// البثُّ الحيّ لا يُسرَّع: `AVPlayer` يقبل المعدّلَ عليه ثم يفرغ ما جمع
    /// ويتلعثم، فلا يُعرض له.
    var canChangeRate: Bool { canSeek }

    func cycleRate() {
        guard canChangeRate else { return }
        let i = Self.rates.firstIndex { abs($0 - quran.rate) < 0.001 } ?? 0
        quran.rate = Self.rates[(i + 1) % Self.rates.count]
    }

    // MARK: مؤقّت النوم — لكلا المصدرين

    /// خياراتُ البثّ الأربعة (`SleepTimer.liveChoices`) للمصدرين معًا، وتزيد
    /// السورةُ «عند نهاية السورة» وحده — فهو ما لا معنى له لبثٍّ لا ينتهي.
    /// ولا الثمانيةُ التي في الجوال: ثمانُ ضغطاتٍ لدورةٍ كاملة كثيرٌ على مِرقاب.
    var sleepChoices: [SleepTimer] {
        canSeek ? SleepTimer.liveChoices + [.endOfSurah] : SleepTimer.liveChoices
    }

    var sleep: SleepTimer {
        switch now {
        case .radio:  return radio.sleep
        case .surah:  return quran.sleep
        case .silent: return .off
        }
    }

    var sleepEndsAt: Date? {
        switch now {
        case .radio:  return radio.sleepEndsAt
        case .surah:  return quran.sleepEndsAt
        case .silent: return nil
        }
    }

    func setSleep(_ t: SleepTimer) {
        switch now {
        case .radio:  radio.setSleep(t)
        case .surah:  quran.setSleep(t)
        case .silent: break
        }
    }

    func cycleSleep() {
        let choices = sleepChoices
        guard !choices.isEmpty else { return }
        let i = choices.firstIndex(of: sleep) ?? 0
        setSleep(choices[(i + 1) % choices.count])
    }
}
