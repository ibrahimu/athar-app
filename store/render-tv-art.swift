import AppKit
import CoreGraphics

// أصولُ Apple TV — الأيقونةُ الطبقيّة وصورتا الرفّ العلوي.
// شغّله من جذر المستودع:  swift store/render-tv-art.swift
//
// أيقونةُ tvOS ليست صورةً بل ثلاثُ طبقاتٍ تتزحزح تحت إبهام المستخدم (parallax):
// الخلفيّةُ معتمةٌ تملأ الإطار، وما فوقها شفّافٌ حولَ رسمه. والرسمُ هو رسمُ أيقونة
// الجوال نفسه — القطرةُ فوق حلقات أثرها على ورقٍ متدرّج — مقسومًا على الطبقات:
//   الخلفُ:   الورقُ ونجماتٌ محفورة بالكاد تُرى.
//   الوسط:    حلقاتُ الأثر ذهبًا.
//   الأمام:   القطرةُ ووهجُها.
// فإذا مال الإطارُ تحرّكت القطرةُ فوق حلقاتها كأنّها تسقط — وهذا ما يُصنع له العمق.
//
// والألوانُ ألوانُ الطابع الأخضر كما في Shared/AppTheme.swift والأيقونة المنشورة.

let paperTop: UInt32 = 0x1F6B4F     // accent (فاتح)
let paperBottom: UInt32 = 0x0E1512  // canvas الداكن
let gold: UInt32 = 0xD9B45F         // ornament الداكن
let cream: UInt32 = 0xF7EED6        // القطرةُ كما في الأيقونة المنشورة

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

enum Layer { case back, middle, front, all }

/// نجمةٌ ثمانية — الرسمُ نفسه في Components.swift.
func star(center c: CGPoint, radius R: CGFloat, inner: CGFloat = 0.62) -> NSBezierPath {
    let p = NSBezierPath()
    for i in 0..<16 {
        let r = i.isMultiple(of: 2) ? R : R * inner
        let a = (.pi / 8) * CGFloat(i) - .pi / 2
        let pt = CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)
        if i == 0 { p.move(to: pt) } else { p.line(to: pt) }
    }
    p.close()
    return p
}

/// يرسم طبقةً من الأيقونة في إطارٍ عرضُه w وارتفاعُه h. المقياسُ من الارتفاع:
/// أيقونةُ tvOS 400×240 عرضُها أكبر، والرسمُ يُبنى على الارتفاع ليبقى نسبُه.
func render(_ layer: Layer, w: Int, h: Int, motifScale: CGFloat = 1) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let W = CGFloat(w), H = CGFloat(h)
    let k = H / 1024 * motifScale
    let cx = W / 2, cy = H * 0.44

    if layer == .back || layer == .all {
        NSGradient(colors: [color(paperTop), color(paperBottom)])!
            .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -60)
        // نجماتٌ محفورة: «تُحسّ لا تُقرأ» — كما في أرض التطبيق.
        let step = 150 * k
        var y: CGFloat = -step
        var row = 0
        while y < H + step {
            var x: CGFloat = (row.isMultiple(of: 2) ? 0 : step / 2) - step
            while x < W + step {
                color(cream, 0.035).setFill()
                star(center: CGPoint(x: x, y: y), radius: 34 * k).fill()
                x += step
            }
            y += step * 0.87
            row += 1
        }
    }

    if layer == .middle || layer == .all {
        for i in 0..<5 {
            let rx = (152 + CGFloat(i) * 70) * k
            let ry = rx * 0.42
            let ring = NSBezierPath(ovalIn: NSRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
            ring.lineWidth = (12 - CGFloat(i) * 1.7) * k
            color(gold, CGFloat(max(0.18, 0.95 - Double(i) * 0.18))).setStroke()
            ring.stroke()
        }
    }

    if layer == .front || layer == .all {
        // الوهجُ يُقصّ على بيضاويّه: على ورقٍ معتم لا يُرى حدُّ المستطيل، وعلى
        // طبقةٍ شفّافة يظهر مستطيلٌ داكن خلف القطرة.
        let glowR = 190 * k
        let glowRect = NSRect(x: cx - glowR, y: cy - glowR * 0.72, width: glowR * 2, height: glowR * 1.44)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: glowRect).addClip()
        NSGradient(colorsAndLocations: (color(cream, 0.42), 0.0), (color(cream, 0.0), 1.0))!
            .draw(in: glowRect, relativeCenterPosition: .zero)
        NSGraphicsContext.restoreGraphicsState()
        let r = 92 * k
        let center = CGPoint(x: cx, y: cy + 62 * k)
        color(cream).setFill()
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
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// MARK: الكتابة

let root = FileManager.default.currentDirectoryPath
let brand = "\(root)/AtharTV/Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
let fm = FileManager.default

func write(_ data: Data, _ path: String) {
    try! fm.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
    try! data.write(to: URL(fileURLWithPath: path))
    print("wrote", (path as NSString).lastPathComponent)
}

func layerSet(_ stack: String, layer: Layer, name: String, sizes: [(Int, Int, String)]) {
    let dir = "\(brand)/\(stack)/\(name).imagestacklayer/Content.imageset"
    var images: [String] = []
    for (w, h, scale) in sizes {
        let file = "\(name.lowercased())-\(scale).png"
        write(render(layer, w: w, h: h, motifScale: 1.6), "\(dir)/\(file)")
        images.append("""
            { "filename" : "\(file)", "idiom" : "tv", "scale" : "\(scale)" }
        """)
    }
    let contents = "{\n  \"images\" : [\n\(images.joined(separator: ",\n"))\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    try! contents.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
}

// الأيقونة 400×240 — @1x و@2x
for (name, layer) in [("Back", Layer.back), ("Middle", .middle), ("Front", .front)] {
    layerSet("App Icon.imagestack", layer: layer, name: name, sizes: [(400, 240, "1x"), (800, 480, "2x")])
}
// أيقونة المتجر 1280×768 — @1x فقط
for (name, layer) in [("Back", Layer.back), ("Middle", .middle), ("Front", .front)] {
    layerSet("App Icon - App Store.imagestack", layer: layer, name: name, sizes: [(1280, 768, "1x")])
}

// الرفُّ العلوي: الرسمُ كاملًا على يمين الإطار الواسع، ونقشٌ يملأ الباقي.
func shelf(_ set: String, sizes: [(Int, Int, String)]) {
    let dir = "\(brand)/\(set)"
    var images: [String] = []
    for (w, h, scale) in sizes {
        let file = "shelf-\(w)x\(h).png"
        write(render(.all, w: w, h: h, motifScale: 0.9), "\(dir)/\(file)")
        images.append("""
            { "filename" : "\(file)", "idiom" : "tv", "scale" : "\(scale)" }
        """)
    }
    let contents = "{\n  \"images\" : [\n\(images.joined(separator: ",\n"))\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
    try! contents.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
}
shelf("Top Shelf Image.imageset", sizes: [(1920, 720, "1x"), (3840, 1440, "2x")])
shelf("Top Shelf Image Wide.imageset", sizes: [(2320, 720, "1x"), (4640, 1440, "2x")])
print("done")
