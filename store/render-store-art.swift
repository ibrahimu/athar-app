import SwiftUI
import AppKit
import CoreText

// صور المتجر: خلفية متدرّجة بلون القسم، عنوان ووصف بخط النسخ، الهاتف في إطار مستدير، ورقاقات مزايا.
let root = FileManager.default.currentDirectoryPath   // شغّله من جذر المستودع: swift store/render-store-art.swift
let shots = "\(root)/store_final/1.2"
let out = "\(shots)/art"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for f in ["NotoNaskhArabic-Bold", "NotoNaskhArabic-Regular", "NotoNaskhArabic-Medium"] {
    let url = URL(fileURLWithPath: "\(root)/Athar/Resources/Fonts/\(f).ttf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
}

struct Spec { let file: String; let shot: String; let title: String; let subtitle: String; let chips: [String]; let c1: Color; let c2: Color; let watch: Bool }

let specs: [Spec] = [
    .init(file: "01", shot: "02-tafsir.png", title: "المصحف كاملًا… والتفسير بضغطة",
          subtitle: "تفسير السعدي والجلالين لكل آية، بلا إنترنت", chips: ["ثلاثة أشكال للمصحف", "تلاوة آية بآية", "ختمة وورد يومي"],
          c1: Color(red: 0.06, green: 0.32, blue: 0.26), c2: Color(red: 0.10, green: 0.45, blue: 0.36), watch: false),
    .init(file: "02", shot: "03-hadith.png", title: "رياض الصالحين والأربعون النووية",
          subtitle: "بعزو الإمام النووي، وحديث اليوم، وشرح ابن دقيق العيد", chips: ["1938 حديثًا", "بحث وحفظ", "تذكير يومي"],
          c1: Color(red: 0.09, green: 0.30, blue: 0.40), c2: Color(red: 0.12, green: 0.40, blue: 0.52), watch: false),
    .init(file: "03", shot: "08-name-detail.png", title: "أسماء الله الحسنى بشرح السعدي",
          subtitle: "التسعة والتسعون، لكل اسم معناه ودليله", chips: ["اسم اليوم", "من كلام الشيخ السعدي", "ودجت"],
          c1: Color(red: 0.26, green: 0.22, blue: 0.48), c2: Color(red: 0.36, green: 0.32, blue: 0.60), watch: false),
    .init(file: "04", shot: "05c-ahkam-item.png", title: "الأحكام العملية بدليلها",
          subtitle: "الطهارة والصلاة والصيام والحج والمرأة والأيمان — خطوةً خطوة", chips: ["الدليل من الكتاب والصحيحين", "روابط فتاوى ابن باز", "8 أبواب"],
          c1: Color(red: 0.10, green: 0.36, blue: 0.30), c2: Color(red: 0.16, green: 0.48, blue: 0.40), watch: false),
    .init(file: "05", shot: "06-sunan.png", title: "يومك مع الرواتب",
          subtitle: "ما قبل كل فريضة وما بعدها، والوتر والضحى — بأدلّتها", chips: ["12 ركعة", "تنبيه قبل الأذان والإقامة", "أصوات أذان بأسمائها"],
          c1: Color(red: 0.62, green: 0.40, blue: 0.16), c2: Color(red: 0.78, green: 0.52, blue: 0.22), watch: false),
    .init(file: "06", shot: "11-calendar.png", title: "التقويم الهجري ومناسبات السنّة",
          subtitle: "الأيام البيض، عاشوراء، عرفة، رمضان — بلا بدع", chips: ["حاسبة الزكاة", "سجل الصلاة والفوائت", "مدينة ثانية للمسافر"],
          c1: Color(red: 0.60, green: 0.42, blue: 0.12), c2: Color(red: 0.75, green: 0.56, blue: 0.20), watch: false),
    .init(file: "07", shot: "09-sections.png", title: "رتّبه على كيفك",
          subtitle: "أي قسم يصلح تبويبًا في الشريط، وبطاقات «اليوم» بيدك", chips: ["18 قسمًا", "12 طابعًا لونيًّا", "بلا حسابات ولا إعلانات"],
          c1: Color(red: 0.16, green: 0.20, blue: 0.36), c2: Color(red: 0.24, green: 0.30, blue: 0.50), watch: false),
    .init(file: "08", shot: "13-watch-prayer.png", title: "على معصمك أيضًا",
          subtitle: "الصلاة القادمة بحلقة وعدّ تنازلي، ومسبحة بنبضة، ومضاعفة على واجهة الساعة", chips: ["Apple Watch", "Dynamic Island", "اختصارات Siri"],
          c1: Color(red: 0.05, green: 0.25, blue: 0.20), c2: Color(red: 0.10, green: 0.42, blue: 0.33), watch: true),
]

let W: CGFloat = 1290, H: CGFloat = 2796

struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.custom("NotoNaskhArabic-Medium", size: 34))
            .foregroundStyle(.white)
            .padding(.horizontal, 30).padding(.vertical, 14)
            .background(Capsule().fill(.white.opacity(0.16)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 2))
    }
}

