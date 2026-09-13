import SwiftUI
import UIKit

// MARK: - وضع النوم — العدُّ إلى السكون
//
// هذا التطبيق يُترك يعمل ساعاتٍ في غرفة. وشاشةُ تلفازٍ مضيئةٌ طولَ الليل خطأٌ
// من ثلاثة أوجهٍ معًا: تُضيء غرفةً أُطفئت، وتحفر إطارَها الثابت في لوحة OLED،
// وتقول لصاحبها إنّ التطبيق لا يدري أنّ أحدًا لم يعد ينظر.
//
// فهنا عدّادُ سكونٍ واحد: يبدأ من آخر لمسةٍ على المِرقاب، ويمرّ بحالتين —
// خافتٌ ثم نائم — ويعود إلى اليقظة من أوّل إشارة. وهو لا يعرف المشغّلَ ولا
// يملك إليه سبيلًا: لا استيراد لـ`RadioPlayer` هنا ولا نداءَ له، فالصوتُ يمضي
// كما هو مهما أظلمت الشاشة. سكونُ العين لا سكونُ الأذن.
@MainActor
final class TVIdle: ObservableObject {

    /// ثلاثُ حالاتٍ لا رابعَ لها، ولا رجوعَ بينها إلا إلى اليقظة دفعةً واحدة.
    enum State { case awake, dim, asleep }

    /// واحدٌ للتطبيق: الشاشةُ واحدة، والسكونُ حالةُ الجهاز كلّه لا حالةُ عرضٍ فيه.
    static let shared = TVIdle()

    @Published private(set) var state: State = .awake

    /// نبضةُ المؤقّت — وهي ساعةُ الوجه الخافت كذلك. ولا تُنشر والشاشةُ مضيئة:
    /// المجلسُ يعدّ ثوانيه بنفسه، فنشرُها حينئذٍ إيقاظُ رسمٍ بلا سبب.
    @Published private(set) var beat = Date()

    // MARK: العتبات

    /// دقيقتان — وهي مدّةُ حافظةِ الشاشة الافتراضية في tvOS نفسه: أقصرُ سكونٍ
    /// حكم به النظامُ أنّ أحدًا لم يعد يُمسك المِرقاب. ولا تظلم من يقرأ العدّ
    /// التنازلي، لأنّ الخافتَ يُبقي الوقتَ والصلاةَ القادمة ولا يطوي غيرهما.
    static let dimAfter: TimeInterval = 120

    /// عشرُ دقائق — أي ثماني دقائقَ بعد الخفوت. من رآها خافتةً هذه المدّة ولم
    /// يُحرّك ساكنًا فقد نام أو خرج. وليست الفائدةُ في الظلمة وحدها: إطارٌ واحد
    /// ثابت — ولو خافتًا — يبقى ساعاتٍ في موضعه يحفر نفسه في لوحة OLED، فالنومُ
    /// التامّ هو ما يمنع الحفر لا الخفوت. ولذلك كانت حالةً ثالثةً لا درجةَ خفوتٍ أشدّ.
    static let sleepAfter: TimeInterval = 600

    /// خمسُ ثوانٍ: العدُّ إلى دقيقتين لا يحتاج دقّةً أعلى، وهي نبضةُ الساعة
    /// الخافتة كذلك — مؤقّتٌ واحد للوضع كلّه لا اثنان، وبثوانٍ لا بإطارات.
    private static let beatEvery: TimeInterval = 5

    // MARK: الحال

    private var last = Date()
    private var timer: Timer?
    private var foreground = true
    private var begun = false
    private var watch: TVRemoteWatch?

    private init() {}

    // MARK: البدء والإيقاظ

    /// يُستدعى مرّةً من الشاشة. يُركّب مراقبَ المِرقاب ويصل بالمؤقّت بالمشهد.
    func begin() {
        guard !begun else { return }
        begun = true
        watchScene()
        attachWatch()
        poke()
    }

    /// أيُّ إشارةٍ من المِرقاب. تُعيد اليقظة فورًا وتُصفّر العدّ — ولا تمسّ صوتًا
    /// ولا تُبدّل مصدرًا ولا تعرف أنّ ثمّة مشغّلًا أصلًا.
    func poke() {
        last = Date()
        // ولا يُكتب على الحالة وهي هي: `@Published` تُعلن التغيّر ولو لم يتغيّر
        // شيء، وهذه تُنادى مع كلِّ لمسةٍ على المِرقاب — فتصير الشاشةُ تُعاد
        // حسبتُها مع كلِّ إصبعٍ يمرّ بلا أن يتبدّل فيها بكسل.
        if state != .awake { state = .awake }
        start()
    }

    // MARK: المؤقّت — واحدٌ، خشِن، ويقف متى لم يعد له معنى

