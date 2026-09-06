import AppKit
import CoreText

// swiftc render.swift -o renderer; renderer <project-root> <jobs.json>
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let jobs = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]))) as! [[String: String]]
for face in ["Regular", "Medium", "Bold"] {
    CTFontManagerRegisterFontsForURL(root.appendingPathComponent("Athar/Resources/Fonts/NotoNaskhArabic-\(face).ttf") as CFURL, .process, nil)
}
let ink = NSColor(srgbRed: 20/255, green: 54/255, blue: 44/255, alpha: 1)
let gold = NSColor(srgbRed: 166/255, green: 124/255, blue: 48/255, alpha: 1)
let paper = NSColor(srgbRed: 247/255, green: 242/255, blue: 231/255, alpha: 1)
func attributed(_ text: String, size: CGFloat, color: NSColor, bold: Bool = false) -> NSAttributedString {
    let style = NSMutableParagraphStyle()
    style.alignment = .center; style.baseWritingDirection = .rightToLeft
    style.lineSpacing = 2
    return NSAttributedString(string: text, attributes: [.font: NSFont(name: "NotoNaskhArabic-\(bold ? "Bold" : "Regular")", size: size)!, .foregroundColor: color, .paragraphStyle: style])
}
for job in jobs {
    let text = job["text"]!, title = job["title"]!, out = URL(fileURLWithPath: job["out"]!)
    var fontSize: CGFloat = 26
    var content = attributed(text, size: fontSize, color: ink)
    func height(_ value: NSAttributedString) -> CGFloat {
        value.boundingRect(with: NSSize(width: 327, height: 1000), options: [.usesLineFragmentOrigin, .usesFontLeading]).height
    }
    while fontSize > 17 && height(content) > 100 {
        fontSize -= 0.5; content = attributed(text, size: fontSize, color: ink)
    }
    let titleOnly = height(content) > 100
    if titleOnly { content = attributed(title, size: 28, color: ink, bold: true) }
    for scale in 1...3 {
        let w = 375 * scale, h = 144 * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let cg = NSGraphicsContext.current!.cgContext
        cg.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
        cg.translateBy(x: 0, y: 144); cg.scaleBy(x: 1, y: -1)
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
        paper.setFill(); NSRect(x: 0, y: 0, width: 375, height: 144).fill()
        // إطار هادئ بلون الهوية، مع مساحة بيضاء تحمي التشكيل من الزخرفة.
        gold.withAlphaComponent(0.45).setStroke()
        for y: CGFloat in [8, 136] {
            let line = NSBezierPath(); line.lineWidth = 0.5
            line.move(to: NSPoint(x: 24, y: y)); line.line(to: NSPoint(x: 177, y: y))
            line.move(to: NSPoint(x: 198, y: y)); line.line(to: NSPoint(x: 351, y: y)); line.stroke()
            let star = NSBezierPath()
            for i in 0..<16 {
                let angle = CGFloat(i) * .pi / 8
                let radius: CGFloat = i % 2 == 0 ? 4 : 2.5
                let point = NSPoint(x: 187.5 + cos(angle) * radius, y: y + sin(angle) * radius)
                if i == 0 { star.move(to: point) } else { star.line(to: point) }
            }
            star.close(); gold.setFill(); star.fill()
        }
        let contentHeight = height(content)
        content.draw(with: NSRect(x: 24, y: (144 - contentHeight) / 2 - (titleOnly ? 12 : 0), width: 327, height: contentHeight + 2), options: [.usesLineFragmentOrigin, .usesFontLeading])
        if titleOnly {
            attributed("النص كامل في تفاصيل البطاقة", size: 12, color: gold)
                .draw(in: NSRect(x: 24, y: 100, width: 327, height: 25))
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 1 ? "" : "@\(scale)x"
        try rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("strip\(suffix).png"))
    }
}
