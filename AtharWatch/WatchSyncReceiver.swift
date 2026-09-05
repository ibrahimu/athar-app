import Foundation
import WatchConnectivity

/// يستقبل إعدادات المواقيت من الهاتف ويطبّقها على مخزن الساعة.
final class WatchSyncReceiver: NSObject, WCSessionDelegate {
    static let shared = WatchSyncReceiver()

    func activate() {
        guard WCSession.isSupported() else { return }
        let s = WCSession.default
        s.delegate = self
        s.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // ما أرسله الهاتف قبل الاستيقاظ محفوظ في receivedApplicationContext.
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty { DispatchQueue.main.async { AtharStore.shared.applyWatchContext(ctx) } }
    }

    func session(_ session: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        DispatchQueue.main.async { AtharStore.shared.applyWatchContext(ctx) }
    }
}
