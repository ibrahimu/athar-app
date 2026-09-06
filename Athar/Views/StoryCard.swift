import SwiftUI
import UIKit

/// بطاقة قصّة (١٠٨٠×١٩٢٠) لسناب وواتساب: تدرّج بلون الطابع الحالي، نجمة ثمانية
/// باهتة، والعبارة وسطًا بخط النسخ (والتهاني بخط الواجهة) — حجمها يصغر كلما طال النص
/// فلا يفيض عن الإطار. الخطوط كلها بأحجام ثابتة: اللوحة لا تتبع حجم خطّ النظام.
struct StoryCard: View {
    let phrase: Phrase

    static let size = CGSize(width: 1080, height: 1920)

    /// ألوان الطابع تُقرأ ساكنةً هنا لأن البطاقة تُصيَّر خارج شجرة الواجهة (ImageRenderer)
    /// ولا تُعاد رسمها عند تبديل الطابع.
    private var top: Color { Color(hex: Theme.current.accent2.light) }
    private var mid: Color { Color(hex: Theme.current.accent.light) }
    private var bottom: Color { StoryCard.shade(Theme.current.accent.light, 0.55) }

    private var text: String { phrase.text }
    private var attribution: String { phrase.attribution }

    /// قياس اللفظ كاملًا؛ طول النص وحده لا يكفي لمنع قص الأحاديث الطويلة.
    private var fontSize: CGFloat { Self.fittingFontSize(for: phrase) }

    static func fittingFontSize(for phrase: Phrase) -> CGFloat {
        let name: String
        if phrase.isSacred { name = "NotoNaskhArabic-Regular" }
        else {
            switch AppFont.current {
            case .system: name = ""
            case .naskh: name = "NotoNaskhArabic-Medium"
            case .thmanyah: name = "thmanyahsans-Medium"
            }
        }
        for size in stride(from: CGFloat(64), through: 18, by: -1) {
            let font = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .medium)
            let paragraph = NSMutableParagraphStyle()
            paragraph.baseWritingDirection = .rightToLeft
            paragraph.lineSpacing = size * 0.45
            let rect = (phrase.text as NSString).boundingRect(with: CGSize(width: 888, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font, .paragraphStyle: paragraph], context: nil)
            if rect.height <= 1100 { return size }
        }
        return 18
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [top, mid, bottom], startPoint: .top, endPoint: .bottom)

            // نجمة ثمانية كبيرة محفورة خلف النص — تُحسّ ولا تُقرأ.
            EightPointStar(innerRatio: 0.72)
                .stroke(Color.white.opacity(0.10), lineWidth: 3)
                .frame(width: 1320, height: 1320)
                .offset(y: 60)
            EightPointStar(innerRatio: 0.72)
                .fill(Color.white.opacity(0.04))
                .frame(width: 900, height: 900)
                .offset(y: 60)

            VStack(spacing: 44) {
                Spacer(minLength: 0)
                ornamentLine
                Text(text)
                    .font(phrase.isSacred ? Theme.dhikrFont(fixed: fontSize)
                                          : AppFont.current.font(size: fontSize, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(fontSize * 0.45)
                    .fixedSize(horizontal: false, vertical: true)
                if !attribution.isEmpty {
                    Text(attribution)
                        .font(Theme.naskhFont(fixed: 30))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ornamentLine
                Spacer(minLength: 0)
            }
            .frame(width: StoryCard.size.width - 192)
            .padding(.horizontal, 96)
            .padding(.vertical, 200)

            VStack {
                Spacer()
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill").font(.system(size: 26)).foregroundStyle(.white.opacity(0.9))
                    Text("أثر").font(Theme.naskhFont(fixed: 34, bold: true)).foregroundStyle(.white.opacity(0.9))
                }
                .padding(.bottom, 120)
            }
        }
        .frame(width: StoryCard.size.width, height: StoryCard.size.height)
        .clipped()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.dynamicTypeSize, .large)
    }

    private var ornamentLine: some View {
        HStack(spacing: 14) {
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 140, height: 2)
            EightPointStar().fill(Color.white.opacity(0.7)).frame(width: 18, height: 18)
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 140, height: 2)
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

    /// تُصيَّر بمقياس ١ لأن الإطار نفسه بدقّة القصص (١٠٨٠×١٩٢٠).
    @MainActor
    static func render(phrase: Phrase) -> UIImage? {
        let renderer = ImageRenderer(content: StoryCard(phrase: phrase))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}
