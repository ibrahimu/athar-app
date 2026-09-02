import SwiftUI

// MARK: - الكعبة (🕋) — مكعّب أحادي اللون بحزام (فراغ) — مبسّطة

/// ظِلّ الكعبة: مربّع بفراغ أفقيّ رفيع في ثلثه الأعلى (الحزام) — لون واحد يتلوّن.
struct KaabaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) * 0.74
        let x = rect.midX - s/2, y = rect.midY - s/2
        var p = Path()
        p.addRect(CGRect(x: x, y: y, width: s, height: s))                    // الجسم
        p.addRect(CGRect(x: x, y: y + s*0.22, width: s, height: s*0.085))     // فراغ الحزام (even-odd)
        return p
    }
}

/// علامة الكعبة بلون واحد (للبطاقات).
struct KaabaMark: View {
    var color: Color = Theme.ink
    var body: some View {
        KaabaShape().fill(style: FillStyle(eoFill: true)).foregroundStyle(color)
    }
}

// MARK: - سجّادة الصلاة — مستطيل طوليّ بشريطين (علويّ وسفليّ) طالعين للأطراف

/// ظِلّ سجّادة: مستطيل طوليّ بعرض موحّد، مقسوم بشريطين علويّ وسفليّ (طرفا السجّادة)
/// يفصلهما عن الجسم فراغان رفيعان. الثلاثة بنفس العرض.
struct PrayerMatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width * 0.60
        let x = rect.midX - w/2
        let top = rect.minY + rect.height * 0.06
        let bot = rect.maxY - rect.height * 0.06
        let total = bot - top
        let barH = total * 0.14          // ارتفاع الشريطين
        let gap  = total * 0.05          // الفراغ بين الشريط والجسم
        var p = Path()
        p.addRect(CGRect(x: x, y: top, width: w, height: barH))                                   // شريط علويّ
        p.addRect(CGRect(x: x, y: top + barH + gap, width: w, height: total - 2*(barH+gap)))      // الجسم
        p.addRect(CGRect(x: x, y: bot - barH, width: w, height: barH))                            // شريط سفليّ
        return p
    }
}

// MARK: - تحويل شكل إلى أيقونة تبويب (قالب أحادي اللون يتلوّن مع الاختيار)

enum AtharIconRenderer {
    @MainActor
    static func templateImage(_ shape: some Shape, size: CGFloat = 27) -> Image {
        let r = ImageRenderer(content:
            shape.fill(style: FillStyle(eoFill: true)).frame(width: size, height: size))
        r.scale = 3
        #if canImport(UIKit)
        if let ui = r.uiImage?.withRenderingMode(.alwaysTemplate) { return Image(uiImage: ui) }
        #endif
        return Image(systemName: "square")
    }
}
