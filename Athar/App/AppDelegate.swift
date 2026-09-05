import UIKit

/// اختصارات الضغط المطوّل على الأيقونة (المصحف، المسبحة، القبلة، الحديث) — تُستقبل هنا وتُحوَّل وجهةً.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        if let item = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem { Self.handle(item) }
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(Self.handle(shortcutItem))
    }

    @discardableResult
    static func handle(_ item: UIApplicationShortcutItem) -> Bool {
        guard let tab = AppTab(rawValue: item.type.replacingOccurrences(of: "com.ibrahim.athar.", with: "")) else { return false }
        DispatchQueue.main.async { AtharStore.shared.pendingRoute = .tab(tab) }
        return true
    }
}
