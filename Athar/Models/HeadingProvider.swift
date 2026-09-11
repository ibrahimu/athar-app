import Foundation
import CoreLocation
import UIKit

/// اتجاه الجهاز من البوصلة. لا يغادر الجهاز شيء.
@MainActor
final class HeadingProvider: NSObject, ObservableObject {
    /// الاتجاه بالدرجات من الشمال، أو nil قبل وصول أول قراءة.
    @Published var heading: Double?
    /// دقة القراءة بالدرجات؛ سالبة تعني أن البوصلة تحتاج معايرة.
    @Published var accuracy: Double = -1
    /// هل القراءة منسوبة للشمال الحقيقي؟ (تتطلب خدمات الموقع) وإلا فهي مغناطيسية.
    @Published var usesTrueNorth = false

    let isAvailable = CLLocationManager.headingAvailable()

    private let manager = CLLocationManager()

    /// هل طُلب التشغيل (start) ولم يُطلب الإيقاف (stop) بعد؟ الشاشة تطلب وتوقف، أمّا
    /// مغادرة الواجهة فلا تُطلق onDisappear (قفل الشاشة، أو تطبيق آخر فوقنا)، فكانت
    /// البوصلة — ومعها سهم الموقع في شريط الحالة — تبقى تعمل ما دام التطبيق حيًّا،
    /// والصوت في الخلفية يبقيه حيًّا ساعات. لذا يوقف المزوّد الحسّاس بنفسه عند المغادرة
    /// ويعيده عند العودة إن بقي الطلب قائمًا — فلا يتعلّق الأمان بالشاشة وحدها.
    private var wantsUpdates = false
    private var lifecycle: [NSObjectProtocol] = []

    /// إشعار دورة الجهاز لا يُنشر إلا لمن طلب توليده. النظام يطلبه لنفسه في الغالب،
    /// و«الغالب» يكفي في زينةٍ ولا يكفي في جهةٍ يُصلَّى إليها — فنطلبه صراحةً ما دامت
    /// البوصلة تعمل، ونتركه بتركها، فلا يبقى مقياسٌ يعمل لشاشةٍ غادرها صاحبها.
    private var wantsOrientationNotices = false

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1          // درجة واحدة
        syncHeadingOrientation()

