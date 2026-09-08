import Foundation

/// «فيه تحديث»: يسأل متجر التطبيقات عن آخر إصدارٍ منشور ويقارنه بالمُشغَّل الآن.
///
/// لماذا: المتجر لا يُخبر إلا من فتحه، ومن أطفأ التحديث التلقائي يبقى على نسخته
/// أشهرًا — فتُصلَح العلّة عندنا ولا تصل إليه. فيُقال له في التطبيق نفسه مرّةً،
/// بلطف: بطاقةٌ تُغلق ولا تعود، لا جدارٌ يمنعه من الاستعمال.
///
/// وما يخرج من الجهاز: معرّفُ التطبيق وحده إلى واجهة متجر Apple — لا شيء عن صاحبه.
/// والفشل صامت: التطبيق يعمل بلا إنترنت، فغيابُ الشبكة ليس خبرًا يُزعَج به.
@MainActor
final class UpdateCheck: ObservableObject {
    static let shared = UpdateCheck()

    /// الإصدار المنشور في المتجر إن كان أحدث من المُشغَّل — وإلا nil.
    @Published private(set) var available: String?

    private enum Key {
        static let lastCheck = "athar.update.lastCheck"
        static let seen      = "athar.update.dismissed"   // آخر إصدارٍ أُغلقت بطاقته
    }

    /// مرّة كل يوم على الأكثر: السؤال رخيص لكنّه شبكة، ولا جديد في المتجر كل ساعة.
    private static let interval: TimeInterval = 24 * 60 * 60

    private var defaults: UserDefaults { UserDefaults(suiteName: AtharStore.appGroup) ?? .standard }

    var current: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// أُغلقت بطاقةُ هذا الإصدار فلا تعود — حتى ينزل إصدارٌ بعده.
    var dismissed: Bool {
        guard let v = available else { return true }
        return defaults.string(forKey: Key.seen) == v
    }

    func dismiss() {
        guard let v = available else { return }
        defaults.set(v, forKey: Key.seen)
        objectWillChange.send()
    }

    /// يُنادى عند تنشيط التطبيق. لا يرمي ولا ينتظر: ما لم يصل جوابٌ صالح لم يتغيّر شيء.
    func refresh(force: Bool = false) {
        let last = defaults.object(forKey: Key.lastCheck) as? Date
        if !force, let last, Date().timeIntervalSince(last) < Self.interval { return }
        Task { await fetch() }
    }

    private func fetch() async {
        let id = Bundle.main.bundleIdentifier ?? "com.ibrahim.athar"
        // بلا معرّف بلد: المتجر يستنتجه، والسؤال عن الإصدار لا عن السعر.
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(id)") else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 8
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let store = results.first?["version"] as? String
        else { return }

        defaults.set(Date(), forKey: Key.lastCheck)
        available = Self.isNewer(store, than: current) ? store : nil
    }

    /// مقارنة إصدارين عددًا عددًا: «١٫١٠» أحدث من «١٫٩»، والمقارنة النصّية تقول العكس.
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0
            let r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
