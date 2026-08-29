import Foundation
import CoreLocation

/// اتجاه القبلة ومسافتها — حساب فلكي بحت على الجهاز، بلا شبكة.
enum Qibla {

    /// الكعبة المشرّفة.
    static let kaaba = CLLocationCoordinate2D(latitude: 21.4224779, longitude: 39.8251832)

    /// نصف قطر الأرض المتوسط بالكيلومترات.
    private static let earthRadiusKm = 6371.0088

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }

    /// الزاوية الابتدائية للدائرة العظمى من الموقع إلى الكعبة، بالدرجات من الشمال الحقيقي
    /// (٠ شمال، ٩٠ شرق). ترجع nil إن كان الموقع هو الكعبة نفسها فلا اتجاه له.
    static func bearing(from origin: CLLocationCoordinate2D) -> Double? {
        let phi1 = rad(origin.latitude)
        let phi2 = rad(kaaba.latitude)
        let dLambda = rad(kaaba.longitude - origin.longitude)

        let y = sin(dLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLambda)

        // عند الكعبة تمامًا يتلاشى المتجه ولا يبقى اتجاه معرَّف.
        guard abs(y) > 1e-12 || abs(x) > 1e-12 else { return nil }

        let theta = deg(atan2(y, x))
        return (theta + 360).truncatingRemainder(dividingBy: 360)
    }

    /// مسافة الدائرة العظمى إلى الكعبة بالكيلومترات (صيغة هافرساين).
    static func distanceKm(from origin: CLLocationCoordinate2D) -> Double {
        let phi1 = rad(origin.latitude)
        let phi2 = rad(kaaba.latitude)
        let dPhi = rad(kaaba.latitude - origin.latitude)
        let dLambda = rad(kaaba.longitude - origin.longitude)

        let a = sin(dPhi / 2) * sin(dPhi / 2)
            + cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2)
        return 2 * earthRadiusKm * asin(min(1, sqrt(a)))
    }

    /// اسم الجهة بالعربية لزاوية بالدرجات.
    static func compassName(for bearing: Double) -> String {
        let names = ["الشمال", "الشمال الشرقي", "الشرق", "الجنوب الشرقي",
                     "الجنوب", "الجنوب الغربي", "الغرب", "الشمال الغربي"]
        let idx = Int((bearing / 45).rounded()) % 8
        return names[idx]
    }

    /// هل الموقع قريب جدًا من الكعبة بحيث لا معنى لعرض بوصلة؟
    static func isAtKaaba(_ origin: CLLocationCoordinate2D) -> Bool {
        distanceKm(from: origin) < 0.05   // ٥٠ مترًا
    }
}