        // إشعارات التطبيق تُنشر على الخيط الرئيس، والطابور الرئيس يضمن بقاءنا عليه.
        // نراقب دخول الخلفية لا willResignActive: قفل الشاشة والخروج كلاهما يبلغان الخلفية،
        // أمّا الخمول العابر (مركز التحكّم، تنبيه إذن الموقع، وشاشة معايرة البوصلة التي
        // يعرضها النظام بطلبنا أدناه) فإيقاف الحسّاس فيه يغلق المعايرة ثم يعيد فتحها — رفرفة.
        let center = NotificationCenter.default
        lifecycle = [
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.suspend() }
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.resume() }
            },
            // ودورةُ الجهاز: إشعارها قد يسبق استقرار الواجهة على اتجاهها الجديد، فلا
            // يُتّكل عليه وحده — يُراجَع المرجع مع كل قراءة أيضًا (أسفل الملف).
            center.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.syncHeadingOrientation() }
            },
        ]
    }

    deinit {
        for token in lifecycle { NotificationCenter.default.removeObserver(token) }
        manager.stopUpdatingHeading()
        // عدّاد التوليد في UIDevice مشترك بين التطبيق كلّه: ما زدناه فيه يُنقص ولو مات
        // المزوّد قبل stop، وإلا بقي الحسّاس يعمل لا لأحد.
        if wantsOrientationNotices {
            Task { @MainActor in UIDevice.current.endGeneratingDeviceOrientationNotifications() }
        }
    }

    func start() {
        guard isAvailable else { return }
        wantsUpdates = true
        // قد تُفتح الشاشة والجهاز عَرْضًا أصلًا، فلا دورةَ تأتي بعدها ليُصحَّح بها المرجع.
        syncHeadingOrientation()
        beginOrientationNotices()
        manager.startUpdatingHeading()
    }

    func stop() {
        wantsUpdates = false
        guard isAvailable else { return }
        manager.stopUpdatingHeading()
        endOrientationNotices()
    }

    /// يوقف الحسّاس دون إسقاط الطلب، فتعود القراءة مع عودة التطبيق إلى الواجهة.
    private func suspend() {
        guard isAvailable else { return }
        manager.stopUpdatingHeading()
        endOrientationNotices()
    }

    /// يعيد الحسّاس فقط إن كان الطلب ما زال قائمًا (start بلا stop بعده).
    private func resume() {
        guard isAvailable, wantsUpdates else { return }
        // ربّما دارت الواجهة ونحن خلفها، أو فُكّ قفل الدوران من مركز التحكّم والجهازُ
        // ساكن — فلا إشعار دورةٍ يأتي أصلًا. فيُراجع المرجع قبل أوّل قراءة.
        syncHeadingOrientation()
        beginOrientationNotices()
        manager.startUpdatingHeading()
    }

    private func beginOrientationNotices() {
        guard !wantsOrientationNotices else { return }
        wantsOrientationNotices = true
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    }

    private func endOrientationNotices() {
        guard wantsOrientationNotices else { return }
        wantsOrientationNotices = false
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    var needsCalibration: Bool { accuracy < 0 || accuracy > 25 }

    // MARK: - مرجع البوصلة

    /// مرجعُ القراءة في CoreLocation حافةٌ بعينها من الجهاز، وكان مثبّتًا على الطول
    /// (portrait). فمن أدار جهازه — والتطبيق يعمل على الآيباد كما يعمل على الآيفون،
    /// والعرضُ عندهما بابٌ مفتوح، ويزداد انفتاحًا بالآيفون المطويّ — انحرف سهم القبلة
    /// تسعين درجة وهو واثق لا يشكو. وهذا خطأ في جهةٍ يُصلَّى إليها لا في زينة، فيتبع
    /// المرجعُ اتجاهَ الواجهة ويُجدَّد كلّما دارت.
    private func syncHeadingOrientation() {
        guard let interface = Self.foregroundInterfaceOrientation() else { return }
        let orientation = Self.headingOrientation(for: interface)
        guard manager.headingOrientation != orientation else { return }
        manager.headingOrientation = orientation
    }

    /// اتجاه أوّل مشهدٍ نشِطٍ في الواجهة. لا مشهدَ نشِطًا يعني أنّنا خلفها — فيبقى آخر
    /// مرجعٍ معروف على حاله، ولا يُردّ إلى الطول ظنًّا.
    private static func foregroundInterfaceOrientation() -> UIInterfaceOrientation? {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes
        where scene.activationState == .foregroundActive {
            return scene.interfaceOrientation
        }
        return nil
    }

    /// UIKit تعدّ الدوران من جهة المحتوى، وCoreLocation تعدّه من جهة الجهاز: إدارةُ
    /// الجهاز يسارًا تُدير المحتوى يمينًا، فـ«يسار» الواجهة هي «يمين» الجهاز — نصٌّ في
    /// رأس UIKit نفسه لا استنتاج منّا. وما لا اتجاه له (مشهدٌ لم يُركَّب بعد، أو قيمةٌ
    /// يستحدثها النظام) يُعامل معاملة الطول، وهو ما كانت عليه الحال قبل هذا كلّه.
    nonisolated static func headingOrientation(for interface: UIInterfaceOrientation) -> CLDeviceOrientation {
        switch interface {
        case .portrait:           return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft:      return .landscapeRight
        case .landscapeRight:     return .landscapeLeft
        case .unknown:            return .portrait
        @unknown default:         return .portrait
        }
    }
}

extension HeadingProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading سالب حين تكون خدمات الموقع مغلقة؛ عندها نقع على المغناطيسي.
        let trueH = newHeading.trueHeading
        let usable = trueH >= 0 ? trueH : newHeading.magneticHeading
        let isTrue = trueH >= 0
        let acc = newHeading.headingAccuracy
        Task { @MainActor in
            // يُراجَع المرجع مع كل قراءة: ثمنُه مقارنةٌ واحدة، ويكسب أن الخطأ — إن سبق
            // إشعارُ الدورة استقرارَ الواجهة — لا يعيش أكثر من قراءةٍ واحدة.
            syncHeadingOrientation()
            heading = usable
            usesTrueNorth = isTrue
            accuracy = acc
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}
