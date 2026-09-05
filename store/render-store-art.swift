import SwiftUI
import AppKit
import CoreText

// صور المتجر — شغّله من جذر المستودع: swift store/render-store-art.swift
// كل صورة: عنوان كبير، وصف، شبكة مزايا بأيقونات، وهاتفٌ أو هاتفان في إطار. تُقرأ اللقطات من store_final/1.2.
let root = FileManager.default.currentDirectoryPath
let shots = "\(root)/store_final/1.2"
let out = "\(shots)/art"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
for f in ["NotoNaskhArabic-Bold", "NotoNaskhArabic-Regular", "NotoNaskhArabic-Medium"] {
    CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: "\(root)/Athar/Resources/Fonts/\(f).ttf") as CFURL, .process, nil)
}

struct Feature { let icon: String; let text: String }
struct Spec {
    let file: String; let shots: [String]; let title: String; let subtitle: String
    let features: [Feature]; let c1: Color; let c2: Color; var watch = false
}

let specs: [Spec] = [
    .init(file: "01", shots: ["02-tafsir.png", "01-home.png"], title: "أثر — يومك كله في مكان واحد",
          subtitle: "مصحف وتفسير وأذكار ومواقيت وحديث وأحكام… بلا إعلانات ولا حسابات ولا إنترنت",
          features: [.init(icon: "book.closed.fill", text: "المصحف كاملًا بالرسم العثماني"), .init(icon: "text.book.closed.fill", text: "تفسير السعدي والجلالين لكل آية"),
                     .init(icon: "moon.stars.fill", text: "مواقيت دقيقة وأذان بأصوات بأسمائها"), .init(icon: "sparkles", text: "أسماء الله الحسنى بشرح السعدي")],
          c1: Color(red: 0.06, green: 0.32, blue: 0.26), c2: Color(red: 0.10, green: 0.46, blue: 0.37)),
    .init(file: "02", shots: ["02-tafsir.png"], title: "التفسير بضغطة على الآية",
          subtitle: "السعدي للمعنى، والجلالين للبيان الموجز، وسبب النزول وفضل السورة",
          features: [.init(icon: "waveform.and.mic", text: "تلاوة آية بآية مع تظليل الموضع"), .init(icon: "repeat", text: "تكرار الآية للحفظ ٣/٥/١٠"),
                     .init(icon: "eye.slash", text: "وضع الحفظ: إخفاء الكلمات"), .init(icon: "photo.on.rectangle.angled", text: "مشاركة الآية بطاقةً بخط المصحف")],
          c1: Color(red: 0.08, green: 0.28, blue: 0.24), c2: Color(red: 0.13, green: 0.42, blue: 0.34)),
    .init(file: "03", shots: ["03-hadith.png", "08-name-detail.png"], title: "حديثٌ واسمٌ كل يوم",
          subtitle: "رياض الصالحين والأربعون النووية بعزو النووي، والأسماء الحسنى بشرح السعدي",
          features: [.init(icon: "quote.opening", text: "1938 حديثًا وبحث وحفظ"), .init(icon: "text.book.closed.fill", text: "شرح الأربعين لابن دقيق العيد"),
                     .init(icon: "bell.fill", text: "تذكير يومي بالحديث"), .init(icon: "square.grid.2x2", text: "ودجات حديث اليوم واسم اليوم")],
          c1: Color(red: 0.10, green: 0.30, blue: 0.42), c2: Color(red: 0.16, green: 0.42, blue: 0.55)),
    .init(file: "04", shots: ["05c-ahkam-item.png", "05-ahkam.png"], title: "الأحكام العملية بدليلها",
          subtitle: "ثمانية أبواب: الطهارة، الصلاة، الجنازة، الاستخارة، الصيام، الحج، أحكام المرأة، الأيمان",
          features: [.init(icon: "checkmark.seal.fill", text: "الدليل من الكتاب والصحيحين بلفظه"), .init(icon: "link", text: "رابط فتوى الشيخ ابن باز لكل مسألة"),
                     .init(icon: "list.bullet.clipboard.fill", text: "76 مسألة خطوةً خطوة"), .init(icon: "hand.raised.fill", text: "من مصادر أهل السنّة فقط")],
          c1: Color(red: 0.10, green: 0.36, blue: 0.30), c2: Color(red: 0.16, green: 0.50, blue: 0.40)),
    .init(file: "05", shots: ["06-sunan.png", "12-prayer-log.png"], title: "صلاتك: رواتب وسجل وتنبيهات",
          subtitle: "يومك مع الرواتب على خط زمني، وسجل صلواتك وفوائتك، وتنبيه قبل الأذان والإقامة",
          features: [.init(icon: "rays", text: "12 ركعة راتبة بدليلها"), .init(icon: "checkmark.circle.fill", text: "سجل الصلاة وقضاء الفوائت"),
                     .init(icon: "alarm.fill", text: "تنبيه قبل الأذان وتنبيه الإقامة"), .init(icon: "plusminus.circle.fill", text: "ضبط المواقيت بالدقائق لمسجدك")],
          c1: Color(red: 0.62, green: 0.40, blue: 0.16), c2: Color(red: 0.80, green: 0.54, blue: 0.22)),
    .init(file: "06", shots: ["11-calendar.png", "10-zakat.png"], title: "التقويم والزكاة والمناسبات",
          subtitle: "تقويم أم القرى بمناسبات السنّة الثابتة، وحاسبة زكاة بسعر تدخله بنفسك",
          features: [.init(icon: "calendar", text: "الأيام البيض وعاشوراء وعرفة ورمضان"), .init(icon: "banknote.fill", text: "النصاب بالذهب أو الفضة"),
                     .init(icon: "chart.bar.xaxis", text: "إحصاء شهري لأذكارك وصفحاتك"), .init(icon: "globe.asia.australia.fill", text: "مدينة ثانية للمسافر")],
          c1: Color(red: 0.58, green: 0.40, blue: 0.12), c2: Color(red: 0.76, green: 0.56, blue: 0.20)),
    .init(file: "07", shots: ["09-sections.png", "00-whatsnew.png"], title: "رتّبه على كيفك",
          subtitle: "18 قسمًا في أربع عائلات: أي قسم يصلح تبويبًا في الشريط، وبطاقات «اليوم» بيدك",
          features: [.init(icon: "square.grid.2x2.fill", text: "18 قسمًا و12 طابعًا لونيًّا"), .init(icon: "rectangle.stack.fill", text: "بطاقات اليوم تُرتَّب وتُخفى"),
                     .init(icon: "person.3.fill", text: "ختمة جماعية برمز للعائلة"), .init(icon: "icloud.fill", text: "مزامنة اختيارية للتفضيلات")],
          c1: Color(red: 0.16, green: 0.20, blue: 0.36), c2: Color(red: 0.26, green: 0.32, blue: 0.52)),
    .init(file: "08", shots: ["13-watch-prayer.png"], title: "على معصمك أيضًا",
          subtitle: "الصلاة القادمة بحلقة وعدّ تنازلي، ومسبحة بنبضة، ومضاعفة على واجهة الساعة",
          features: [.init(icon: "applewatch", text: "Apple Watch تتزامن مع الهاتف"), .init(icon: "timer", text: "Dynamic Island للصلاة القادمة"),
                     .init(icon: "mic.fill", text: "اختصارات Siri: «كم باقي للصلاة»"), .init(icon: "car.fill", text: "التلاوة في CarPlay")],
          c1: Color(red: 0.05, green: 0.25, blue: 0.20), c2: Color(red: 0.10, green: 0.42, blue: 0.33), watch: true),
]

