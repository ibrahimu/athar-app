import Foundation
import UIKit
import WatchConnectivity

/// يرسل إعدادات المواقيت إلى الساعة كلما تغيّرت — الساعة كانت تحسب على المدينة الافتراضية
/// لأن لا شيء يخبرها بمدينة المستخدم.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    private var leavingObserver: NSObjectProtocol?

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        if s.activationState != .activated { s.activate() }
        observeLeaving()
    }

    /// وخروج التطبيق إلى الخلف يرسل أيضًا: من بدّل لون الويدجت أو الطابع ثم أقفل هاتفه ورفع
    /// معصمه، وجد الساعة على اختياره — لا ينتظر فتحةً أخرى للتطبيق.
    private func observeLeaving() {
        guard leavingObserver == nil else { return }
        leavingObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { _ in WatchSync.shared.push(store: AtharStore.shared) }
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

    /// تسبيح الساعة يُضاف إلى عدّاد الهاتف ومجموع الأذكار — حتى يكون الرقم واحدًا في الجهازين.
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let delta = userInfo["tasbihDelta"] as? Int, delta > 0 else { return }
        DispatchQueue.main.async {
            let store = AtharStore.shared
            store.tasbihCount += delta
            store.totalDhikrCount += delta
            store.noteDhikr(delta)   // وإلا غاب تسبيح الساعة عن إحصاء الشهر
        }
    }
}
