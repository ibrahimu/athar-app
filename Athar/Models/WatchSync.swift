import Foundation
import WatchConnectivity

/// يرسل إعدادات المواقيت إلى الساعة كلما تغيّرت — الساعة كانت تحسب على المدينة الافتراضية
/// لأن لا شيء يخبرها بمدينة المستخدم.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        if s.activationState != .activated { s.activate() }
    }

    /// السياق الأخير يبقى عند النظام حتى تستيقظ الساعة، فلا يضيع إن كانت بعيدة.
    func push(store: AtharStore) {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        guard s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
        try? s.updateApplicationContext(store.watchContext)
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated { push(store: AtharStore.shared) }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) { push(store: AtharStore.shared) }
}
