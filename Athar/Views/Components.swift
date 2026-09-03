import SwiftUI

// MARK: - Screen background

/// خلفية الشاشة: ورق سادة بنقش هندسي محفور ناعم جدًا (يُحسّ ولا يُقرأ)،
/// وغسالة لونية علوية بلون القسم، ونغمة سفلية خافتة.
/// كل شاشة تمرّر لونها المميّز (Hifz بحري، Wird فجري…)، وتبقى النغمة ناعمة.
struct AtharBackground: View {
    var tint: Color = Theme.accent
    var secondary: Color? = nil          // النغمة السفلية (افتراضيًا ذهبي)
    var motif: Bool = true

    var body: some View {
        Theme.canvas
            .overlay { if motif { PaperMotif().allowsHitTesting(false) } }  // نقش الورق كامل الصفحة
            .overlay(alignment: .topTrailing) {
                // وهج علوي بلون القسم — شكل مموّه بدل تدرّج شعاعي، فلا حزوز ولا تكسّر
                Circle()
                    .fill(tint.opacity(0.16))
                    .frame(width: 460, height: 460)
                    .blur(radius: 110)
                    .offset(x: 120, y: -230)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                // نغمة سفلية خافتة جدًا (اتجاه عربي: أسفل اليسار) — مموّهة كذلك
                Circle()
                    .fill((secondary ?? Theme.gold).opacity(0.10))
                    .frame(width: 380, height: 380)
                    .blur(radius: 120)
                    .offset(x: -120, y: 160)
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}

// MARK: - نقش الورق (تبليط هندسي محفور، ناعم ومموّه)

/// نقش الورق — يتبع اختيار المستخدم (نجوم/سادة/موج/تعريشة). كله باهت جدًا
/// ومموّه قليلًا، «يُحسّ لا يُقرأ»، ويُرسم مرّة عبر Canvas بلا تبكسل.
struct PaperMotif: View {
    var tint: Color = Theme.ink
    var pattern: BackgroundPattern = BackgroundPattern.current
    var intensity: Double = 1        // مضاعف للمعاينات في الإعدادات
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let op = (scheme == .dark ? 0.028 : 0.020) * intensity
        Group {
            switch pattern {
            case .plain:
                Color.clear
            case .stars:
                Canvas { ctx, size in
                    let cell: CGFloat = 96, r: CGFloat = 20
                    let color = tint.opacity(op)
                    var row = 0; var y: CGFloat = -cell / 2
                    while y < size.height + cell {
                        let off: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                        var x: CGFloat = -cell / 2 + off
                        while x < size.width + cell {
                            let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                            ctx.fill(EightPointStar(innerRatio: 0.64).path(in: rect), with: .color(color))
                            x += cell
                        }
                        y += cell * 0.86; row += 1
                    }
                }
                .blur(radius: 0.6)
            case .waves:
                Canvas { ctx, size in
                    // حلقات أثر القطرة من الزاوية العليا اليمنى (هوية «أثر»)
                    let c = CGPoint(x: size.width * 0.9, y: size.height * 0.12)
                    let color = tint.opacity(op * 0.9)
                    var r: CGFloat = 40
                    while r < size.width * 1.7 {
                        let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                        ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.2)
                        r += 46
                    }
                }
                .blur(radius: 0.5)
            case .lattice:
                Canvas { ctx, size in
                    // تعريشة قُطرية متشابكة
                    let step: CGFloat = 52
                    let color = tint.opacity(op * 0.85)
                    var d: CGFloat = -size.height
                    while d < size.width + size.height {
                        var p1 = Path(); p1.move(to: CGPoint(x: d, y: 0)); p1.addLine(to: CGPoint(x: d + size.height, y: size.height))
                        ctx.stroke(p1, with: .color(color), lineWidth: 0.9)
                        var p2 = Path(); p2.move(to: CGPoint(x: d, y: 0)); p2.addLine(to: CGPoint(x: d - size.height, y: size.height))
                        ctx.stroke(p2, with: .color(color), lineWidth: 0.9)
                        d += step
                    }
                }
                .blur(radius: 0.5)
            case .dots:
                Canvas { ctx, size in
                    // نقاط ناعمة منتظمة
                    let cell: CGFloat = 40, r: CGFloat = 2.4
                    let color = tint.opacity(op * 1.15)
                    var row = 0; var y: CGFloat = cell / 2
                    while y < size.height + cell {
                        let off: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                        var x: CGFloat = cell / 2 + off
                        while x < size.width + cell {
                            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                     with: .color(color))
                            x += cell
                        }
                        y += cell; row += 1
                    }
                }
                .blur(radius: 0.4)
            case .scales:
                Canvas { ctx, size in
                    // حراشف — أقواس متراكبة صفًّا بعد صف (زخرفة إسلامية)
                    let r: CGFloat = 30
                    let color = tint.opacity(op * 0.9)
                    var row = 0; var y: CGFloat = 0
                    while y < size.height + r {
                        let off: CGFloat = row.isMultiple(of: 2) ? 0 : r
                        var x: CGFloat = -r + off
                        while x < size.width + r {
                            var arc = Path()
                            arc.addArc(center: CGPoint(x: x, y: y), radius: r,
                                       startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                            ctx.stroke(arc, with: .color(color), lineWidth: 0.9)
                            x += r * 2
                        }
                        y += r; row += 1
                    }
                }
                .blur(radius: 0.5)
            }
        }
    }
}

