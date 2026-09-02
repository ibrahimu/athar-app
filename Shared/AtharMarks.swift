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

/// ظِلّ سجّادة: جسم طوليّ، وفوقه وتحته شريطان أعرض منه (طرفا السجّادة).
struct PrayerMatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let midX = rect.midX
        let bodyW = rect.width * 0.42
        let barW  = rect.width * 0.68
        let top = rect.minY + rect.height * 0.07
        let bot = rect.maxY - rect.height * 0.07
        let barH = rect.height * 0.085
        var p = Path()
        p.addRect(CGRect(x: midX - barW/2, y: top, width: barW, height: barH))                     // شريط علويّ
        p.addRect(CGRect(x: midX - bodyW/2, y: top + barH + rect.height*0.05,
                         width: bodyW, height: (bot - barH - rect.height*0.05) - (top + barH + rect.height*0.05))) // الجسم
        p.addRect(CGRect(x: midX - barW/2, y: bot - barH, width: barW, height: barH))               // شريط سفليّ
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
