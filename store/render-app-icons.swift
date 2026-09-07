import AppKit
import CoreGraphics

// أيقونات أثر البديلة — الرسم نفسه بألوان الطوابع.
// شغّله من جذر المستودع:  swift store/render-app-icons.swift
//
// الأيقونة قطرةٌ فوق حلقات أثرها على ورقٍ متدرّج. لا تُلوَّن الأصلُ تلوينًا آليًّا
// (الحلقات ذهبٌ لا يتبع اللون، والقطرة كريميّة على كل خلفية)، بل يُعاد الرسم بالمعادلة
// نفسها لكل طابع — فيبقى الشكل واحدًا ويتبدّل الورق وحده.

struct IconSpec {
    let name: String       // اسم مجموعة الأصول: AppIcon أو AppIcon-<الطابع>
    let title: String      // الاسم العربي في المنتقي
    let top: UInt32        // أعلى التدرّج
    let bottom: UInt32     // أسفله
    let ring: UInt32       // لون الحلقات
    let drop: UInt32       // لون القطرة
}

// الطوابع كما في Shared/AppTheme.swift — لونا التدرّج من accent2/accent الداكنَين، وحلقةٌ من زخرفه.
// الأخضر ليس هنا: أيقونة المتجر المنشورة تبقى ملفَّها هي، لا رسمًا يُعاد فيختلف بشعرة.
let specs: [IconSpec] = [
    .init(name: "AppIcon-night",    title: "ليلي",    top: 0x27324F, bottom: 0x0B1220, ring: 0x8FB4E8, drop: 0xF2F5FB),
    .init(name: "AppIcon-sand",     title: "رملي",    top: 0x8A5D28, bottom: 0x3A2611, ring: 0xE3C489, drop: 0xFBF3E4),
    .init(name: "AppIcon-sea",      title: "بحري",    top: 0x1E6E80, bottom: 0x0A2C35, ring: 0x7FD0E0, drop: 0xEFF9FB),
    .init(name: "AppIcon-rose",     title: "وردي",    top: 0x8C3554, bottom: 0x3A1223, ring: 0xE9A8BE, drop: 0xFDF0F4),
    .init(name: "AppIcon-indigo",   title: "نيلي",    top: 0x3B4A86, bottom: 0x151B38, ring: 0xA9B6EA, drop: 0xF1F3FD),
    .init(name: "AppIcon-charcoal", title: "فحمي",    top: 0x3A423F, bottom: 0x141817, ring: 0xB6C2BD, drop: 0xF3F5F4),
    .init(name: "AppIcon-plum",     title: "برقوقي",  top: 0x5A2A63, bottom: 0x220E27, ring: 0xD2A6E0, drop: 0xF8F0FB),
    .init(name: "AppIcon-olive",    title: "زيتوني",  top: 0x5A6B22, bottom: 0x22290B, ring: 0xCBD98A, drop: 0xF6F9E8),
    .init(name: "AppIcon-mint",     title: "نعناعي",  top: 0x18795F, bottom: 0x073028, ring: 0x86E0C0, drop: 0xEDFBF5),
    .init(name: "AppIcon-honey",    title: "عسلي",    top: 0xA5701A, bottom: 0x412A07, ring: 0xF0CE82, drop: 0xFDF5E4),
    .init(name: "AppIcon-violet",   title: "بنفسجي",  top: 0x51418F, bottom: 0x1D1738, ring: 0xB9A7E0, drop: 0xF4F1FC),
]

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func render(_ s: IconSpec, size: CGFloat = 1024) -> Data {
    // تمثيلٌ نقطيّ بقياسٍ صريح: NSImage وحده يرسم بمقياس الشاشة فتخرج ٢٠٤٨ على ريتينا،
    // وأيقونة المتجر لا تُقبل إلا ١٠٢٤ بالضبط.
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                               pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let k = size / 1024   // كل الأرقام أدناه بمقياس ١٠٢٤

    // الورق: تدرّج قُطريّ من أعلى اليمين — كالأصل.
    NSGradient(colors: [color(s.top), color(s.bottom)])!
        .draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -60)

    // مركز السقوط: الإحداثيات هنا غير مقلوبة، فالأسفل صفر.
    let cx = size / 2, cy = 455 * k

    // حلقات الأثر: قطوعٌ ناقصة متمددة، تخفت كلّما اتّسعت — كالأصل.
    for i in 0..<5 {
        let rx = (152 + CGFloat(i) * 70) * k
        let ry = rx * 0.42
        let ring = NSBezierPath(ovalIn: NSRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        ring.lineWidth = (12 - CGFloat(i) * 1.7) * k
        color(s.ring, CGFloat(max(0.18, 0.95 - Double(i) * 0.18))).setStroke()
        ring.stroke()
    }

    // وهجٌ حيث تلامس القطرةُ الماء — يفصلها عن الحلقات بلا حدٍّ مرسوم.
    let glowR = 190 * k
    NSGradient(colorsAndLocations: (color(s.drop, 0.42), 0.0), (color(s.drop, 0.0), 1.0))!
        .draw(in: NSRect(x: cx - glowR, y: cy - glowR * 0.72, width: glowR * 2, height: glowR * 1.44),
              relativeCenterPosition: .zero)

    // القطرة: كرةٌ ورأسٌ فوقها — يُملآن باللون نفسه فيتّحدان بلا خطّ بينهما.
    let r = 92 * k
    let center = CGPoint(x: cx, y: cy + 62 * k)
    color(s.drop).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)).fill()
    let tip = NSBezierPath()
    let apex = CGPoint(x: center.x, y: center.y + r * 2.30)
    tip.move(to: CGPoint(x: center.x - r * 0.999, y: center.y))
    tip.curve(to: apex,
              controlPoint1: CGPoint(x: center.x - r * 0.96, y: center.y + r * 0.92),
              controlPoint2: CGPoint(x: center.x - r * 0.34, y: center.y + r * 1.62))
    tip.curve(to: CGPoint(x: center.x + r * 0.999, y: center.y),
              controlPoint1: CGPoint(x: center.x + r * 0.34, y: center.y + r * 1.62),
              controlPoint2: CGPoint(x: center.x + r * 0.96, y: center.y + r * 0.92))
    tip.close()
    tip.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: الكتابة في مجلد الأصول

let root = FileManager.default.currentDirectoryPath
let assets = "\(root)/Athar/Resources/Assets.xcassets"
let fm = FileManager.default

for s in specs {
    let dir = "\(assets)/\(s.name).appiconset"
    try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let file = "\(s.name)-1024.png"
    try! render(s).write(to: URL(fileURLWithPath: "\(dir)/\(file)"))
    let contents = """
    {
      "images" : [
        {
          "filename" : "\(file)",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try! contents.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
    print("wrote \(s.name)")
}
print("done: \(specs.count) icons")
