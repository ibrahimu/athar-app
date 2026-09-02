import SwiftUI

/// إيقاع حركة واحد للتطبيق كله.
///
/// القاعدة التي بُني عليها: **كل حركة تشرح سببًا ونتيجة، ولا حركة للزينة.**
/// لا توهّج، ولا نبض، ولا لمعان — فقط ما يجعل التغيير مفهومًا.
/// وكلها تحترم «تقليل الحركة» في إعدادات الجهاز.
enum Motion {

    // MARK: المدد — قصيرة، والخروج أسرع من الدخول

    static let instant  = 0.14   // ارتداد ضغطة
    static let quick    = 0.20   // تبدّل حالة صغيرة
    static let standard = 0.28   // ظهور/اختفاء عنصر
    static let exit     = 0.18   // الخروج ≈ ٦٥٪ من الدخول

    // MARK: المنحنيات

    /// نابض لطيف بلا ارتداد مزعج — للضغط والانتقالات المكانية.
    static var press: Animation { .spring(response: 0.28, dampingFraction: 0.72) }

    /// سلس للتغيّرات العامة.
    static var smooth: Animation { .smooth(duration: standard) }

    /// أسرع، لتبدّل القيم والحالات.
    static var snappy: Animation { .smooth(duration: quick) }

    /// استقرار المحتوى الوارد — نابض هادئ بلا ارتداد.
    static var arrive: Animation { .spring(response: 0.5, dampingFraction: 0.85) }

    /// تلاشٍ متقاطع للصبغات والتدرّجات (تبدّل لون القسم أو خلفية الوقت).
    static var gentle: Animation { .easeOut(duration: 0.4) }

    /// تتابع ظهور عناصر القوائم: ٣٥ مللي لكل عنصر، وبحدّ أقصى ٨ عناصر
    /// حتى لا ينتظر المستخدم قائمة طويلة.
    static func stagger(_ index: Int) -> Animation {
        .smooth(duration: standard).delay(Double(min(index, 8)) * 0.035)
    }
}

// MARK: - تقليل الحركة

private struct ReducedMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var prefersReducedMotion: Bool {
        get { self[ReducedMotionKey.self] }
        set { self[ReducedMotionKey.self] = newValue }
    }
}

// MARK: - ضغطة محسوسة

/// تصغير خفيف عند الضغط (٠٫٩٧) يرتدّ عند الرفع — يخبر الإصبع أن اللمسة وصلت.
/// لا يزيح التخطيط ولا يحرّك ما حوله.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? scale : 1))
            .animation(Motion.press, value: configuration.isPressed)
    }
}

extension View {
    /// يجعل البطاقة تستجيب للضغط بتصغير خفيف.
    func pressable(scale: CGFloat = 0.97) -> some View {
        buttonStyle(PressableStyle(scale: scale))
    }

    /// ظهور متتابع لعناصر القائمة — يوضّح أنها وصلت واحدًا بعد آخر.
    ///
    /// **مبدأ ملزم:** العنصر ظاهر افتراضيًا، والحركة تحسين فوقه لا شرط لظهوره.
    /// لو تعطّل المؤقّت أو أُلغيت الحركة، يبقى المحتوى مرئيًا — لأن حركة
    /// تُخفي محتوى ليست حركة، بل عطل.
    func appearStagger(_ index: Int) -> some View {
        modifier(StaggerModifier(index: index))
    }
}

private struct StaggerModifier: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 8)
                .onAppear {
                    withAnimation(Motion.stagger(index)) { shown = true }
                }
                // شبكة أمان: لو لم يُطلق onAppear لأي سبب، يظهر العنصر بعد نصف ثانية.
                .task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if !shown { shown = true }
                }
        }
    }
}
