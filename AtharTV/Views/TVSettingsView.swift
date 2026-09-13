import SwiftUI

// MARK: - الإعدادات
//
// شاشةٌ واحدة بلا تمرير: ثلاثةُ أشرطةٍ من أعلى إلى أسفل — اللونُ، فالنقشُ، فما
// تُحسب به المواقيت. كلُّ ما يُضبط يُرى دفعةً واحدة، والمِرقابُ يمشي فيها كما
// تمشي العين: فوق وتحت بين الأشرطة، ويمينًا ويسارًا بين الخيارات.
//
// وكانت قبلُ قائمةً تُمرَّر، فقال صاحبُها «النقش ما أقدر أختار». وقِيس الأمرُ
// بسجلِّ التركيز لا بالظنّ: المِرقابُ كان يبلغ النقوشَ والمدينةَ فعلًا، وإنما
// لم يُرَ. فالعيبُ ثلاثةٌ كلُّها في العين لا في الطريق:
//   التركيزُ بلا أثر — تكبيرٌ بثلاثةٍ في المئة لا غير، والمختارُ من النقوش عليه
//     حدٌّ يُشبه حدَّ التركيز، فيظنّ الواقفُ على «نجوم» أن المِرقاب لا يتحرّك.
//   والنقوشُ الستّة مربّعاتٌ بمئتي نقطة، النقشُ فيها بثلث حجمه وحبرُه خافت، فلا
//     يُفرَّق بينها من ثلاثة أمتار.
//   والمكانُ تحت طيّ الشاشة، ومن نزل إليه انزلق المحتوى تحت العنوان.
//
// فالعلاجُ: حدٌّ للتركيز يُرى من آخر الغرفة ويختلف عن علامة الاختيار؛ ونقوشٌ
// كبيرةٌ مرفوعةُ الحبر تُقارَن؛ وشاشةٌ تسع كلَّ شيءٍ فلا تُمرَّر أصلًا.
struct TVSettingsView: View {
    @ObservedObject private var prefs = TVPrefs.shared
    @FocusState private var focus: Focus?
    @State private var page: Page = .main
    @State private var showCities = false

    var onClose: (() -> Void)?

    private enum Focus: Hashable {
        case back, theme(String), pattern(String), city, method, choice(String)
    }

    /// الشاشةُ الأمّ، أو قائمةُ طرق الحساب مكانَها — كما تُبدَّل «ماذا نسمع؟»
    /// مكانَ شبكة القرّاء: صفحةٌ تحلّ محلّ صفحة، لا غطاءٌ فوق غطاء.
    private enum Page { case main, method }

    /// مقاساتُ الشاشة. لا رقمَ في موضعه — tvOS بلا «حجمٍ ديناميكي».
    private enum Metric {
        /// مربّعُ اللون: اثنا عشرَ في صفٍّ واحد على عرض الشاشة — والحسابُ مقيَّد:
        /// ١٢ × ١٢٤ + ١١ × ٢٢ = ١٧٣٠، والمتاحُ بعد حافّتَي الأمان ١٧٤٠. وبـ١٣٦
        /// فاض الصفُّ عن الشاشة فجرّ العنوانَ وزرَّ الرجوع إلى حافّة الزجاج.
        static let swatch: CGFloat = 124
        static let swatchRadius: CGFloat = 24
        /// مربّعُ النقش: أطولُ ما يسعه الشرطُ، لأن `TVPattern.unit` تُصغِّر النقشَ
        /// بصغر لوحه — ولوحٌ بمئتين وخمسين يُري النجمةَ بثلثي حجمها لا بثلثه.
        static let tile: CGFloat = 250
        static let tileRadius: CGFloat = TVMetric.tileRadius
        /// حدُّ التركيز: خمسُ نقاطٍ تُرى من ثلاثة أمتار، لا ثلاثٌ تُحزَر.
        static let ring: CGFloat = 5
        /// صفُّ الحقل في أسفل الشاشة.
        static let field: CGFloat = 92
        static let fieldRadius: CGFloat = 22
        /// بين الخيارات في الشرط الواحد، وبين الأشرطة.
        static let gap: CGFloat = 22
        static let bandGap: CGFloat = 40
        /// حبرُ النقش في المعاينة: الأرضُ على ٠٫٠٠٩ «تُحسّ ولا تُقرأ»، والمعاينةُ
        /// تُقرأ وتُقارَن — فيُرفع هنا وحده إلى نحو النصف ولا تُمسّ معايرةُ الأرض.
        static let previewBoost: Double = 50
    }

    var body: some View {
        TVScreen(title: title, subtitle: subtitle,
                 onBack: back, backFocused: focus == .back) {
            switch page {
            case .main:   main
            case .method: methods
            }
        }
        .fullScreenCover(isPresented: $showCities) {
            CityPickerView { showCities = false }
        }
        .onAppear { focus = .theme(prefs.theme.rawValue) }
        // العودةُ من اختيار المدينة تُعيد التركيز إلى صفّها لا إلى أوّل الشاشة.
        .onChange(of: showCities) { _, shown in if !shown { focus = .city } }
        .onExitCommand(perform: back)
    }

