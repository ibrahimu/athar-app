import Foundation
import CoreLocation

/// One-shot location lookup. Nothing is transmitted — the coordinate is written
/// to the shared store so prayer times can be computed on device.
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
            store.setDeviceLocation(location.coordinate, name: name)
            isResolving = false
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
