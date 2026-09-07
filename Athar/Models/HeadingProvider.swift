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

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1          // درجة واحدة
        manager.headingOrientation = .portrait

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
        ]
    }

    deinit {
        for token in lifecycle { NotificationCenter.default.removeObserver(token) }
        manager.stopUpdatingHeading()
    }

    func start() {
        guard isAvailable else { return }
        wantsUpdates = true
        manager.startUpdatingHeading()
    }

    func stop() {
        wantsUpdates = false
        guard isAvailable else { return }
        manager.stopUpdatingHeading()
    }

    /// يوقف الحسّاس دون إسقاط الطلب، فتعود القراءة مع عودة التطبيق إلى الواجهة.
    private func suspend() {
        guard isAvailable else { return }
        manager.stopUpdatingHeading()
    }

    /// يعيد الحسّاس فقط إن كان الطلب ما زال قائمًا (start بلا stop بعده).
    private func resume() {
        guard isAvailable, wantsUpdates else { return }
        manager.startUpdatingHeading()
    }

    var needsCalibration: Bool { accuracy < 0 || accuracy > 25 }
}

extension HeadingProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // trueHeading سالب حين تكون خدمات الموقع مغلقة؛ عندها نقع على المغناطيسي.
        let trueH = newHeading.trueHeading
        let usable = trueH >= 0 ? trueH : newHeading.magneticHeading
        let isTrue = trueH >= 0
        let acc = newHeading.headingAccuracy
        Task { @MainActor in
            heading = usable
            usesTrueNorth = isTrue
            accuracy = acc
        }
    }

    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }
}
