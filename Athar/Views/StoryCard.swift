import SwiftUI
import UIKit

/// تصميم بطاقة القصّة: اللون (طابع من طوابع التطبيق)، والنقش، والشكل، وخط النص غير الشرعي
/// والتوقيع، وتوقيع اختياري. «المعتمد» = طابع التطبيق الحالي ونجومه وخطّه — ما كان يُشارك
/// بضغطة قبل المصمّم، فمن لم يغيّر شيئًا خرج بالشكل نفسه.
struct StoryDesign: Equatable {
    enum Layout: String, CaseIterable, Identifiable {
        case classic, paper, plaque, minimal, sticker, plaqueSticker
        var id: String { rawValue }
        var title: String {
            switch self {
            case .classic: return loc("المعتمد")
            case .paper:   return loc("ورقة")
            case .plaque:  return loc("لوحة")
            case .minimal: return loc("بسيط")
            case .sticker: return loc("ملصق شفاف")
            case .plaqueSticker: return loc("لوحة شفافة")
            }
        }
        var icon: String {
            switch self {
            case .classic: return "sparkles.rectangle.stack"
            case .paper:   return "doc.plaintext"
            case .plaque:  return "rectangle.inset.filled"
            case .minimal: return "text.alignright"
            case .sticker: return "rectangle.dashed"
            case .plaqueSticker: return "photo.on.rectangle.angled"
            }
        }
    }

    /// لون نص الملصق الشفاف — فوق صورة لا نعرفها: أبيض بظلّ (الأصل)، أو داكن بهالة فاتحة، أو لون الطابع.
    enum StickerInk: String, CaseIterable, Identifiable {
        case white, dark, theme
        var id: String { rawValue }
        var title: String {
            switch self {
            case .white: return loc("أبيض")
            case .dark:  return loc("داكن")
            case .theme: return loc("لون الطابع")
            }
        }
    }

    var theme: AppTheme
    var pattern: BackgroundPattern
    var layout: Layout
    /// خط العبارات العامة والتوقيع. النص الشرعي بخط النسخ دائمًا مهما كان هذا.
    var font: AppFont
    var signature: String = ""
    var stickerInk: StickerInk = .white
    /// كلمة اليوم فوق المتن («جمعة مباركة»). فارغةٌ افتراضًا كالتوقيع: شاشة العبارات
    /// ومعاينات المحفظة تبنيان بطاقاتهما بهذا التصميم نفسه، فلو نطقت من تلقائها
    /// لتبدّلت صورٌ اعتادها الناس بلا أن يطلبوا. من أرادها سمّاها.
    var eyebrow: String = ""

    /// الملصق: نصٌّ وحده على خلفية شفافة، يُلصق فوق أي صورة في سناب أو إنستغرام.
    /// (اللوحة الشفافة ليست منه: لها جسمُها الورقيّ، فلا تُعرض عليها ألوانُ نصّ الملصق.)
    var isSticker: Bool { layout == .sticker }

    /// ما يُصيَّر بخلفيةٍ شفّافة وارتفاعٍ على قدر نصّه — الملصق النصّي واللوحة جميعًا.
    var isTransparent: Bool { layout == .sticker || layout == .plaqueSticker }

    /// اللوحة: ورقٌ كريمي في إطارٍ منقوط — كاملةً على خلفيتها أو شفّافةً فوق صورة.
    var isPlaque: Bool { layout == .plaque || layout == .plaqueSticker }

    static var standard: StoryDesign {
        StoryDesign(theme: Theme.current, pattern: .stars, layout: .classic, font: AppFont.current)
    }
}

/// بطاقة قصّة (١٠٨٠×١٩٢٠) لسناب وواتساب: تدرّج بلون الطابع المختار، نقش باهت، والعبارة وسطًا
/// بخط النسخ (والتهاني بالخط المختار) — حجمها يصغر كلما طال النص فلا يفيض عن الإطار.
/// الخطوط كلها بأحجام ثابتة: اللوحة لا تتبع حجم خطّ النظام.
struct StoryCard: View {
    let phrase: Phrase
    var design: StoryDesign = .standard