// MARK: - زخرفة نجمية مفردة (لزوايا البطاقات البطلة والأيقونات)

/// نجمة ثمانية واحدة كبيرة كعلامة مائية باهتة جدًا. السقف المطلق للشفافية ٠٫٠٥.
struct GeometryMotif: View {
    var tint: Color = Theme.ink
    var intensity: Double = 1
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let base = (scheme == .dark ? 0.05 : 0.035) * intensity
        GeometryReader { g in
            let s = min(g.size.width, g.size.height) * 1.1
            EightPointStar(innerRatio: 0.68)
                .fill(tint.opacity(min(0.06, base)))
                .frame(width: s, height: s)
                .position(x: g.size.width * 0.84, y: g.size.height * 0.32)
        }
        .clipped()
    }
}

extension View {
    /// زخرفة هندسية باهتة خلف العنصر (خلف الأيقونات وزوايا البطاقات البطلة).
    func motifTexture(_ tint: Color = Theme.ink, intensity: Double = 1) -> some View {
        background(GeometryMotif(tint: tint, intensity: intensity))
    }
}

// MARK: - Card

struct AtharCard<Content: View>: View {
    var padding: CGFloat = 18
    var elevation: Theme.Elevation = .e1
    var tint: Color? = nil            // بطاقة «لحظة» مصبوغة بلون قسمها
    var radius: CGFloat = Theme.Radius.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardSurface(radius: radius, tint: tint, elevation: elevation))
    }
}