struct Page: View {
    let s: Spec
    var body: some View {
        let img = NSImage(contentsOfFile: "\(shots)/\(s.shot)")
        ZStack(alignment: .top) {
            LinearGradient(colors: [s.c1, s.c2], startPoint: .topLeading, endPoint: .bottomTrailing)
            // دوائر أثر القطرة — الهوية البصرية
            Circle().stroke(.white.opacity(0.08), lineWidth: 3).frame(width: 1500).offset(x: 500, y: 1900)
            Circle().stroke(.white.opacity(0.06), lineWidth: 3).frame(width: 2100).offset(x: 500, y: 1900)
            Circle().fill(.white.opacity(0.06)).frame(width: 900).offset(x: -700, y: -200).blur(radius: 60)

            VStack(spacing: 26) {
                Text(s.title)
                    .font(.custom("NotoNaskhArabic-Bold", size: 80))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 90)
                Text(s.subtitle)
                    .font(.custom("NotoNaskhArabic-Regular", size: 42))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 120)
                HStack(spacing: 18) { ForEach(s.chips, id: \.self) { Chip(text: $0) } }
                    .padding(.top, 6)

                if let img {
                    if s.watch {
                        // إطار الساعة: مستطيل بزوايا كبيرة جدًّا + تاج
                        ZStack(alignment: .trailing) {
                            RoundedRectangle(cornerRadius: 210, style: .continuous)
                                .fill(Color.black)
                                .frame(width: 1010, height: 1200)
                                .shadow(color: .black.opacity(0.45), radius: 60, y: 30)
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 900, height: 1080)
                                .clipShape(RoundedRectangle(cornerRadius: 170, style: .continuous))
                                .padding(.trailing, 55)
                            Capsule().fill(Color(white: 0.2)).frame(width: 34, height: 160).offset(x: 40, y: -180)
                        }
                        .padding(.top, 60)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 132, style: .continuous)
                                .fill(Color.black)
                                .frame(width: 880, height: 1870)
                                .shadow(color: .black.opacity(0.45), radius: 60, y: 30)
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                                .frame(width: 836, height: 1818)
                                .clipShape(RoundedRectangle(cornerRadius: 116, style: .continuous))
                        }
                        .padding(.top, 30)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 110)
        }
        .frame(width: W, height: H)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

MainActor.assumeIsolated {
    for s in specs {
        let renderer = ImageRenderer(content: Page(s: s))
        renderer.scale = 1
        guard let cg = renderer.cgImage else { print("render failed", s.file); continue }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { continue }
        let path = "\(out)/\(s.file).png"
        try? data.write(to: URL(fileURLWithPath: path))
        print("wrote", path, cg.width, "x", cg.height)
    }
}
