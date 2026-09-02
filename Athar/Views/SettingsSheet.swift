import SwiftUI

/// الإعدادات صارت تُفتح من شاشة اليوم بدل تبويب مستقل، لتُفسح مكانًا للمصحف.
/// هذا الغلاف يعيد استخدام محتوى SettingsView بلا NavigationStack متداخل.
struct SettingsSheet: View {
    var body: some View {
        SettingsView(embedded: true)
    }
}
