import SwiftUI

// MARK: - وجهُ الخفوت
//
// حين يسكن المِرقاب تنطوي الشاشةُ إلى أقلّ ما يبقى نافعًا: كم الساعةُ الآن،
// ومتى الصلاةُ القادمة. لا مدينةَ ولا طابعَ ولا زرَّ تشغيلٍ ولا اسمَ التطبيق —
// كلُّها أشياءُ يدٍ تُمسك المِرقاب، ولا يدَ الآن.
//
// وليس هذا حافظةَ شاشة: لا ساعةَ تسبح، ولا نبضَ، ولا تلاشيَ يتكرّر. إطارٌ واحد
// ساكن بضوءٍ خافت — «لا حركة للزينة» قاعدةُ `Motion` في هذا المشروع، وشاشةٌ
// تبقى إلى الفجر أولى بها من كل شاشة.
//
// والزخرفةُ ضوء، والضوءُ هو ما نُطفئه: فما في هذا الوجه نقشٌ ولا إطارٌ ولا ظلّ.
// جمالُه أنّه لم يبقَ فيه ما يُحذف.
struct TVDimmer: ViewModifier {
    @ObservedObject var idle: TVIdle
    @ObservedObject private var prefs = TVPrefs.shared
    /// «تقليل الحركة» في إتاحة النظام (`UIAccessibility.isReduceMotionEnabled`
    /// نفسها، لكنها تصل هنا حيّةً تتغيّر مع الإعداد): التلاشي يصير قطعًا.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var veiled: Bool

    private var dimmed: Bool { idle.state != .awake }

    func body(content: Content) -> some View {
        ZStack {
            // المجلسُ يبقى في مكانه لا يُهدم: هدمُه يُعيد تركيبَ ما فيه ويُطلق
            // `onAppear` من جديد، والصوتُ في مشغّلٍ خارج الشاشة لا يبالي —
            // لكنّ إعادةَ البناء في كل خفوتٍ عبث. و`disabled` ترفع أزرارَه من
            // نظام التركيز فلا تصل إليها ضغطةُ إيقاظ: من ضغط ليرى الوقتَ لا
            // يُريد أن يسكت القرآن.
            content
                .opacity(dimmed ? 0 : 1)
                .disabled(dimmed)

            if dimmed { veil }
        }
        .animation(reduceMotion ? nil : Motion.gentle, value: idle.state)
        .onAppear { idle.begin() }
    }

    // MARK: الغطاء

    /// سوادٌ لا لونُ الأرض: بكسلُ OLED الأسودُ مُطفأ لا مُظلم، وغرفةٌ نام أهلُها
    /// لا يُضيئها هذا.
    ///
    /// وهو زرٌّ لا مستطيلًا لأنّ الزرَّ يأخذ التركيزَ ويبتلع ضغطةَ الاختيار معًا:
    /// فأوّلُ ضغطةٍ تقع عليه هو، لا على «إذاعة القرآن» تحته. ولو تُرك مستطيلًا
    /// لكان من مدّ يدَه ليعرف الوقتَ قد أسكت التلاوة.
    private var veil: some View {
        Button { idle.poke() } label: {
            ZStack {
                Color.black
                // وجُرِّب `TVPattern` هنا فرُدّ: حبرُه مُعايَرٌ على أرض الطابع
                // (لمعانُها نحوُ ٢٢) فهو عليها همس، وعلى السواد المطلق تصير
                // النجماتُ ثلاثَ درجاتٍ فوق الصفر — تُرى وتُعدّ، فيصير تحت
                // الساعة ورقٌ مُحلًّى لا فراغ. وقياسًا: لمعانُ الإطار كلِّه
                // يتضاعف (٠٫١٨ ← ٠٫٣٥ من ٢٥٥) زينةً لا غير. صُوِّر فرُئي فحُذف.
                if idle.state == .dim { face }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tvButton(false, radius: 0)
        .focused($veiled)
        .accessibilityLabel(loc("أيقظ الشاشة"))
        // المسحُ على السطح، وزرُّ القائمة، وزرُّ التشغيل: كلُّها هنا إيقاظٌ لا
        // غير. واعتراضُ زرِّ التشغيل مقصود — أوّلُ ضغطةٍ تُعيد الضوءَ ولا تمسّ
        // الصوت، فلا يُسكِت القرآنَ من أراد أن يعرف كم الساعة.
        .onMoveCommand { _ in idle.poke() }
        .onExitCommand { idle.poke() }
        .onPlayPauseCommand { idle.poke() }
        .ignoresSafeArea()
        .onAppear { veiled = true }
    }

    // MARK: ما يبقى

    /// الساعةُ أوّلًا لأنّها سؤالُ من استيقظ في الليل، والصلاةُ تحتها. ولونُ
    /// وقتِ الصلاة لونُ الطابع كما هو في المجلس مضيئًا — خيطٌ واحد يصل الوجهين
    /// بلا أن يُضاف شيء.
    private var face: some View {
        VStack(spacing: 20) {
            Text(clock(idle.beat))
                .font(Theme.display(TVType.clock, weight: .light))
                .foregroundStyle(Theme.ink.opacity(0.24))
                .monospacedDigit()

            if let up = prefs.upcoming(now: idle.beat) {
                // والصغيرُ يحتاج ضوءًا أكثر من الكبير ليُقرأ من المسافة نفسها،
                // فسطرُ الصلاة أظهرُ من الساعة فوقه لا أخفت — والساعةُ تسبقه
                // بحجمها لا بضوئها. وبهذا لم يزد ما تُضيئه الشاشةُ جملةً.
                HStack(spacing: 22) {
                    Text(up.prayer.title)
                        .foregroundStyle(Theme.ink.opacity(0.30))
                    Text(clock(up.date))
                        .foregroundStyle(Theme.accent.opacity(0.42))
                        .monospacedDigit()
                }
                .font(Theme.display(TVType.body, weight: .regular))
            }
        }
    }

    /// بمنطقة المدينة المختارة لا بمنطقة الجهاز، وبأرقامٍ غربية — كما في المجلس.
    /// والمواقيتُ تُؤخذ من `TVPrefs` كما هي ولا تُحسب هنا من جديد: حسابان
    /// لوقتٍ واحد بابُ اختلافٍ في الدين لا في الواجهة.
    ///
    /// ولا «ص/م» هنا وهي في المجلس: اسمُ الصلاة يُغني عنها — لا فجرَ مساءً ولا
    /// عشاءَ صباحًا — وحرفٌ عربيٌّ واحد بين أرقامٍ لاتينية على مئةٍ وعشرين نقطة
    /// يُرى شكلًا رابعًا يُزاحم الوقتَ لا علامةً عليه. جُرِّب فرُئي فحُذف.
    private func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "h:mm"
        f.timeZone = prefs.city?.timeZone ?? .current
        return f.string(from: date)
    }
}

extension View {
    /// سطرٌ واحد يُلبِس الشاشةَ وضعَ النوم: `.tvDim(idle: .shared)`.
    ///
    /// ولا قيمةَ افتراضية لـ`idle` وإن كانت واحدةً لا ثانيَ لها: القيمُ
    /// الافتراضية تُحسب عند المُنادي خارج عزل الفاعل، و`TVIdle.shared` مقصورةٌ
    /// على `@MainActor` — فيصير السطرُ تحذيرًا اليوم وخطأً في Swift 6 غدًا.
    func tvDim(idle: TVIdle) -> some View {
        modifier(TVDimmer(idle: idle))
    }
}