let W: CGFloat = 1290, H: CGFloat = 2796

struct FeatureRow: View {
    let f: Feature
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: f.icon).font(.system(size: 28, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 58, height: 58).background(Circle().fill(.white.opacity(0.16)))
            Text(f.text).font(.custom("NotoNaskhArabic-Medium", size: 27)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct Phone: View {
    let img: NSImage; let width: CGFloat
    var body: some View {
        let h = width * 874 / 402
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.155, style: .continuous).fill(Color.black)
                .frame(width: width + 42, height: h + 42)
                .shadow(color: .black.opacity(0.45), radius: 50, y: 26)
            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                .frame(width: width, height: h)
                .clipShape(RoundedRectangle(cornerRadius: width * 0.135, style: .continuous))
        }
    }
}

struct Page: View {
    let s: Spec
    var body: some View {
        let imgs = s.shots.compactMap { NSImage(contentsOfFile: "\(shots)/\($0)") }
        ZStack(alignment: .top) {
            LinearGradient(colors: [s.c1, s.c2], startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().stroke(.white.opacity(0.08), lineWidth: 3).frame(width: 1500).offset(x: 520, y: 1950)
            Circle().stroke(.white.opacity(0.06), lineWidth: 3).frame(width: 2100).offset(x: 520, y: 1950)
            Circle().fill(.white.opacity(0.07)).frame(width: 900).offset(x: -700, y: -250).blur(radius: 70)

            VStack(spacing: 22) {
                Text(s.title).font(.custom("NotoNaskhArabic-Bold", size: 78)).foregroundStyle(.white)
                    .multilineTextAlignment(.center).lineSpacing(4).padding(.horizontal, 70)
                Text(s.subtitle).font(.custom("NotoNaskhArabic-Regular", size: 38)).foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center).padding(.horizontal, 100).lineSpacing(4)
                // شبكة المزايا: عمودان بعرض ثابت — الشبكة المرنة في RTL كانت تدفع العمود الأيمن خارج الصورة.
                let cols = [GridItem(.fixed(560), spacing: 30, alignment: .leading), GridItem(.fixed(560), spacing: 30, alignment: .leading)]
                LazyVGrid(columns: cols, alignment: .center, spacing: 20) {
                    ForEach(0..<s.features.count, id: \.self) { FeatureRow(f: s.features[$0]) }
                }
                .frame(width: 1150)
                .padding(.top, 10)

                if s.watch, let img = imgs.first {
                    ZStack(alignment: .trailing) {
                        RoundedRectangle(cornerRadius: 200, style: .continuous).fill(Color.black).frame(width: 960, height: 1140)
                            .shadow(color: .black.opacity(0.45), radius: 60, y: 30)
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill).frame(width: 860, height: 1030)
                            .clipShape(RoundedRectangle(cornerRadius: 165, style: .continuous)).padding(.trailing, 50)
                        Capsule().fill(Color(white: 0.2)).frame(width: 34, height: 160).offset(x: 40, y: -170)
                    }
                    .padding(.top, 40)
                } else if imgs.count >= 2 {
                    // هاتفان: الأمامي كبير يمينًا والخلفي أصغر يسارًا، يملآن أسفل الصورة.
                    ZStack(alignment: .bottom) {
                        Phone(img: imgs[1], width: 600).offset(x: -300, y: -150).opacity(0.94)
                        Phone(img: imgs[0], width: 740).offset(x: 180, y: 0)
                    }
                    .frame(width: W, height: 1760, alignment: .bottom)
                    .padding(.top, 70)
                } else if let img = imgs.first {
                    Phone(img: img, width: 800).padding(.top, 70)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 90)
        }
        .frame(width: W, height: H)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

MainActor.assumeIsolated {
    for s in specs {
        let r = ImageRenderer(content: Page(s: s)); r.scale = 1
        guard let cg = r.cgImage, let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { print("render failed", s.file); continue }
        try? data.write(to: URL(fileURLWithPath: "\(out)/\(s.file).png"))
        print("wrote \(s.file).png")
    }
}