    static let size = CGSize(width: 1080, height: 1920)

    /// ألوان الطابع تُقرأ من التصميم لا من Theme.current: البطاقة تُصيَّر خارج شجرة الواجهة
    /// (ImageRenderer) ولا تُعاد رسمها عند تبديل الطابع.
    private var theme: AppTheme { design.theme }
    private var top: Color { Color(hex: theme.accent2.light) }
    private var mid: Color { Color(hex: theme.accent.light) }
    private var bottom: Color { StoryCard.shade(theme.accent.light, 0.55) }
    private var paper: Color { Color(hex: theme.canvas.light) }
    private var paperInk: Color { Color(hex: theme.ink.light) }
    private var paperAccent: Color { Color(hex: theme.accent.light) }

    private var text: String { phrase.text }
    private var attribution: String { phrase.attribution }
    private var isPaper: Bool { design.layout == .paper }
    /// اللوحة ورقٌ كالورقة: حبرها داكن على كريمي، لا أبيض على تدرّج.
    private var onPaper: Bool { isPaper || design.isPlaque }

    /// عرض عمود النص وأقصى ارتفاعه بحسب الشكل: الورقة أضيق بحواشيها.
    private var textWidth: CGFloat {
        if design.isPlaque { return plaqueWidth - 2 * Self.plaqueTextInset }
        return isPaper ? 744 : 888
    }
    private var textMaxHeight: CGFloat { design.isPlaque ? 880 : (isPaper ? 960 : 1100) }

    /// قياس اللفظ كاملًا؛ طول النص وحده لا يكفي لمنع قص الأحاديث الطويلة.
    private var fontSize: CGFloat {
        Self.fittingFontSize(for: phrase, font: design.font, width: textWidth, maxHeight: textMaxHeight)
    }

