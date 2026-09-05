import SwiftUI

/// بطاقة آية للمشاركة صورةً: خطّ المصحف، اسم السورة ورقم الآية، وسطر من التفسير اختياريًّا.
struct AyahShareCard: View {
    let ref: AyahRef
    var tafsir: String? = nil
    var scheme: ColorScheme = .light

    private var text: String { Quran.text(ref) ?? "" }
    private var surahName: String { Quran.surah(ref.surah)?.name ?? "" }
    private var paper: Color { scheme == .dark ? Color(hex: 0x14201C) : Color(hex: 0xFBF7EE) }
    private var ink: Color { scheme == .dark ? Color(hex: 0xF2EFE6) : Color(hex: 0x1E2A24) }
    private var soft: Color { scheme == .dark ? Color(hex: 0xB9B3A4) : Color(hex: 0x6D7570) }
    private var accent: Color { Color(hex: scheme == .dark ? 0x7FC9A3 : 0x1F6B4E) }
    private var gold: Color { Color(hex: 0xC9A24A) }

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 10) {
                Circle().stroke(gold, lineWidth: 1.4).frame(width: 10, height: 10)
                Rectangle().fill(gold.opacity(0.6)).frame(height: 1)
                Text("﴿ \(surahName) · \(ref.ayah) ﴾")
                    .font(.custom("NotoNaskhArabic-Medium", size: 20))
                    .foregroundStyle(accent)
                    .fixedSize()
                Rectangle().fill(gold.opacity(0.6)).frame(height: 1)
                Circle().stroke(gold, lineWidth: 1.4).frame(width: 10, height: 10)
            }
            Text(text)
                .font(.custom("NotoNaskhArabic-Regular", size: 40))
                .foregroundStyle(ink)
                .multilineTextAlignment(.center)
                .lineSpacing(18)
                .fixedSize(horizontal: false, vertical: true)
            if let t = tafsir, !t.isEmpty {
                Rectangle().fill(gold.opacity(0.35)).frame(width: 120, height: 1)
                Text(t)
                    .font(.custom("NotoNaskhArabic-Regular", size: 21))
                    .foregroundStyle(soft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Image(systemName: "drop.fill").font(.system(size: 13)).foregroundStyle(accent)
                Text("أثر").font(.custom("NotoNaskhArabic-Bold", size: 18)).foregroundStyle(accent)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 54)
        .padding(.vertical, 60)
        .frame(width: 1080)
        .background(
            ZStack {
                paper
                Circle().stroke(gold.opacity(0.10), lineWidth: 2).frame(width: 900).offset(x: 380, y: 300)
                Circle().stroke(gold.opacity(0.07), lineWidth: 2).frame(width: 1300).offset(x: 380, y: 300)
            }
        )
        .environment(\.layoutDirection, .rightToLeft)
    }

    /// تُصيَّر صورة للمشاركة (٣×).
    @MainActor
    static func render(ref: AyahRef, tafsir: String?, scheme: ColorScheme) -> UIImage? {
        let renderer = ImageRenderer(content: AyahShareCard(ref: ref, tafsir: tafsir, scheme: scheme))
        renderer.scale = 2
        return renderer.uiImage
    }
}
