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

    static func key(_ s: String) -> String { key(s, slim: false) }

    /// المفتاح نفسه إلّا أنّ **الألف الخنجرية تُسقط** ولا تُزاد ألفًا.
    ///
    /// الخنجرية تُقرأ ألفًا فيزيدها المفتاح، وهذا صوابٌ فيما يكتبه الناس بألف —
    /// «ٱلسَّمَٰوَٰتِ» يبحث عنها من يكتب «السماوات». لكنّ الرسم فيه ما لا يُكتب بألفٍ
    /// أصلًا: «ذَٰلِكَ» يكتبها الناس «ذلك» لا «ذالك»، و«أُو۟لَـٰٓئِكَ» «أولئك» لا
    /// «أولايك»، و«ٱلرَّحْمَٰنِ» «الرحمن». فمفتاحُها الدقيق يفترق عمّا يُكتب،
    /// فلا يُوجَد — و«ذلك» وحدها في أربعمئةٍ وثمانٍ وستّين آية.
    /// فيُحسب مفتاحان: دقيقٌ تُزاد فيه، ونحيلٌ تُسقط منه، ويُبحث بهما معًا.
    static func slim(_ s: String) -> String { key(s, slim: true) }

    private static func key(_ s: String, slim: Bool) -> String {
        let scalars = Array(s.unicodeScalars)
        var out = String.UnicodeScalarView()
        out.reserveCapacity(scalars.count)
        // نحن داخل رقم آية: «۝٢» رمزٌ ثمّ رقمُه. الرمزُ يُسقط، ولو بقي رقمُه لالتصق
        // بين الكلمتين — «قل هو الله أحد ۝١ الله الصمد» يصير «…احد1الله…» — فلا يجد
        // من كتب الآيتين متتابعتين كما يقرأهما على الشاشة.
        var inAyahNumber = false
        // هل آخرُ ما أُلحق ياءٌ مولَّدةٌ من ألفٍ مقصورة؟ — «out.last == \"ي\"» لا تكفي:
        // الياءُ الحقيقية والمقصورةُ والهمزةُ على نبرة تصير كلُّها «ي» في المخرَج،
        // فكانت قاعدةُ وسط الكلمة تأكل ياءً منطوقة: «ٱلْقِيَٰمَةِ» تصير «القامه»،
        // و«ٱلشَّيَٰطِينَ» «الشاطين»، و«ءَايَٰتِ» «اات» — في ثمانمئةٍ وثلاثين موضعًا.
        var lastWasMaqsura = false
        var i = 0
        while i < scalars.count {
            let u = scalars[i]
            defer { i += 1 }
            if inAyahNumber {
                if (0x0660...0x0669).contains(u.value) || (0x06F0...0x06F9).contains(u.value) { continue }
                inAyahNumber = false
            }
            switch u.value {
            case 0x06DD: inAyahNumber = true                   // ۝ علامة نهاية الآية
            // الياء الصغيرة العليا حرفٌ يُنطق لا علامةَ ضبط: «إِبْرَٰهِـۧمَ» إملاؤها
            // «إبراهيم»، و«ٱلنَّبِيِّـۧنَ» إملاؤها «النبيين». وكانت تُسقط مع علامات
            // الضبط، فلا يجد من كتب «إبراهيم» ولا «خاتم النبيين».
            case 0x06E7: out.append("ي")
            // رمز ﷺ وأخواته من صور العرض: حروفٌ في نظر النظام، فكانت تمرّ في المفتاح
            // فتقطع الجملة على من كتبها متّصلة.
            case 0xFDF0...0xFDFF, 0xFE70...0xFEFF: continue
            // تشكيل، وعلامات وقفٍ وضبطٍ للمصحف، وتطويل — تُسقط جميعًا.
            case 0x0610...0x061A, 0x064B...0x065F, 0x06D6...0x06ED,
                 0x0640, 0x08D3...0x08FF:
                continue
            // الألف الخنجرية: تُقرأ ألفًا، ورسمُها في المصحف على ثلاثة أوجه —
            //   «عَلَىٰ» ألفٌ مقصورة تحتها، وإملاؤها «على»: فتُسقط ويبقى ما قبلها.
            //   «ٱلْعَٰلَمِينَ» حرفٌ صحيح تحتها، وإملاؤها «العالمين»: فتُزاد ألفًا.
            //   وبعد الواو وجهان لا وجه، والفرقُ بينهما ما يليها:
            //     «ٱلصَّلَوٰةَ» و«ٱلزَّكَوٰةَ» و«ٱلْحَيَوٰةِ» — تليها تاءٌ مربوطة، والواو
            //     فيها كرسيُّ رسمٍ لا حرفٌ يُنطق، وإملاؤها «الصلاة»: فتحلّ الألفُ محلّها.
            //     «ٱلسَّمَٰوَٰتِ» و«ٱلْوَٰلِدَيْنِ» — الواو فيها حرفٌ أصليّ يُنطق،
            //     وإملاؤها «السماوات» و«الوالدين»: فتبقى وتُزاد الألف بعدها.
            //   وكان الوجهان واحدًا فتُؤكل الواو الأصلية، فلا يجد من كتب «السماوات»
            //   شيئًا — وهي في ثلاثٍ وثمانين ومئة آية.
            case 0x0670:
                defer { lastWasMaqsura = false }
                // المفتاح النحيل: تُسقط رأسًا بلا زيادةٍ ولا حذفٍ لما قبلها.
                guard !slim else { continue }
                let next = nextLetter(scalars, after: i)
                let midWord = next.map { Character(Unicode.Scalar($0) ?? " ").isLetter } ?? false
                switch out.last {
                case "ي" where lastWasMaqsura:
                    // الألف المقصورة وحدها: «عَلَىٰ» في آخر الكلمة إملاؤها «على»،
                    // و«ٱلتَّوْرَىٰةَ» في وسطها ألفٌ تامّة إملاؤها «التوراة».
                    if midWord { out.removeLast(); out.append("ا") }
                case "و":
                    // الواو كرسيُّ رسمٍ إن تلتها تاءٌ مربوطة («ٱلصَّلَوٰةَ» ← «الصلاة»)،
                    // وحرفٌ أصليّ فيما سواه («ٱلسَّمَٰوَٰتِ» ← «السماوات»).
                    if next == 0x0629 { out.removeLast() }
                    out.append("ا")
                default: out.append("ا")
                }
            // صور الألف والهمزة تُردّ إلى ألف: «إسراء» و«اسراء» سواء.
            case 0x0622, 0x0623, 0x0625, 0x0671:
                out.append("ا"); lastWasMaqsura = false
            case 0x0629: out.append("ه"); lastWasMaqsura = false   // «رحمة» و«رحمه»
            case 0x0649: out.append("ي"); lastWasMaqsura = true     // «ذكرى» و«ذكري»
            case 0x0624: out.append("و"); lastWasMaqsura = false
            case 0x0626: out.append("ي"); lastWasMaqsura = false    // همزةٌ على نبرة، لا مقصورة
            case 0x0621: continue          // همزةٌ مفردة تُسقط
            // الأرقام الهندية والفارسية تُردّ إلى الغربية: من كتب «٥٥» بلوحته العربية.
            case 0x0660...0x0669: out.append(Unicode.Scalar(u.value - 0x0660 + 48)!); lastWasMaqsura = false
            case 0x06F0...0x06F9: out.append(Unicode.Scalar(u.value - 0x06F0 + 48)!); lastWasMaqsura = false
            default:
                lastWasMaqsura = false
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

    /// أوّلُ حرفٍ بعد الموضع، متخطّيًا التشكيلَ وعلاماتِ الضبط — به يُعرف وجهُ الألف
    /// الخنجرية بعد الواو.
    private static func nextLetter(_ scalars: [Unicode.Scalar], after i: Int) -> UInt32? {
        var j = i + 1
        while j < scalars.count {
            let v = scalars[j].value
            let isMark = (0x0610...0x061A).contains(v) || (0x064B...0x065F).contains(v)
                || (0x06D6...0x06ED).contains(v) || v == 0x0640 || v == 0x0670
                || (0x08D3...0x08FF).contains(v)
            if !isMark { return v }
            j += 1
        }
        return nil
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
    /// المفتاح مع **طيّ الحرف المكرَّر** وحده، والألفُ باقية.
    ///
    /// المصحف يكتب المشدَّد حرفًا واحدًا وعليه شدّة، والناس يكتبونه حرفين:
    /// «ٱلَّيْلِ» مفتاحُها «اليل» بلامٍ واحدة، ومن يبحث يكتب «الليل» بلامين —
    /// فلا يجد شيئًا وهي في تسعٍ وستّين آية. وطيُّ التكرار وحده يجمعهما
    /// بلا أن يُفقد الألفَ فيتّسع الضجيج كما يتّسع في المتساهل.
    static func collapsed(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        var last: Unicode.Scalar?
        for u in key(s).unicodeScalars {
            if u == last { continue }
            out.append(u); last = u
        }
        return String(out)
    }

    static func loose(_ s: String) -> String {
        var out = String.UnicodeScalarView()
        var last: Unicode.Scalar?
        for u in key(s).unicodeScalars {
            if u == "ا" { continue }
            // ولا يُكرَّر حرفٌ: الهمزةُ على الياء تُردّ ياءً فتلتقي بياءٍ بعدها —
            // «اسرائيل» تصير «اسراييل» ولا تقع في «إِسْرَٰٓءِيلَ». والتضعيفُ كذلك.
            if u == last { continue }
            out.append(u); last = u
        }
        return String(out)
    }

    /// صيغةُ الاسم المعرَّف بعد لام الجرّ: «الرحمن» ← «للرحمن».
    ///
    /// لامُ الجرّ تبتلع ألفَ «ال» في الرسم — «لِلرَّحْمَٰنِ» و«لِلنَّاسِ»
    /// و«لِلْوَٰلِدَيْنِ» و«لِلصَّلَوٰةِ» — فمن بحث عن الاسم مُعرَّفًا لم يجد مواضعه
    /// المجرورة باللام، وهي في «الناس» وحدها سبعٌ وثلاثون آية. ولا يُتوسَّع بأكثر
    /// من هذا: الباءُ والكافُ والفاءُ تُبقي الألف، فلا حاجة لها.
    /// يعود nil لما لا يبدأ بـ«ال» أو كان أقصرَ من أن يُميَّز.
    static func lamPrefixed(_ k: String) -> String? {
        guard k.hasPrefix("ال"), k.count > 3 else { return nil }
        return "لل" + k.dropFirst(2)
    }

    /// هل يقع `needle` في `text`؟ على أربع درجاتٍ من الدقّة إلى التساهل، تُجرَّب
    /// بترتيبها: المفتاح، ثمّ النحيل (الخنجرية)، ثمّ طيّ التكرار (الشدّة)، ثمّ
    /// المتساهل. والثلاثة الأُوَل دقيقة، والرابعة آخرُ ما يُلجأ إليه.
    static func matches(_ text: String, _ needle: String) -> Bool {
        let n = key(needle)
        guard !n.isEmpty else { return true }
        if key(text).contains(n) { return true }
        let sl = slim(needle)
        if sl.count >= 2, slim(text).contains(sl) { return true }
        let c = collapsed(needle)
        if c.count >= 2, collapsed(text).contains(c) { return true }
        if let lam = lamPrefixed(n), key(text).contains(lam) { return true }
        if let lam = lamPrefixed(sl), slim(text).contains(lam) { return true }
        // حرفان كما في بحث المصحف والحديث: حرفٌ واحد بعد طيّ المكرّر يُطابق كلَّ شيء.
        let l = loose(needle)
        return l.count >= 2 && loose(text).contains(l)
    }

    /// هل يقع الاستعلام في اسم سورة؟ — يُسقط «سورة» المتصدّرة، فمن كتب «سورة الكهف»
    /// كما تُقرأ في الشاشة يجدها؛ وكان المفتاح يُلصقها بالاسم فلا يقع في «الكهف».
    /// ويُجرَّب المتساهل كذلك: «الرحمان» تجد «الرحمن».
    static func matchesSurahName(_ name: String, _ query: String) -> Bool {
        var q = key(query)
        let prefix = key("سورة")
        if q.hasPrefix(prefix), q.count > prefix.count { q.removeFirst(prefix.count) }
        guard !q.isEmpty else { return false }
        if key(name).contains(q) { return true }
        var l = loose(query)
        let lp = loose("سورة")
        if !lp.isEmpty, l.hasPrefix(lp), l.count > lp.count { l.removeFirst(lp.count) }
        return !l.isEmpty && loose(name).contains(l)
    }
}

extension String {
    /// مفتاح هذا النصّ للبحث — اختصارٌ لـ`ArabicSearch.key`.
    var searchKey: String { ArabicSearch.key(self) }
    /// ومفتاحه المتساهل — بلا ألفات.
    var looseSearchKey: String { ArabicSearch.loose(self) }
}