    private func start() {
        guard foreground, timer == nil else { return }
        let t = Timer(timeInterval: Self.beatEvery, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        // خمسُ ثوانٍ تحتمل ثانيةَ تأخير، والنظامُ يجمع المؤقّتات المتسامحة فيوقظ
        // المعالجَ مرّةً بدل مرّتين.
        t.tolerance = 1
        // `.common` لا `.default`: تحريكُ التركيز بالمِرقاب يُدخل حلقةَ التشغيل
        // في نمط التتبّع، والمؤقّتُ العاديّ يصمت فيه.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = Date()
        let still = now.timeIntervalSince(last)
        let next: State = still >= sleepThreshold ? .asleep
                        : still >= dimThreshold   ? .dim
                        : .awake
        if next != state { state = next }
        if next != .awake { beat = now }
        // النومُ حالةٌ نهائية: لا شيء بعده يتغيّر حتى تأتيَ إشارة، فلا يبقى
        // مؤقّتٌ يستيقظ كلَّ خمس ثوانٍ ليلةً كاملةً ليجد نفسه نائمًا.
        if next == .asleep { stop() }
    }

    // MARK: المشهد — لا عدَّ والتطبيقُ في الخلف

    /// التطبيقُ في الخلف لا شاشةَ له تُخفت، فالمؤقّتُ يقف. وعند العودة يُوقَظ من
    /// جديد: من رجع إلى التطبيق لم يرجع إليه ليجده مظلمًا.
    private func watchScene() {
        let c = NotificationCenter.default
        c.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.foreground = false
                self?.stop()
            }
        }
        c.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.foreground = true
                self?.poke()
            }
        }
    }

    // ولا `deinit` يرفع هذين المراقبين: هذا الكائن واحدُ التطبيق، يعيش ما عاش
    // ويموت بموته — ورفعُ مراقبٍ في اللحظة التي يُنهى فيها المشهد عبثٌ.

    // MARK: مراقبُ المِرقاب

    /// النافذةُ تُطلب بعد أن يُركّبها المشهد، وقد لا تكون قد وُجدت بعدُ عند أوّل
    /// ظهور. فيُعاد الطلبُ مرّاتٍ معدودة ثم يُترك: بديلُه غطاءُ الخفوت نفسه —
    /// زرٌّ يستقبل التركيز — فلا يبقى الوضعُ بلا مَخرجٍ على كل حال.
    private func attachWatch(retries: Int = 4) {
        guard watch == nil else { return }
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else {
            guard retries > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.attachWatch(retries: retries - 1)
            }
            return
        }
        let g = TVRemoteWatch()
        g.onInput = { [weak self] in self?.poke() }
        window.addGestureRecognizer(g)
        watch = g
    }

    // MARK: عتبتان مُعجَّلتان للتصوير

    #if DEBUG
    /// «-atharTVDim 4 -atharTVSleep 12» في وسائط التشغيل تُقرّبان الحالتين حتى
    /// تُرَيا وتُصوَّرا في ثوانٍ بدل دقائق. و`#if DEBUG` يمحوهما من الإصدار
    /// محوًا، فلا مفتاحَ في يد أحدٍ يُخفت شاشةً بعد أربع ثوانٍ.
    private static func forced(_ key: String) -> TimeInterval? {
        let v = UserDefaults.standard.double(forKey: key)
        return v > 0 ? v : nil
    }
    #endif

    private var dimThreshold: TimeInterval {
        #if DEBUG
        if let v = Self.forced("atharTVDim") { return v }
        #endif
        return Self.dimAfter
    }

    private var sleepThreshold: TimeInterval {
        #if DEBUG
        if let v = Self.forced("atharTVSleep") { return v }
        #endif
        return Self.sleepAfter
    }
}

// MARK: - مُميِّزُ إيماءةٍ لا يُميّز شيئًا

/// يُضاف إلى نافذة التطبيق فيرى كلَّ لمسةٍ على سطح المِرقاب وكلَّ ضغطةِ زرّ —
/// أينما كان التركيز وأيًّا كان الزرُّ المقصود — ولا يعترض منها شيئًا: لا يخرج
/// من `.possible` إلى `.began` أبدًا، ويُعلن `.failed` عند انتهاء كل إشارة
/// ليُعيده النظامُ إلى موضعه للإشارة التي بعدها.
///
/// والبديلُ كان نداءَ `poke()` من كل زرٍّ في الشاشة يدًا بيد؛ وزرٌّ واحد يُنسى
/// يعني شاشةً تخفت في وجه من يُقلّب فيها.
private final class TVRemoteWatch: UIGestureRecognizer {
    var onInput: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        // مراقبٌ لا حاجب: لا يُلغي لمسةً تحته ولا يؤخّرها، وإلا صار كلُّ ضغطةِ
        // زرٍّ في التطبيق تمرّ من طابورٍ لا لزوم له.
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        allowedPressTypes = [UIPress.PressType.upArrow, .downArrow, .leftArrow, .rightArrow,
                             .select, .menu, .playPause].map { NSNumber(value: $0.rawValue) }
        allowedTouchTypes = [UITouch.TouchType.direct, .indirect].map { NSNumber(value: $0.rawValue) }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        onInput?()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .failed
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent) {
        super.pressesBegan(presses, with: event)
        onInput?()
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent) {
        super.pressesEnded(presses, with: event)
        state = .failed
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent) {
        super.pressesCancelled(presses, with: event)
        state = .failed
    }
}
