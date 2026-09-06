import Foundation
import CoreText
import CoreGraphics
import os

/// تسجيل خط «ثمانية» المرخَّص عند الإقلاع.
/// ترخيصه يجيز التضمين في التطبيقات بشرط ألّا تُعرض ملفاته للاستخراج، فلا تُشحن
/// كـ .otf في UIAppFonts بل مموَّهة (XOR بمفتاح ثابت) في Resources/Fonts/Obf/*.bin،
/// وتُفكّ في الذاكرة وتُسجَّل لعمر العملية فقط عبر CoreText.
enum FontLoader {
    private static let log = Logger(subsystem: "com.ibrahim.athar", category: "fonts")
    private static let key = Array("athar.thmanyah.2026".utf8)
    private static let faces = ["thmanyahsans-Regular", "thmanyahsans-Medium", "thmanyahsans-Bold"]
    private static var registered = false

    /// آمنة للاستدعاء المتكرّر (التطبيق ثم الاختبارات): تسجّل مرة واحدة،
    /// وملفٌ مفقود أو تالف يُسجَّل في السجل ولا يُسقط التطبيق — تسقط الواجهة إلى خط النظام.
    static func registerAll() {
        guard !registered else { return }
        registered = true
        for face in faces {
            guard let url = Bundle.main.url(forResource: face, withExtension: "bin")
                    ?? Bundle.main.url(forResource: face, withExtension: "bin", subdirectory: "Obf") else {
                log.error("font resource missing: \(face, privacy: .public).bin")
                continue
            }
            guard let obfuscated = try? Data(contentsOf: url), !obfuscated.isEmpty else {
                log.error("font resource unreadable: \(face, privacy: .public)")
                continue
            }
            let data = deobfuscate(obfuscated)
            /// نسجّل عبر CGFont لا CTFontManagerRegisterFontsForData: الأخيرة لا تُرى من Swift هنا،
            /// وCGDataProvider يبقي الخط في الذاكرة دون أن يلمس القرص.
            guard let provider = CGDataProvider(data: data as CFData),
                  let cgFont = CGFont(provider) else {
                log.error("font data invalid: \(face, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterGraphicsFont(cgFont, &error) {
                // «مسجَّل من قبل» ليس خطأ فعليًا (يحدث إن سُجّل الخط في العملية بطريق آخر).
                let code = error.map { ($0.takeRetainedValue() as Error as NSError).code } ?? 0
                if code == CTFontManagerError.alreadyRegistered.rawValue { continue }
                log.error("font registration failed: \(face, privacy: .public) code \(code)")
            }
        }
    }

    /// XOR بمفتاح متكرّر: العملية عكس نفسها، فالدالة ذاتها تموّه وتفكّ.
    static func deobfuscate(_ input: Data) -> Data {
        var out = Data(count: input.count)
        let n = key.count
        input.withUnsafeBytes { (src: UnsafeRawBufferPointer) in
            out.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) in
                for i in 0..<input.count {
                    dst[i] = src[i] ^ key[i % n]
                }
            }
        }
        return out
    }
}
