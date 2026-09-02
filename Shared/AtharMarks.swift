import SwiftUI

// MARK: - الكعبة (🕋) — مكعّب أسود مسطّح بحزام الكسوة الذهبي وباب

/// علامة الكعبة الملوّنة: مربّع حبريّ + حزام ذهبيّ في أعلاه + باب — تُرندَر ملوّنة.
struct KaabaMark: View {
    var body: some View {
        GeometryReader { g in
            let s = min(g.size.width, g.size.height)
            let bw = s * 0.70          // عرض المكعّب
            let bh = s * 0.74          // ارتفاعه
            ZStack {
                // جسم الكعبة (حواف شبه حادّة)
                RoundedRectangle(cornerRadius: s * 0.03, style: .continuous)
                    .fill(Theme.ink)
                    .frame(width: bw, height: bh)
                // حزام الكسوة الذهبي في الثلث الأعلى
                Rectangle()
                    .fill(Theme.goldGradient)
                    .frame(width: bw, height: s * 0.10)
                    .offset(y: -bh * 0.24)
                // الباب الذهبي أسفل المنتصف
                Rectangle()
                    .fill(Theme.gold)
                    .frame(width: s * 0.12, height: s * 0.22)
                    .offset(y: bh * 0.26)
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

/// ظِلّ الكعبة (أحادي) — للأماكن التي تحتاج شكلًا قالبيًّا فقط.
struct KaabaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let bw = rect.width * 0.70, bh = rect.height * 0.74
        let x = rect.midX - bw/2, y = rect.midY - bh/2
        var p = Path()
        p.addRect(CGRect(x: x, y: y, width: bw, height: bh))                 // الجسم
        // فراغ الحزام (خطّ فاتح) عبر even-odd
        p.addRect(CGRect(x: x, y: y + bh*0.20, width: bw, height: bh*0.12))
        return p
    }
}

// MARK: - سجّادة الصلاة — مستطيل طوليّ حادّ، وخطّ واحد أسفله طالع للأطراف

/// ظِلّ سجّادة: مستطيل طوليّ بحواف حادّة، وخطّ أفقيّ قرب الأسفل أعرض منه
/// (يبرز يمينًا ويسارًا) يوحي بطرف السجّادة.
struct PrayerMatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width * 0.46
        let h = rect.height * 0.86
        let x = rect.midX - w/2
        let y = rect.midY - h/2
        var p = Path()
        // جسم السجّادة (مستطيل حادّ)
        p.addRect(CGRect(x: x, y: y, width: w, height: h))
        // خطّ واحد قرب الأسفل، أعرض من الجسم (يطلع للأطراف)
        let barW = rect.width * 0.72
        let barH = h * 0.055
        p.addRect(CGRect(x: rect.midX - barW/2, y: y + h*0.82, width: barW, height: barH))
        return p
    }
}

// MARK: - تحويل شكل/عنصر إلى أيقونة تبويب

enum AtharIconRenderer {
    /// قالب أحادي اللون يتلوّن مع اختيار التبويب.
    @MainActor
    static func templateImage(_ shape: some Shape, size: CGFloat = 27) -> Image {
        let r = ImageRenderer(content: shape.frame(width: size, height: size))
        r.scale = 3
        #if canImport(UIKit)
        if let ui = r.uiImage?.withRenderingMode(.alwaysTemplate) { return Image(uiImage: ui) }
        #endif
        return Image(systemName: "square")
    }

    /// صورة ملوّنة كما هي (لا تتلوّن) — للكعبة الأسود/الذهبي.
    @MainActor
    static func coloredImage(_ view: some View, size: CGFloat = 27) -> Image {
        let r = ImageRenderer(content: view.frame(width: size, height: size))
        r.scale = 3
        #if canImport(UIKit)
        if let ui = r.uiImage?.withRenderingMode(.alwaysOriginal) { return Image(uiImage: ui) }
        #endif
        return Image(systemName: "cube.fill")
    }
}
