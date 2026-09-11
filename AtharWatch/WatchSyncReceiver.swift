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
        // جلسةٌ مفعّلة سلفًا لا يُنادى مندوبُها من جديد، فما بقي في الدفتر من
        // تسبيحٍ لم يصل الهاتفَ يُستأنف من هنا أيضًا لا من المندوب وحده.
        resumePendingTasbih()
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        // ما أرسله الهاتف قبل الاستيقاظ محفوظ في receivedApplicationContext.
        let ctx = session.receivedApplicationContext
        if !ctx.isEmpty { DispatchQueue.main.async { AtharStore.shared.applyWatchContext(ctx) } }
        guard state == .activated else { return }
        resumePendingTasbih()
    }

    func session(_ session: WCSession, didReceiveApplicationContext ctx: [String: Any]) {
        DispatchQueue.main.async { AtharStore.shared.applyWatchContext(ctx) }
    }

    // MARK: عدّ المسبحة يُرسل إلى الهاتف دفعاتٍ مؤجّلة — لا رسالة مع كل نقرة.

    /// الدفتر مكتوبٌ في التخزين لا في الذاكرة: كانت الدفعة تعيش في مهمةٍ مؤجّلة
    /// ثلاث ثوانٍ لا غير، فمن سبّح ثم أسقط معصمه — أو أُغلق التطبيق قبل أن تحين —
    /// ذهب تسبيحه كأن لم يكن. والمكتوب يبقى حتى يبلغ الهاتف.
    ///
    /// وفيه عددان في مفتاحٍ واحد: `pending` ما لم يُسلَّم بعد، و`handedOff` ما
    /// سُلّم إلى WatchConnectivity ولم يُمحَ من الدفتر بعدُ. جُمعا في مفتاح واحد
    /// عمدًا لأن كل انتقالٍ بينهما لا بدّ أن يكون كتابةً واحدة: لو كانا مفتاحين
    /// لوقع الموت بين الكتابتين، فضاع عدٌّ أو تضاعف.
    private static let tasbihLedgerKey = "athar.watch.tasbih.ledger"
    private let ledger = UserDefaults(suiteName: AtharStore.appGroup) ?? .standard
    private var flushWork: DispatchWorkItem?

    private var tasbihLedger: (pending: Int, handedOff: Int) {
        get {
            let v = ledger.array(forKey: Self.tasbihLedgerKey) as? [Int] ?? []
            return (max(0, v.first ?? 0), max(0, v.count > 1 ? v[1] : 0))
        }
        set {
            ledger.set([max(0, newValue.pending), max(0, newValue.handedOff)],
                       forKey: Self.tasbihLedgerKey)
        }
    }

    func reportTasbih(_ delta: Int) {
        guard delta > 0 else { return }
        let book = tasbihLedger
        tasbihLedger = (book.pending + delta, book.handedOff)
        flushWork?.cancel()
        let w = DispatchWorkItem { [weak self] in self?.flush() }
        flushWork = w
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: w)
    }

    /// الإرسال كلّه من هذا الباب: نداءان متعاقبان لا يضاعفان العدّ لأن الثاني
    /// يجد الدفتر صفرًا — والهاتف يجمع كل ما يصله بلا تمييزٍ للمكرَّر.
    private func flush() {
        var book = tasbihLedger
        // علامةُ تسليمٍ باقية = مات التطبيق بين تسليم الدفعة ومحوها من الدفتر.
        // تُحسب واصلةً ولا تُعاد: طابور WatchConnectivity محفوظ على القرص يُسلَّم
        // ولو أُغلق التطبيق، وتضييعُ دفعةٍ في تلك اللحظة الضيّقة أهون من أن
        // يُنسب إلى المسبِّح تسبيحٌ لم يُسبّحه.
        if book.handedOff > 0 {
            book = (max(0, book.pending - book.handedOff), 0)
            tasbihLedger = book
        }
        guard book.pending > 0 else { return }
        // ما إن يهدأ العدّ حتى تلحق به مضاعفة اليوم على الواجهة — لا مع كل حبّة.
        // المفتاح نفسه المسجَّل في TasbihComplication.
        WidgetCenter.shared.reloadTimelines(ofKind: "AtharWatchTasbih")
        // الجلسة غير مفعّلة: يبقى الدفتر على حاله حتى تُفعَّل فيُستأنف الإرسال.
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        let sending = book.pending
        tasbihLedger = (sending, sending)      // علامةٌ قبل التسليم
        WCSession.default.transferUserInfo(["tasbihDelta": sending, "at": Date().timeIntervalSince1970])
        // ولا يُمحى المؤجَّل إلا بعد أن يستلمه الإطار. والطرح لا التصفير: ما عُدّ
        // بعد قراءة الدفتر ليس من الدفعة المسلَّمة فلا يُمحى معها.
        tasbihLedger = (max(0, tasbihLedger.pending - sending), 0)
    }

    /// الاستئناف على الخيط الرئيس كالعدّ نفسه، فلا يلتقي قارئان على الدفتر.
    private func resumePendingTasbih() {
        DispatchQueue.main.async { [weak self] in self?.flush() }
    }
}
