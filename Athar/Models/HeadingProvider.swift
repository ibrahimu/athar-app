import Foundation
import CoreLocation

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

    override init() {
        super.init()
        manager.delegate = self
        manager.headingFilter = 1          // درجة واحدة
        manager.headingOrientation = .portrait
    }

    func start() {
        guard isAvailable else { return }
        manager.startUpdatingHeading()
    }

    func stop() {
        guard isAvailable else { return }
        manager.stopUpdatingHeading()
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