    nonisolated static func fittingFontSize(for phrase: Phrase, font: AppFont = AppFont.current,
                                width: CGFloat = 888, maxHeight: CGFloat = 1100) -> CGFloat {
        let name: String
        if phrase.isSacred { name = "NotoNaskhArabic-Regular" }
        else {
            switch font {
            case .system: name = ""
            case .naskh: name = "NotoNaskhArabic-Medium"
            case .thmanyah: name = "thmanyahsans-Medium"
            }
        }
        for size in stride(from: CGFloat(64), through: 18, by: -1) {
            let uiFont = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .medium)
            let paragraph = NSMutableParagraphStyle()
            paragraph.baseWritingDirection = .rightToLeft
            paragraph.lineSpacing = size * 0.45
            let rect = (phrase.text as NSString).boundingRect(with: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: uiFont, .paragraphStyle: paragraph], context: nil)
            if rect.height <= maxHeight { return size }
        }
        return 18
    }

    // MARK: ألوان النص بحسب الشكل

    private var ink: Color { onPaper ? paperInk : .white }
    private var inkSoft: Color { onPaper ? paperAccent : .white.opacity(0.82) }
    private var lineInk: Color { onPaper ? paperAccent.opacity(0.55) : .white.opacity(0.35) }
    private var starInk: Color { onPaper ? paperAccent : .white.opacity(0.7) }

    private var textFont: Font {
        phrase.isSacred ? Theme.dhikrFont(fixed: fontSize) : design.font.font(size: fontSize, weight: .medium)
    }

    var body: some View {
        Group {
            if design.isTransparent {
                if design.layout == .plaqueSticker { plaqueSticker } else { sticker }
            } else {
                ZStack {
                    LinearGradient(colors: [top, mid, bottom], startPoint: .top, endPoint: .bottom)
                    motif
                    content
                    brand
                }
                .frame(width: StoryCard.size.width, height: StoryCard.size.height)
                .clipped()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.dynamicTypeSize, .large)
    }

    // MARK: الملصق الشفاف

    /// نصٌّ وعزو وتوقيع فقط، بعرض القصّة وارتفاعٍ على قدر النص، بلا خلفية — الظلّ يُبقيه مقروءًا
    /// فوق صورة فاتحة أو داكنة.
    private var stickerInk: Color {
        switch design.stickerInk {
        case .white: return .white
        case .dark:  return Color(hex: 0x1B2622)
        case .theme: return Color(hex: theme.accent.light)
        }
    }
    private var stickerShadow: Color {
        design.stickerInk == .white ? .black.opacity(0.45) : .white.opacity(0.75)
    }

    private var sticker: some View {
        VStack(spacing: 30) {
            eyebrowLine(stickerInk.opacity(0.9))
            Text(text)
                .font(phrase.isSacred ? Theme.dhikrFont(fixed: 58) : design.font.font(size: 58, weight: .medium))
                .foregroundStyle(stickerInk)
                .multilineTextAlignment(.center)
                .lineSpacing(58 * 0.45)
                .fixedSize(horizontal: false, vertical: true)
            if !attribution.isEmpty {
                Text(attribution)
                    .font(Theme.naskhFont(fixed: 30))
                    .foregroundStyle(stickerInk.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            let signature = design.signature.trimmingCharacters(in: .whitespacesAndNewlines)
            if !signature.isEmpty {
                Text(signature)
                    .font(design.font.font(size: 34, weight: .medium))
                    .foregroundStyle(stickerInk.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .shadow(color: stickerShadow, radius: 7, y: 2)
        .shadow(color: stickerShadow.opacity(0.6), radius: 1, y: 0)
        .frame(width: StoryCard.size.width - 160)
        .padding(80)
        .background(Color.clear)
    }

    // MARK: اللوحة

    /// اللوحة: ورقٌ كريمي في إطارٍ رفيع تتوسّط أضلاعَه أربعُ نقاط — كاللوحات المحفورة.
    /// شكلٌ واحد يُرسم كاملًا على خلفية الطابع، أو شفّافًا يُوضع فوق صورة صاحبه.
    /// الشفّافة أعرض قليلًا: لا خلفية تحتها تحتاج حاشية.
    static let plaqueTextInset: CGFloat = 92
    private var plaqueWidth: CGFloat { design.layout == .plaqueSticker ? 952 : 900 }

    /// حجم اللوحة ثابت المظهر مهما قصر النص: العبارة القصيرة لا تُخرج لوحةً شريطية.
    private var plaqueMinHeight: CGFloat { design.layout == .plaqueSticker ? 560 : 640 }

    private var plaqueBody: some View {
        VStack(spacing: 30) {
            eyebrowLine(paperAccent)
            Text(text)
                .font(textFont)
                .foregroundStyle(paperInk)
                .multilineTextAlignment(.center)
                .lineSpacing(fontSize * 0.45)
                .fixedSize(horizontal: false, vertical: true)
            if !attribution.isEmpty {
                Text(attribution)
                    .font(Theme.naskhFont(fixed: 28))
                    .foregroundStyle(paperAccent.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            signatureLine
        }
        .padding(.horizontal, Self.plaqueTextInset)
        .padding(.vertical, 104)
        .frame(width: plaqueWidth)
        .frame(minHeight: plaqueMinHeight)
        .background(plaqueFrame)
    }

    /// الورق وإطاره: الخطّ الرفيع داخلَه بمسافةٍ ثابتة، وفي وسط كلّ ضلعٍ نقطةٌ تقطعه —
    /// دائرةٌ بلون الورق تفتح له فُرجة، وفيها نقطةٌ بلون الإطار.
    private var plaqueFrame: some View {
        RoundedRectangle(cornerRadius: 64, style: .continuous)
            .fill(paper)
            .overlay {
                RoundedRectangle(cornerRadius: 42, style: .continuous)
                    .strokeBorder(paperAccent.opacity(0.6), lineWidth: 3)
                    .padding(30)
            }
            .overlay(alignment: .top)      { plaqueDot.offset(y: 30) }
            .overlay(alignment: .bottom)   { plaqueDot.offset(y: -30) }
            .overlay(alignment: .leading)  { plaqueDot.offset(x: 30) }
            .overlay(alignment: .trailing) { plaqueDot.offset(x: -30) }
            .shadow(color: .black.opacity(0.22), radius: 36, y: 18)
    }

    private var plaqueDot: some View {
        ZStack {
            Circle().fill(paper).frame(width: 26, height: 26)
            Circle().fill(paperAccent.opacity(0.75)).frame(width: 12, height: 12)
        }
    }

    /// اللوحة الشفافة: اللوحة وحدها وتحتها اسمُ التطبيق صغيرًا، وما حولهما شفّاف —
    /// تُلصق فوق صورةٍ كما هي. الهالة الفاتحة تُبقي الاسم مقروءًا فوق صورةٍ داكنة.
    private var plaqueSticker: some View {
        VStack(spacing: 26) {
            plaqueBody
            HStack(spacing: 9) {
                Image(systemName: "drop.fill").font(.system(size: 24))
                Text("أثر").font(Theme.naskhFont(fixed: 30, bold: true))
            }
            .foregroundStyle(paper)
            .shadow(color: .black.opacity(0.45), radius: 6, y: 2)
        }
        .frame(width: StoryCard.size.width)
        .padding(.vertical, 44)
    }

    // MARK: النقش

    @ViewBuilder private var motif: some View {
        switch design.pattern {
        case .plain:
            EmptyView()
        case .stars:
            // نجمة ثمانية كبيرة محفورة خلف النص — تُحسّ ولا تُقرأ.
            EightPointStar(innerRatio: 0.72)
                .stroke(Color.white.opacity(0.10), lineWidth: 3)
                .frame(width: 1320, height: 1320)
                .offset(y: 60)
            EightPointStar(innerRatio: 0.72)
                .fill(Color.white.opacity(0.04))
                .frame(width: 900, height: 900)
                .offset(y: 60)
        default:
            // نقوش ورق التطبيق نفسها (موج/تعريشة/نقاط/حراشف)، مكبَّرة لدقّة القصص ومقوّاة
            // لتُرى على التدرّج — وتبقى خلف النص لا فوقه.
            PaperMotif(tint: .white, pattern: design.pattern, intensity: 7)
                .frame(width: StoryCard.size.width / 2.5, height: StoryCard.size.height / 2.5)
                .scaleEffect(2.5)
                .frame(width: StoryCard.size.width, height: StoryCard.size.height)
                .environment(\.colorScheme, .light)
        }
    }

    // MARK: المحتوى

    @ViewBuilder private var content: some View {
        switch design.layout {
        case .classic:
            VStack(spacing: 44) {
                Spacer(minLength: 0)
                ornamentLine
                textBlock(.center)
                ornamentLine
                signatureLine
                Spacer(minLength: 0)
            }
            .frame(width: StoryCard.size.width - 192)
            .padding(.horizontal, 96)
            .padding(.vertical, 200)

        case .paper:
            VStack(spacing: 40) {
                ornamentLine
                textBlock(.center)
                ornamentLine
                signatureLine
            }
            .padding(.horizontal, 72)
            .padding(.vertical, 96)
            .frame(width: 888)
            .background(
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .fill(paper)
                    .shadow(color: .black.opacity(0.22), radius: 44, y: 22)
            )
            .padding(.horizontal, 96)
            .padding(.vertical, 200)

        case .plaque:
            plaqueBody
                .padding(.horizontal, 90)
                .padding(.vertical, 180)

        case .minimal:
            VStack(alignment: .leading, spacing: 40) {
                Spacer(minLength: 0)
                textBlock(.leading)
                signatureLine
                Spacer(minLength: 0)
            }
            .frame(width: StoryCard.size.width - 192, alignment: .leading)
            .padding(.horizontal, 96)
            .padding(.vertical, 200)

        case .sticker, .plaqueSticker:
            // الشفّافان لهما جسماهما الخاصّان — لا يمرّان من هنا.
            EmptyView()
        }
    }

    /// النص ثم العزو. المحاذاة «البادئة» في الاتجاه العربي = اليمين.
    private func textBlock(_ alignment: TextAlignment) -> some View {
        let frameAlignment: Alignment = alignment == .leading ? .leading : .center
        return VStack(alignment: alignment == .leading ? .leading : .center, spacing: 36) {
            eyebrowLine(inkSoft)
            Text(text)
                .font(textFont)
                .foregroundStyle(ink)
                .multilineTextAlignment(alignment)
                .lineSpacing(fontSize * 0.45)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            if !attribution.isEmpty {
                Text(attribution)
                    .font(Theme.naskhFont(fixed: 30))
                    .foregroundStyle(inkSoft)
                    .multilineTextAlignment(alignment)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
    }

    /// كلمة اليوم فوق المتن — بخط الواجهة لا بخط النسخ، فهي من عندنا لا من المصدر،
    /// وسطرٌ واحد يتضاءل ولا يلتفّ حتى لا يزاحم النصّ الذي جاءت تُصدّره.
    /// لا تُرسم البتّة ما لم تُسمَّ، فتبقى البطاقات القديمة على حالها.
    @ViewBuilder private func eyebrowLine(_ color: Color) -> some View {
        let eyebrow = design.eyebrow.trimmingCharacters(in: .whitespacesAndNewlines)
        if !eyebrow.isEmpty {
            Text(eyebrow)
                .font(design.font.font(size: 34, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    /// التوقيع أو الإهداء بخط التصميم — يظهر فقط إن كُتب.
    @ViewBuilder private var signatureLine: some View {
        let signature = design.signature.trimmingCharacters(in: .whitespacesAndNewlines)
        if !signature.isEmpty {
            Text(signature)
                .font(design.font.font(size: 36, weight: .medium))
                .foregroundStyle(inkSoft)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ornamentLine: some View {
        HStack(spacing: 14) {
            Rectangle().fill(lineInk).frame(width: 140, height: 2)
            EightPointStar().fill(starInk).frame(width: 18, height: 18)
            Rectangle().fill(lineInk).frame(width: 140, height: 2)
        }
    }

    private var brand: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                Image(systemName: "drop.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.9))
                Text("أثر").font(Theme.naskhFont(fixed: 34, bold: true)).foregroundStyle(.white.opacity(0.9))
            }
            .padding(.bottom, 120)
        }
    }

    /// درجة أغمق من لون سداسي — لطرف التدرّج السفلي.
    private static func shade(_ hex: UInt32, _ factor: Double) -> Color {
        Color(.sRGB,
              red:   Double((hex >> 16) & 0xFF) / 255 * factor,
              green: Double((hex >>  8) & 0xFF) / 255 * factor,
              blue:  Double( hex        & 0xFF) / 255 * factor,
              opacity: 1)
    }

    /// تُصيَّر بمقياس ١ لأن الإطار نفسه بدقّة القصص (١٠٨٠×١٩٢٠). الملصق شفّاف وارتفاعه على
    /// قدر نصّه (العرض ١٠٨٠) ليُلصق فوق أي صورة.
    @MainActor
    static func render(phrase: Phrase, design: StoryDesign = .standard) -> UIImage? {
        let renderer = ImageRenderer(content: StoryCard(phrase: phrase, design: design))
        renderer.scale = 1
        if design.isTransparent {
            renderer.isOpaque = false
            renderer.proposedSize = ProposedViewSize(width: size.width, height: nil)
        } else {
            renderer.proposedSize = ProposedViewSize(size)
        }
        return renderer.uiImage
    }

    /// الملصق يُشارك ملفَّ PNG لا صورةً: بعض الوجهات تحوّل UIImage إلى JPEG فتضيع الشفافية.
    @MainActor
    static func stickerFile(phrase: Phrase, design: StoryDesign) -> URL? {
        guard let image = render(phrase: phrase, design: design), let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("athar-sticker.png")
        do { try data.write(to: url, options: .atomic) } catch { return nil }
        return url
    }
}
