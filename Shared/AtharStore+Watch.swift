import Foundation
import WidgetKit

// MARK: - مزامنة إعدادات المواقيت بين الهاتف والساعة (WatchConnectivity)

extension AtharStore {
    /// القاموس المرسَل من الهاتف إلى الساعة: كل ما يلزم لحساب المواقيت نفسها هناك.
    var watchContext: [String: Any] {
        var d: [String: Any] = [
            "lat": coordinate.latitude, "lng": coordinate.longitude,
            "place": placeName, "tz": placeTimeZone.identifier,
            "calc": calculationMethod.rawValue, "asr": asrMethod.rawValue,
            // للساعة حاويتها لا يبلغها دفتر الهاتف، فيُحمل إليها اللون والطابع مع المواقيت
            // وإلا بقيت تلبس وقت اليوم مهما اختار «لون الويدجت» في المظهر.
            "palette": widgetPalette.rawValue, "theme": appTheme.rawValue,
            "sent": Date().timeIntervalSince1970,
        ]
        for (p, m) in prayerOffsets { d["offset." + p.rawValue] = m }
        return d
    }

    /// تطبيق ما وصل من الهاتف على مخزن الساعة (يكتب المفاتيح نفسها التي يقرأها الحاسب).
    func applyWatchContext(_ d: [String: Any]) {
        guard let lat = d["lat"] as? Double, let lng = d["lng"] as? Double else { return }
        defaults.set(lat, forKey: "athar.latitude")
        defaults.set(lng, forKey: "athar.longitude")
        if let place = d["place"] as? String { defaults.set(place, forKey: "athar.placeName") }
        if let tz = d["tz"] as? String { defaults.set(tz, forKey: "athar.placeTimeZone") }
        if let calc = d["calc"] as? String { defaults.set(calc, forKey: "athar.calcMethod") }
        if let asr = d["asr"] as? String { defaults.set(asr, forKey: "athar.asrMethod") }
        // هاتفٌ قديم لا يرسلهما؛ فيبقى ما على الساعة على حاله ولا يُكتب فوقه افتراضٌ كاذب.
        if let palette = d["palette"] as? String { defaults.set(palette, forKey: "athar.widgetPalette") }
        if let theme = d["theme"] as? String { defaults.set(theme, forKey: "athar.theme") }
        for p in Prayer.allCases where p.isPrayer {
            if let m = d["offset." + p.rawValue] as? Int { setPrayerOffset(m, for: p) } else { setPrayerOffset(0, for: p) }
        }
        defaults.set(false, forKey: "athar.usesDeviceLocation")
        // الطابع لا يُقرأ إلا عند بناء المخزن، فيُعاد تطبيقه هنا ليلبسه الجهاز الآن لا بعد إغلاقه.
        applyStoredTheme()
        objectWillChange.send()
        // والواجهة خارج التطبيق لا ترى الدفتر حتى تُنعَش — وإلا بقيت مضاعفاتها بلونها القديم.
        WidgetCenter.shared.reloadAllTimelines()
    }
}
