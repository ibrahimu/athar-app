import Foundation
import CoreLocation

/// One-shot location lookup. The coordinate is written to the shared store so prayer
/// times can be computed on device. The only thing that leaves the device is the
/// coordinate handed to Apple's CLGeocoder for a display-only city name.
@MainActor
final class LocationProvider: NSObject, ObservableObject {
    @Published var status: CLAuthorizationStatus
    @Published var isResolving = false
    @Published var failed = false

    private let manager = CLLocationManager()
    private let store: AtharStore

    init(store: AtharStore) {
        self.store = store
        self.status = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    /// آخر مرّةٍ طُلب فيها موقعٌ تلقائيًّا — لا يُسأل النظام مع كل فتحةٍ للتطبيق.
    private static var lastAutoRefresh: Date?

    /// تحديثٌ تلقائي لمن اختار «موقع الجهاز»: كان الموقع لا يُطلب إلا بضغطةٍ من صاحبه،
    /// فمن سافر بقيت مواقيتُه على مدينته الأولى إلى أن ينتبه — والتطبيق يَعِد بأنّه
    /// يتبع موقعه. ولا يُسأل إلا كل نصف ساعة، وبإذنٍ قائم لا يُطلب من جديد.
    static func refreshIfNeeded(store: AtharStore) {
        guard store.usesDeviceLocation else { return }
        let status = CLLocationManager().authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        if let last = lastAutoRefresh, Date().timeIntervalSince(last) < 30 * 60 { return }
        lastAutoRefresh = Date()
        let provider = LocationProvider(store: store)
        autoProvider = provider
        provider.request()
    }

    /// يُمسك المزوّد حيًّا حتى يصل الجواب — بلا هذا يُحرَّر قبل نداء المندوب.
    private static var autoProvider: LocationProvider?

    func request() {
        failed = false
        switch manager.authorizationStatus {
        case .notDetermined:
            isResolving = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isResolving = true
            manager.requestLocation()
        default:
            failed = true
        }
    }

    /// كتابةُ ما وصل: الإحداثيّ، والاسمُ كما جاء من الجيوكودر — ولو كان خيبة.
    ///
    /// اسمُ المدينة نداءٌ شبكيّ يخيب بلا إنترنت، والإحداثيّ وحده يكفي للمواقيت. فإن خاب
    /// مرّ الغياب إلى المخزن ليكتب اسمه الاحتياطي. أمّا أن نُعيد إليه الاسمَ المحفوظ —
    /// وهو ما كان — فيعني أن يقرأ المسافرُ «الرياض» فوق مواقيت أبها، وأن يرى فاتحُ
    /// التطبيق أوّلَ مرّةٍ بلا شبكة «مكة المكرمة» فوق إحداثيّ بيته: اسمٌ كاذب أسوأ من
    /// لا اسم، والحارسُ الذي في المخزن يبطُل بذلك ولا يُحسّ.
    func apply(_ coordinate: CLLocationCoordinate2D, name: String?) {
        store.setDeviceLocation(coordinate, name: name)
        isResolving = false
    }
}

extension LocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in
            status = newStatus
            switch newStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                isResolving = false
                failed = true
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            let name = await Self.placeName(for: location)
            apply(location.coordinate, name: name)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            isResolving = false
            failed = true
        }
    }

    private static func placeName(for location: CLLocation) async -> String? {
        let geocoder = CLGeocoder()
        let arabic = Locale(identifier: "ar")
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location, preferredLocale: arabic).first
        else { return nil }
        return placemark.locality ?? placemark.administrativeArea ?? placemark.country
    }
}