    private var title: String {
        page == .main ? loc("الإعدادات") : loc("طريقة الحساب")
    }

    private var subtitle: String? {
        page == .main ? nil : loc("بها يُحسب الفجرُ والعشاء، وأمّ القرى هي المعتمدة في السعودية.")
    }

    /// من طرق الحساب إلى الإعدادات، ومن الإعدادات إلى المجلس.
    private func back() {
        if page == .method {
            withAnimation(Motion.gentle) { page = .main }
            focus = .method
        } else {
            onClose?()
        }
    }

    // MARK: الشاشة الأمّ — ثلاثة أشرطة

    private var main: some View {
        VStack(alignment: .leading, spacing: Metric.bandGap) {
            band(loc("اللون"), "paintpalette", value: prefs.theme.title) {
                HStack(spacing: Metric.gap) {
                    ForEach(AppTheme.allCases) { swatch($0) }
                    Spacer(minLength: 0)
                }
                .focusSection()
            }
            band(loc("النقش"), "square.grid.3x3", value: prefs.pattern.title) {
                HStack(spacing: Metric.gap) {
                    ForEach(BackgroundPattern.allCases) { patternTile($0) }
                }
                .focusSection()
            }
            HStack(spacing: Metric.gap) {
                field(loc("المكان"), value: prefs.city?.name ?? loc("اختر مدينتك"),
                      symbol: "mappin.and.ellipse", key: .city) { showCities = true }
                // طريقةُ الحساب صفٌّ لا شريط: المدنُ في القائمة تبلغ القاهرة وكراتشي
                // وأمريكا، وأمُّ القرى فيها تُقدِّم الفجرَ عن حسابِ أهلها بربع ساعة —
                // ومواقيتُ خاطئة خطأٌ في الدين لا في الواجهة. أمّا مذهبُ العصر فلم
                // يُدرَج: أهلُ الجمهور هم جمهورُ من يُخاطبهم التطبيق، وصفٌّ رابع
                // ثمنُه من بساطة الشاشة أكبرُ من نفعه.
                field(loc("طريقة الحساب"), value: prefs.method.shortTitle,
                      symbol: "sun.horizon", key: .method) {
                    withAnimation(Motion.gentle) { page = .method }
                    focus = .choice(prefs.method.rawValue)
                }
            }
            .focusSection()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// شريطٌ: رمزُه واسمُه وقيمتُه الحالية في سطرٍ واحد، وتحته خياراتُه.
    /// والقيمةُ إلى جوار الاسم لا في طرف السطر الآخر: على عرض مترٍ ونصف لا تصل
    /// العينُ بين كلمتين بينهما فراغُ الشاشة كلُّه.
    private func band<C: View>(_ title: String, _ symbol: String, value: String,
                               @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: TVType.caption, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(Theme.display(TVType.title, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(value)
                    .font(Theme.display(TVType.caption, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                Spacer(minLength: 0)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: اللون

    /// مربّعُ لونٍ بلا اسم. اثنا عشرَ لونًا في صفٍّ واحد لا يسعُ الاسمَ، واللونُ
    /// من ثلاثة أمتار يُغني عن اسمه؛ والاسمُ يُقرأ في رأس الشريط للمختار منها.
    /// (شاشةُ أوّل تشغيلٍ تسعُ الاسمَ فتُبقيه في `TVSwatch`.)
    ///
    /// وحدُّ التركيز حبرٌ لا لونُ طابع: حدٌّ أخضر على مربّعٍ أخضر لا يُرى، والحبرُ
    /// يُرى على الاثني عشر كلِّها. والمختارُ عليه علامةٌ في صدره — فالتركيزُ حدٌّ
    /// والاختيارُ علامة، ولا يلتبس أحدُهما بالآخر كما التبس من قبل.
    private func swatch(_ theme: AppTheme) -> some View {
        let key = Focus.theme(theme.rawValue)
        let on = focus == key
        let shape = RoundedRectangle(cornerRadius: Metric.swatchRadius, style: .continuous)
        return Button { prefs.theme = theme } label: {
            ZStack(alignment: .topLeading) {
                shape.fill(
                    LinearGradient(colors: [Color(hex: theme.palette.accent.dark),
                                            Color(hex: theme.palette.accent2.dark)],
                                   startPoint: .topTrailing, endPoint: .bottomLeading)
                )
                TVStar()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: Metric.swatch * 1.1, height: Metric.swatch * 1.1)
                    .offset(x: -Metric.swatch * 0.36, y: -Metric.swatch * 0.34)
                if prefs.theme == theme {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: TVType.title, weight: .bold))
                        .foregroundStyle(Color(hex: theme.palette.canvas.dark))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: Metric.swatch, height: Metric.swatch)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.ink.opacity(on ? 0.95 : 0), lineWidth: Metric.ring))
        }
        .focused($focus, equals: key)
        .tvButton(on, radius: Metric.swatchRadius)
    }

    // MARK: النقش

    /// مربّعُ نقشٍ: ورقٌ عليه النقشُ نفسُه مرفوعَ الحبر، واسمُه في أسفله من اليمين،
    /// والمختارُ عليه علامة. والتعبئةُ والحدُّ على شكلٍ واحد — لا حدٌّ خلف حافّة.
    private func patternTile(_ p: BackgroundPattern) -> some View {
        let key = Focus.pattern(p.rawValue)
        let on = focus == key
        let chosen = prefs.pattern == p
        let shape = RoundedRectangle(cornerRadius: Metric.tileRadius, style: .continuous)
        return Button { prefs.pattern = p } label: {
            ZStack(alignment: .bottomLeading) {
                shape.fill(Theme.surface)
                TVPattern(pattern: p, theme: prefs.theme, boost: Metric.previewBoost)
                    .clipShape(shape)
                // صبغةُ التركيز فوق النقش لا تحته، فلا يتبدّل حبرُ المعاينة بتبدّل
                // التركيز ويبقى ما يُقارَن هو هو.
                shape.fill(Theme.accent.opacity(on ? 0.14 : 0))
                HStack(spacing: 12) {
                    Text(p.title)
                        .font(Theme.display(TVType.body, weight: chosen || on ? .bold : .medium))
                        .foregroundStyle(chosen ? Theme.accent : (on ? Theme.ink : Theme.inkSoft))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if chosen {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: TVType.caption, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: Metric.tile)
            .overlay(shape.strokeBorder(on ? Theme.accent.opacity(0.9) : Theme.hairline.opacity(0.6),
                                        lineWidth: on ? Metric.ring : 2))
        }
        .focused($focus, equals: key)
        .tvButton(on, radius: Metric.tileRadius)
    }

    // MARK: الحقلان — المكان وطريقة الحساب

    /// حقلٌ يُفتح: رمزٌ واسمٌ، وقيمتُه في طرفه الآخر وبجانبها سهمٌ يقول إن وراءه
    /// شاشة. وله جسمٌ ساكن — تعبئةٌ خفيفة بلون الطابع — بخلاف `TVRow` التي تسكن
    /// شفّافةً: تلك صفٌّ في قائمة والقائمةُ جسمُها، وهذان حقلان وحيدان في أسفل
    /// الشاشة، وبلا جسمٍ بدَوا سطرَي نصٍّ متناثرَين لا زرّين. والتعبئةُ والحدُّ على
    /// شكلٍ واحد كما في كلّ صفوف التطبيق.
    private func field(_ title: String, value: String, symbol: String, key: Focus,
                       action: @escaping () -> Void) -> some View {
        let on = focus == key
        let shape = RoundedRectangle(cornerRadius: Metric.fieldRadius, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: TVType.caption, weight: .medium))
                    .foregroundStyle(on ? Theme.accent : Theme.inkFaint)
                    .frame(width: 42)
                Text(title)
                    .font(Theme.display(TVType.body, weight: on ? .bold : .medium))
                    .foregroundStyle(on ? Theme.ink : Theme.inkSoft)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                Spacer(minLength: 14)
                Text(value)
                    .font(Theme.display(TVType.caption, weight: .regular))
                    .foregroundStyle(on ? Theme.ink : Theme.inkFaint)
                    .lineLimit(1)
                // في العربية يُشار إلى ما وراءَ بسهمٍ إلى اليسار.
                Image(systemName: "chevron.left")
                    .font(.system(size: TVType.footnote, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Metric.field)
            .background(
                shape.fill(Theme.accent.opacity(on ? 0.16 : 0.06))
                    .overlay(shape.strokeBorder(Theme.accent.opacity(on ? 0.85 : 0), lineWidth: 3))
            )
        }
        .focused($focus, equals: key)
        .tvButton(on, radius: Metric.fieldRadius)
    }

    /// الصفُّ نفسُه الذي في قائمة المدن — لقائمة طرق الحساب.
    private func row(_ title: String, detail: String?, symbol: String?, key: Focus,
                     action: @escaping () -> Void) -> some View {
        let on = focus == key
        return Button(action: action) {
            TVRow(title: title, detail: detail, symbol: symbol, focused: on)
        }
        .focused($focus, equals: key)
        .tvButton(on, radius: 22)
    }

    // MARK: طريقة الحساب

    /// ستُّ طرق، صفٌّ لكلٍّ منها، والمختارةُ عليها علامة. يُختار فيُرجَع من فوره —
    /// كما تُختار المدينةُ فتُغلق قائمتُها.
    private var methods: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(CalculationMethod.allCases) { m in
                row(m.title, detail: m.detail,
                    symbol: prefs.method == m ? "checkmark.circle.fill" : nil,
                    key: .choice(m.rawValue)) {
                    prefs.method = m
                    back()
                }
            }
        }
        .frame(maxWidth: 1600, alignment: .leading)
        .focusSection()
    }
}
