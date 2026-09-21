import SwiftUI
import WatchConnectivity

struct WatchSetupView: View {
    @Environment(\.scenePhase) private var phase
    @State private var paired = false
    @State private var installed = false
    var body: some View {
        List {
            Section {
                Label("أثر على Apple Watch", systemImage: "applewatch").font(Theme.display(20, weight: .semibold))
                Text(paired ? (installed ? "أثر مثبّت على الساعة المقترنة." : "الساعة مقترنة، وأثر غير مثبّت عليها بعد.") : "لم تظهر ساعة مقترنة بهذا الآيفون.")
                    .font(Theme.display(15))
                Button("تحديث الحالة") { refresh() }
            }
            Section("التثبيت مع تطبيق الآيفون") {
                Text("تطبيق الساعة مضمّن مع أثر. فعّل «تثبيت التطبيقات تلقائيًا» من تطبيق Watch على الآيفون ← ساعتي ← عام، ليضيف النظام التطبيقات المتوافقة إلى ساعتك.")
                Text("إذا كان أثر محذوفًا من الساعة، افتح Watch وانزل إلى «التطبيقات المتاحة»، ثم اختر تثبيت بجانب أثر. قد يحتاج التنزيل وقتًا واتصالًا بالإنترنت ومساحة كافية.")
            }
            Section {
                Text("التثبيت التلقائي إعداد للنظام؛ لا يستطيع أثر تغييره أو تثبيت نفسه على الساعة دون سماحك. الألوان وإعدادات المواقيت تُرسل إلى الساعة المثبّت عليها التطبيق.")
                Link("دليل Apple لتطبيقات الساعة", destination: URL(string: "https://support.apple.com/guide/watch/get-apps-apd99e3c6a68/watchos")!)
            }
        }
        .scrollContentBackground(.hidden)
        .background { AtharBackground(tint: Theme.accent) }
        .font(Theme.display(15)).foregroundStyle(Theme.ink).tint(Theme.accent)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("تجهيز الساعة").environment(\.layoutDirection, .rightToLeft)
        .onAppear { WatchSync.shared.activate(); refresh() }
        .onChange(of: phase) { _, value in if value == .active { refresh() } }
    }
    private func refresh() {
        guard WCSession.isSupported() else { return }
        paired = WCSession.default.isPaired
        installed = WCSession.default.isWatchAppInstalled
    }
}
