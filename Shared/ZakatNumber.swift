import Foundation

/// أرقام الزكاة: تحليل ما يكتبه المستخدم (أرقام هندية، فواصل عربية، فواصل آلاف) وصياغته.
enum ZakatNumber {
    /// يقبل الأرقام العربية الهندية والفاصلة العشرية العربية «٫» لأن لوحة المفاتيح
    /// قد تُخرجها حسب لغة الجهاز، فلا يُهمل ما كتبه المستخدم.
    static func parse(_ s: String) -> Double {
        var digits = ""
        var separators: [Int] = []          // مواضع الفواصل داخل digits
        var commaOnly = true
        for ch in s {
            if ch.isNumber, let v = ch.wholeNumberValue {
                digits.append(String(v))
            } else if ch == "." || ch == "٫" || ch == "," {
                separators.append(digits.count)
                if ch != "," { commaOnly = false }
            }
        }
        guard !digits.isEmpty else { return 0 }
        // «١٬٢٣٤٬٥٦٧» كان يُقرأ صفرًا لأن كل فاصلة صارت نقطة عشرية. القاعدة:
        // الفاصلة الأخيرة وحدها عشرية، وما قبلها فواصل آلاف تُهمَل؛ وفاصلةٌ منفردة
        // تتبعها ثلاثة أرقام بالضبط «١٬٢٣٤» فاصلةُ آلاف كما هو المألوف عربيًّا.
        var decimalAt: Int? = separators.last
        if separators.count == 1, commaOnly, digits.count - separators[0] == 3 { decimalAt = nil }
        if separators.count >= 2 {
            // كلّها فواصل آلاف حين تفصل مجموعاتٍ من ثلاثة أرقام إلى آخر الرقم.
            let gaps = zip(separators.dropFirst(), separators).map { $0 - $1 }
            if gaps.allSatisfy({ $0 == 3 }), digits.count - (separators.last ?? 0) == 3 { decimalAt = nil }
        }
        let text: String
        if let at = decimalAt, at > 0, at < digits.count {
            let i = digits.index(digits.startIndex, offsetBy: at)
            text = String(digits[..<i]) + "." + String(digits[i...])
        } else {
            text = digits
        }
        return max(0, Double(text) ?? 0)
    }

    static func string(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "0"
    }

    /// صيغة للحقل نفسه: بلا تجميع حتى تُقرأ بالتفسير أعلاه كما كُتبت.
    static func editable(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? ""
    }
}
