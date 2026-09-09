import Foundation

/// مفتاح البحث الموحّد في التطبيق كلّه.
///
/// كان لكلّ شاشةٍ تطبيعُها: `strippedForSearch` للمصحف، و`hadithSearchKey` للحديث،
/// و`matchKey` للبحث العام، و`normalizedArabic` للأذكار — أربعةٌ تتفق في أكثرها
/// وتفترق في مواضع، فيجد الباحثُ كلمته في شاشةٍ ولا يجدها في أخرى.
///
/// وأهمّها المسافة: النصّ «الْحَمْدُ لِلَّهِ» فيه مسافة، ومن كتبها متّصلةً «الحمدلله»
/// — وهكذا تُكتب في الكلام — لم يجد شيئًا. فالمفتاح يُسقط المسافات وعلاماتِ الترقيم
/// جميعًا: يبقى الحرفُ والرقمُ وحدهما. فيستوي «الحمد لله» و«الحمدلله» و«الحمد للّه».
///
/// وثمنُه أنّ المطابقة قد تعبر حدَّ الكلمة (يجد «ربالعالمين» في «ربّ العالمين») —
/// وهذا في البحث مقبولٌ بل مطلوب، لا يُقاس على التسميع الذي يزن الكلمات وزنًا
/// (انظر `ArabicMatch.normalize`، ولا يُبنى عليه هذا ولا يُبنى عليه).
enum ArabicSearch {

    static func key(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        out.reserveCapacity(s.unicodeScalars.count)
        // نحن داخل رقم آية: «۝٢» رمزٌ ثمّ رقمُه. الرمزُ يُسقط، ولو بقي رقمُه لالتصق
        // بين الكلمتين — «قل هو الله أحد ۝١ الله الصمد» يصير «…احد1الله…» — فلا يجد
        // من كتب الآيتين متتابعتين كما يقرأهما على الشاشة.
        var inAyahNumber = false
        for u in s.unicodeScalars {
            if inAyahNumber {
                if (0x0660...0x0669).contains(u.value) || (0x06F0...0x06F9).contains(u.value) { continue }
                inAyahNumber = false
            }
            switch u.value {
            case 0x06DD: inAyahNumber = true; continue   // ۝ علامة نهاية الآية
            // تشكيل، وعلامات وقفٍ وضبطٍ للمصحف، وتطويل — تُسقط جميعًا.
            case 0x0610...0x061A, 0x064B...0x065F, 0x06D6...0x06ED,
                 0x0640, 0x08D3...0x08FF:
                continue
            // الألف الخنجرية: تُقرأ ألفًا، ورسمُها في المصحف على ثلاثة أوجه —
            //   «ٱلصَّلَوٰةَ» واوٌ تحتها، وإملاؤها «الصلاة»: فتحلّ الألفُ محلّ الواو.
            //   «عَلَىٰ» ألفٌ مقصورة تحتها، وإملاؤها «على»: فتُسقط ويبقى ما قبلها.
            //   «ٱلْعَٰلَمِينَ» حرفٌ صحيح تحتها، وإملاؤها «العالمين»: فتُزاد ألفًا.
            // وبلا هذا لم يجد من كتب «الصلاة» ولا «على» ولا «العالمين» شيئًا.
            case 0x0670:
                switch out.last {
                case "و": out.removeLast(); out.append("ا")
                case "ي": break
                default:  out.append("ا")
                }
            // صور الألف والهمزة تُردّ إلى ألف: «إسراء» و«اسراء» سواء.
            case 0x0622, 0x0623, 0x0625, 0x0671:
                out.append("ا")
            case 0x0629: out.append("ه")   // التاء المربوطة هاءً: «رحمة» و«رحمه»
            case 0x0649: out.append("ي")   // الألف المقصورة ياءً: «ذكرى» و«ذكري»
            case 0x0624: out.append("و")
            case 0x0626: out.append("ي")
            case 0x0621: continue          // همزةٌ مفردة تُسقط
            // الأرقام الهندية والفارسية تُردّ إلى الغربية: من كتب «٥٥» بلوحته العربية.
            case 0x0660...0x0669: out.append(Unicode.Scalar(u.value - 0x0660 + 48)!)
            case 0x06F0...0x06F9: out.append(Unicode.Scalar(u.value - 0x06F0 + 48)!)
            default:
                let c = Character(u)
                if c.isLetter {
                    // اللاتيني يُخفض ليجد «Al-Fatihah» من كتب «fatiha».
                    for l in String(c).lowercased().unicodeScalars { out.append(l) }
                } else if c.isNumber, c.isASCII {
                    out.append(u)
                }
                // وما سواه — مسافةً كان أو قوسًا أو نقطة — يُسقط.
            }
        }
        return String(out)
    }

    /// مفتاحٌ متساهل: كالمفتاح وقد أُسقطت منه الألفات جميعًا.
    ///
    /// لأنّ ردّ الألف الخنجرية ألفًا يصلح موضعًا ويفسد آخر: «ٱلْعَٰلَمِينَ» تصير
    /// «العالمين» فيجدها من كتبها كذلك، لكنّ «ٱلرَّحْمَٰنِ» تصير «الرحمان» فلا يجدها
    /// من كتب «الرحمن» — وهي الأشيع. فلا يستقيم أحدُهما وحده.
    ///
    /// فالبحث مرّتان: بالمفتاح أوّلًا فيصيب ما يصيب بدقّة، فإن لم يجد شيئًا أُعيد
    /// بهذا فتستوي الألفُ حيثما وقعت. والتساهل لا يُلجأ إليه إلا عند خيبة الدقّة،
    /// فلا يُدخل ضجيجَه على بحثٍ صحيح.
    static func loose(_ s: String) -> String {
        key(s).replacingOccurrences(of: "ا", with: "")
    }

    /// هل يقع `needle` في `text`؟ بالدقّة أوّلًا ثم بالتساهل.
    static func matches(_ text: String, _ needle: String) -> Bool {
        let n = key(needle)
        guard !n.isEmpty else { return true }
        if key(text).contains(n) { return true }
        let l = loose(needle)
        return !l.isEmpty && loose(text).contains(l)
    }
}

extension String {
    /// مفتاح هذا النصّ للبحث — اختصارٌ لـ`ArabicSearch.key`.
    var searchKey: String { ArabicSearch.key(self) }
    /// ومفتاحه المتساهل — بلا ألفات.
    var looseSearchKey: String { ArabicSearch.loose(self) }
}