/// سطح البطاقة الموحّد: تعبئة متدرّجة + حدّ شعري + بريق علوي + عمق مزدوج.
/// مصدر واحد يرثه كل سطح في التطبيق.
struct CardSurface: View {
    var radius: CGFloat = Theme.Radius.lg
    var tint: Color? = nil
    var elevation: Theme.Elevation = .e1
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(tint.map { Theme.surfaceTint($0) } ?? Theme.surfaceGradient)
            .overlay(shape.strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
            .overlay(alignment: .top) {
                // بريق على الحافة العلوية يلتقط الضوء
                LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.06 : 0.5), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 6)
                    .mask(shape)
                    .allowsHitTesting(false)
            }
            .atharElevation(elevation)
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 8
    var gradient: Bool = false        // قوس متدرّج بدل لون مصمت
    var ticks: Int = 0                // علامات خافتة حول المسار (مثل أجزاء المصحف)
    var glow: Bool = false            // توهّج يشتدّ قرب الإتمام

    private var p: Double { max(0.001, min(1, progress)) }

    private var arcStyle: AnyShapeStyle {
        gradient
            ? AnyShapeStyle(AngularGradient(colors: [color, color.opacity(0.55), color],
                                            center: .center, angle: .degrees(-90)))
            : AnyShapeStyle(color)
    }

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.16), lineWidth: lineWidth)

            if ticks > 0 {
                ForEach(0..<ticks, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(0.22))
                        .frame(width: lineWidth * 0.14, height: lineWidth * 0.5)
                        .offset(y: -0.5)
                        .rotationEffect(.degrees(Double(i) / Double(ticks) * 360))
                }
                .padding(lineWidth / 2)
            }

            let arc = Circle()
                .trim(from: 0, to: p)
                .stroke(arcStyle, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if glow {
                arc.blur(radius: 6).opacity(0.25 + 0.45 * p)
            }
            arc.animation(Motion.smooth, value: progress)
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var tint: Color = Theme.accent
    var action: (() -> Void)?
    var actionTitle: String = loc("الكل")

    var body: some View {
        HStack(spacing: 9) {
            // شارة بلون القسم على الحافة البادئة (يمين في العربية)
            Capsule()
                .fill(tint)
                .frame(width: 3, height: 16)
            Text(title)
                .font(Theme.display(19, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let action {
                Button(actionTitle, action: action)
                    .font(Theme.display(14, weight: .medium))
                    .foregroundStyle(tint)
            }
        }
    }
}

// MARK: - Readable width

extension View {
    /// Caps content at a comfortable measure so iPad does not stretch cards edge to edge.
    func readableWidth(_ max: CGFloat = 680) -> some View {
        frame(maxWidth: max)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func step(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func done(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Settings building blocks
//
// شاشة الإعدادات كانت Form افتراضيًا وسط تصميم مخصص. هذه اللبنات تجعلها
// من نفس نسيج بقية التطبيق: بطاقات هادئة، فواصل شعرية، ومساحة تتنفّس.

/// عنوان مجموعة: صغير، خافت، ومتباعد الحروف.
struct SettingsGroupTitle: View {
    let text: String
    var tint: Color = Theme.accent
    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint.opacity(0.85))
                .frame(width: 7, height: 7)
            Text(text)
                .font(Theme.display(12, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(tint.opacity(0.85))
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// بطاقة تضمّ صفوفًا، بفواصل شعرية بينها تلقائيًا.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(Theme.surfaceGradient)
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5)
            )
            .atharElevation(.e1)
    }
}

/// فاصل شعري مُزاح ليحاذي بداية النص لا حافة البطاقة.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline.opacity(0.55))
            .frame(height: 0.7)
            .padding(.leading, 60)
    }
}

// MARK: - رقاقة الأيقونة الموحّدة

/// أيقونة في دائرة ناعمة بلون قسمها — بثلاثة أحجام لا أكثر، فلا تتفرّق الرقاقات
/// إلى ثماني مقاسات وثلاث شفافيات كما كانت: صغيرة للصفوف، متوسّطة للبلاطات،
/// كبيرة لصفوف الروابط البارزة.
struct IconChip: View {
    enum Size: CGFloat { case sm = 32, md = 40, lg = 46 }
    let icon: String
    var tint: Color = Theme.accent
    var size: Size = .md

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size.rawValue * 0.45, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size.rawValue, height: size.rawValue)
            .background(Circle().fill(tint.opacity(0.13)))
    }
}

