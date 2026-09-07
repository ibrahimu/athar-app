import Foundation
import WatchConnectivity
import WidgetKit

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

    // MARK: عدّ المسبحة يُرسل إلى الهاتف دفعاتٍ مؤجّلة — لا رسالة مع كل نقرة.
    private var pendingDelta = 0
    private var flushWork: DispatchWorkItem?

    func reportTasbih(_ delta: Int) {
        pendingDelta += delta
        flushWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flush() }
        flushWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    private func flush() {
        guard pendingDelta > 0 else { return }
        // ما إن يهدأ العدّ حتى تلحق به مضاعفة اليوم على الواجهة — لا مع كل حبّة.
        // المفتاح نفسه المسجَّل في TasbihComplication.
        WidgetCenter.shared.reloadTimelines(ofKind: "AtharWatchTasbih")
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        WCSession.default.transferUserInfo(["tasbihDelta": pendingDelta, "at": Date().timeIntervalSince1970])
        pendingDelta = 0
    }
}