/// صف رابط بارز داخل بطاقة: رقاقة كبيرة، عنوان ووصف، وسهم — بدل أربع نسخ يدوية.
struct AtharLinkRow: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    var subtitle: String? = nil
    var padding: CGFloat = 16

    var body: some View {
        AtharCard(padding: padding) {
            HStack(spacing: 14) {
                IconChip(icon: icon, tint: tint, size: .lg)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

/// صف إعداد: أيقونة في دائرة ملوّنة ناعمة، عنوان، ووصف اختياري، ثم عنصر التحكم.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 13) {
            IconChip(icon: icon, tint: tint, size: .sm)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.display(16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, tint: Color = Theme.accent, title: String, subtitle: String? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// قيمة نصية هادئة في نهاية الصف.
struct SettingsValue: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.display(15, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            .monospacedDigit()
    }
}

// MARK: - Settings picker
//
// القوائم المنسدلة كانت تلتف وتغطّي الصفوف تحتها حين يطول اسم الخيار.
// هذا الصف يعرض المختار مختصرًا، ويفتح شاشة اختيار مريحة فيها الشرح كاملًا.

protocol SettingsChoice: Hashable, Identifiable {
    var title: String { get }
    var shortTitle: String { get }
    var detail: String { get }
}

struct SettingsPickerRow<T: SettingsChoice>: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    let options: [T]
    @Binding var selection: T

    var body: some View {
        NavigationLink {
            SettingsChoiceList(title: title, options: options, selection: $selection)
        } label: {
            SettingsRow(icon: icon, tint: tint, title: title) {
                HStack(spacing: 6) {
                    Text(selection.shortTitle)
                        .font(Theme.display(15, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsChoiceList<T: SettingsChoice>: View {
    let title: String
    let options: [T]
    @Binding var selection: T
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                VStack(spacing: 8) {
                    SettingsCard {
                        ForEach(Array(options.enumerated()), id: \.element.id) { i, option in
                            Button {
                                selection = option
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: selection == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(selection == option ? Theme.accent : Theme.hairline)
                                        .padding(.top, 1)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.title)
                                            .font(Theme.display(16, weight: selection == option ? .semibold : .regular))
                                            .foregroundStyle(Theme.ink)
                                            .multilineTextAlignment(.leading)
                                        Text(option.detail)
                                            .font(Theme.display(12))
                                            .foregroundStyle(Theme.inkFaint)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if i < options.count - 1 { SettingsDivider() }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}

// MARK: - زخرفة إسلامية

/// نجمة ثمانية (رَبّ) — الشكل التقليدي حول أرقام السور في المصاحف.
struct EightPointStar: Shape {
    var innerRatio: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2
        let r = R * innerRatio
        var p = Path()
        for i in 0..<16 {
            let radius = i.isMultiple(of: 2) ? R : r
            let angle = (.pi / 8) * CGFloat(i) - .pi / 2
            let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// ميدالية رقم السورة: نجمة ذهبية مزدوجة الحدّ، كما في حاشية المصحف.
struct SurahMedallion: View {
    let number: Int
    var size: CGFloat = 46
    // لون الطابع يُمرَّر كقيمة (لا يُقرأ ساكنًا) ليُعاد رسم النجمة فور تبديل الثيم.
    var tint: Color = Theme.accent

    var body: some View {
        ZStack {
            EightPointStar()
                .fill(tint.opacity(0.12))
            EightPointStar()
                .stroke(LinearGradient(colors: [tint, tint.opacity(0.7)],
                                       startPoint: .topTrailing, endPoint: .bottomLeading), lineWidth: 1.4)
            EightPointStar(innerRatio: 0.72)
                .stroke(tint.opacity(0.35), lineWidth: 0.7)
                .padding(5)
            Text(number.counterText)
                .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - فاصلة الآية

/// ميدالية نهاية الآية — دائرة مزخرفة بالرقم داخلها، كما في المصحف المطبوع.
/// (القوسان ﴿﴾ للاقتباس في النص العادي، لا لترقيم الآي.)
struct AyahMedallion: View {
    let number: Int
    var size: CGFloat = 26
    var tint: Color = Theme.gold

    private var arabicDigits: String {
        let ar = Array("٠١٢٣٤٥٦٧٨٩")
        return String(String(number).compactMap { c in
            c.wholeNumberValue.map { ar[$0] }
        })
    }

    var body: some View {
        ZStack {
            // إطار خارجي بأشعة دقيقة — زخرفة المصاحف المعتادة
            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(tint.opacity(0.5))
                    .frame(width: size * 0.055, height: size * 0.13)
                    .offset(y: -size * 0.435)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            Circle()
                .stroke(tint.opacity(0.85), lineWidth: max(0.8, size * 0.035))
                .frame(width: size * 0.76, height: size * 0.76)
            Circle()
                .fill(tint.opacity(0.10))
                .frame(width: size * 0.76, height: size * 0.76)
            Text(arabicDigits)
                .font(.system(size: size * 0.36, weight: .medium))
                .foregroundStyle(tint)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(width: size * 0.64)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(loc("الآية %1$@", number.counterText))
    }
}

/// مطابقة لغات الواجهة لبروتوكول الاختيار — هنا لأن البروتوكول في هدف
/// التطبيق وAppLanguage في الملفات المشتركة مع الويدجت.
extension AppLanguage: SettingsChoice {}

// MARK: - أزرار متدرّجة موحّدة

/// الزر الأساسي (CTA): تعبئة متدرّجة بلون القسم، نص onAccent، وظلّ ملوّن يرفعه عن الورق.
struct AtharPrimaryButton: View {
    let title: String
    var icon: String? = nil
    var gradient: LinearGradient = Theme.accentGradient
    var glowTint: Color = Theme.accent
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(Theme.display(16, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(gradient))
            .shadow(color: glowTint.opacity(0.28), radius: 12, y: 6)
        }
        .pressable()
    }
}

extension View {
    /// خلفية زر متدرّجة بظلّ ملوّن — لأي Label/نص زرّ قائم.
    func gradientButton(_ gradient: LinearGradient = Theme.accentGradient,
                        glow: Color = Theme.accent,
                        radius: CGFloat = Theme.Radius.md) -> some View {
        self
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(gradient))
            .shadow(color: glow.opacity(0.28), radius: 12, y: 6)
    }

    /// زر ثانوي ناعم: صبغة خفيفة، نصّ بلون القسم، حدّ شعري.
    func softButton(_ tint: Color = Theme.accent, radius: CGFloat = Theme.Radius.md) -> some View {
        self
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(tint.opacity(0.18), lineWidth: 0.5))
            )
    }
}

// MARK: - مكافأة الإتمام (بذوق، بلا مبالغة)

/// وميض دائري لمرّة واحدة عند إتمام صغير — يتمدّد ويتلاشى في نصف ثانية.
struct CompletionBloom: View {
    var tint: Color = Theme.accent
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [tint.opacity(0.28), .clear],
                                 center: .center, startRadius: 0, endRadius: 90))
            .scaleEffect(reduceMotion ? 1 : (on ? 1.3 : 0.8))
            .opacity(on ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { on = true }
            }
            .allowsHitTesting(false)
    }
}

/// هالة احتفاء لذُرى الإنجاز الحقيقية فقط (ختم المراجعة، إتمام الورد، ختم القرآن،
/// بلوغ هدف التسبيح): توهّج ذهبي ناعم + حلقة أشعّة نجمية باهتة تظهر بنبضة نابضة.
/// لا قصاصات، لا حلقات لانهائية، ويتلطّف مع «تقليل الحركة».
struct CelebrationHalo: View {
    var tint: Color = Theme.gold
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [tint.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: 130))
                .scaleEffect(shown ? 1 : 0.6)
                .opacity(shown ? 1 : 0)

            ForEach(0..<12, id: \.self) { i in
                Capsule()
                    .fill(tint.opacity(0.5))
                    .frame(width: 2.5, height: 12)
                    .offset(y: -70)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            .opacity(shown ? 0.9 : 0)
            .scaleEffect(shown ? 1 : 0.85)
        }
        .allowsHitTesting(false)
        .onAppear {
            if reduceMotion { shown = true }
            else { withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { shown = true } }
        }
    }
}

// MARK: - مكدّس تنقّل اختياري

/// يلفّ المحتوى بمكدّس تنقّل، إلا حين يُعرض القسم داخل مكدّس قائم
/// (كفتحه من شاشة «الأقسام») فيُترك بلا مكدّس ثانٍ يضاعف شريط العنوان.
struct MaybeStack<Content: View>: View {
    let embedded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        if embedded { content } else { NavigationStack { content } }
    }
}
