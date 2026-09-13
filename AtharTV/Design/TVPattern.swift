import SwiftUI

// MARK: - نقشُ الأرض
//
// منقولٌ عن `PaperMotif` في `Athar/Views/Components.swift`: النقوشُ الستّة
// نفسُها — نجومٌ وسادةٌ وموجٌ وتعريشةٌ ونقاطٌ وحراشفُ — بهندستها وترتيبِ
// شفافيّاتها، والنجمةُ الثمانيةُ معها لأنها في ذلك الملفّ أيضًا.
//
// ونُقل ولم يُشارَك: هدفُ التلفاز يترجم من `Shared` قائمةَ إدراجٍ من أربعةَ عشرَ
// ملفًا، و`Components.swift` ليس منها ولا يصلح لها — ثمانُمئةِ سطرٍ من بطاقاتٍ
// وصفوفِ إعداداتٍ وحلقاتِ تقدّمٍ وميدالياتٍ وهالاتِ ختمٍ ورقائقِ أيقونات، وضعُها
// شاشةٌ تُلمَس بالإصبع. فنقلُ ثمانين سطرًا من رسمٍ أرخصُ من جرِّ ذلك كلِّه — وأصدقُ:
// النقشُ على التلفاز ليس هو النقشَ على الهاتف حتى يُشارَك، وقد أُعيدت معايرتُه هنا.
//
// وما أُعيد: المسافةُ كبُرت (`repeatScale`) والحبرُ خفّ (`ornamentOpacity`)،
// وكلُّ رقمٍ في الرسم أدناه هو رقمُ الهاتف نفسُه مضروبًا في المقياس — تُرك ظاهرًا
// ولم يُختصر ليُقرأ الأصلُ والمنقولُ في السطر الواحد.
//
// ولا حركةَ فيه: «لا حركة للزينة» قاعدةُ `Motion` في هذا المشروع، وهذه أرضُ
// شاشةٍ تبقى مضاءةً ساعاتٍ والقرآنُ يُتلى — فلا انسيابَ ولا لمعانَ ولا نبض.
// يُرسم مرّةً ثم يسكن.
struct TVPattern: View {

    /// النقش — وافتراضُه اختيارُ صاحبِ الجهاز لا النجماتُ وحدها.
    ///
    /// `BackgroundPattern.current` هو ما يضبطه `TVPrefs` عند كلِّ تبديل، كما
    /// يفعل `Theme.current` باللون؛ وبه يبقى وصلُ الأرض كلمةً واحدة: `TVPattern()`
    /// تتبع المختارَ من غير أن يُمرَّر إليها. ولا يُمرَّر صراحةً إلا في مربّعات
    /// المعاينة، حيث يُعرض كلُّ نقشٍ بعينه لا المختارُ منها.
    var pattern: BackgroundPattern = BackgroundPattern.current

    /// الطابعُ يُؤخذ قيمةً ولا يُقرأ من `Theme` داخل الرسم: `Canvas` لا يُعاد
    /// رسمُه إلا إذا تغيّرت قيمةُ البنية، ولونٌ يُقرأ ساكنًا من داخل الإغلاق يبقى
    /// على الطابع القديم بعد تبديله — وفي هذه الشاشة يُبدَّل الطابعُ بضغطةِ نقطة.
    var theme: AppTheme = Theme.current

    /// مضاعِفُ الظهور. النقشُ في الأرض «يُحسّ ولا يُقرأ»، وهو في مربّع الاختيار
    /// معروضٌ ليُرى ويُقارَن — فيُرفع هناك وحده، ولا تُمسّ معايرةُ الأرض.
    var boost: Double = 1

    // MARK: المعايرة

    /// مضاعفُ وحدة النقش — والمقياسُ ليس زاويًّا كما بدا أوّلَ الأمر.
    ///
    /// الحسابُ الزاويّ يقول: هاتفٌ عرضُه ٣٩٠ نقطةً على بُعد ٣٠ سم يملأ من العين
    /// نحوَ ١٥ درجة، وتلفازٌ عرضُه ١٩٢٠ على بُعد ثلاثةِ أمتارٍ يملأ نحوَ ٢٧ —
    /// فالتعادلُ ٢٫٧ تقريبًا، أي أن تكبُر الوحدةُ ثلاثةَ أضعاف. وبُني على ٢٫٢ ثمّ
    /// رُئي في التطبيق نفسِه فإذا هو خطأ: نجمةٌ قطرُها ٨٨ نقطةً لا تتكرّر في
    /// العرض إلا تسعَ مرّات، فيخرج الفراغُ بقعًا كبيرةً متباعدةً تُعدّ واحدةً
    /// واحدة — وترى العينُ في اللطخة الواسعة الخافتة غبارًا على الزجاج أو خللًا
    /// في الإضاءة لا نقشًا. والعينُ للتموّج الواسع أشدُّ حساسيةً منها للحبيبة.
    ///
    /// فجُرّبت أربعةُ مقاييسَ في لوحٍ واحدٍ جنبًا إلى جنبٍ على الشاشة نفسِها
    /// (٢٫٢ و١٫٣ و٠٫٩ و٠٫٦): عند ٢٫٢ و١٫٣ بقعٌ متفرّقة، وعند ٠٫٦ حبيبةٌ ناعمةٌ
    /// لا يُعرف شكلُها، وعند ٠٫٩ نسجٌ مستوٍ يعمّ الفراغ — ومن دنا من الشاشة رأى
    /// النجماتِ الثمانيةَ نقشًا يُعرف. وهي وحدةُ الهاتف نفسُها تقريبًا: النقشُ
    /// لا يُكبَّر لأن الشاشة كبُرت، بل يبقى محفورًا كما هو ويكثر عددُه.
    static let repeatScale: CGFloat = 0.90

    /// خليّةُ نقش النجوم في الهاتف — وإليها تُنسب مقاساتُ النقوش الستّة كلِّها،
    /// فهي وحدةُ القياس التي يُعرف بها كم وحدةً يسع اللوح.
    static let baseCell: CGFloat = 96

    /// وحدةُ النقش في لوحٍ مقاسُه `size`.
    ///
    /// الأرضُ ملءُ الشاشة فتأخذ `repeatScale` كما عُوير — القسمةُ أدناه أكبرُ
    /// منه بكثيرٍ فلا تبلغه، والمعايرةُ تبقى حيث قيست حرفًا. وإنما تعمل في
    /// اللوح الصغير: مربّعُ المعاينة في الإعدادات ١٧٦ في ١٠٨، ووحدةٌ خليّتُها
    /// ٨٦ نقطةً تضع فيه نجمةً واحدةً مقطوعةً — فيُرى في الستّة كلِّها لطخةٌ
    /// لا نقشٌ يُقارَن بأخيه، ويُختار النقشُ على غير بيّنة. فحدٌّ واحد: لا يقلّ
    /// اللوح عن أربع خلايا في أقصر ضلعيه، ويصغر النقشُ بصغر لوحه.
    static func unit(in size: CGSize) -> CGFloat {
        min(repeatScale, min(size.width, size.height) / (4 * baseCell))
    }

    /// حبرُ النقش. الهاتفُ في الوضع الداكن ٠٫٠٢٨، وهنا ٠٫٠٠٩ — أي ثلثُه.
    ///
    /// والنافذةُ ضيّقةٌ جدًّا، وقد قيست على المِرقاب لا خُمّنت: حبرُ الوضع الداكن
    /// يكاد يكون أبيضَ وأرضُه تكاد تكون سوداء، والفرقُ بينهما نحوُ ٢٢٣ من ٢٥٥ في
    /// الطوابع الاثني عشر كلِّها. فـ٠٫٠٢٨ ترفع الأرضَ ستَّ درجاتٍ ونصفًا —
    /// وأرضٌ لمعانُها ٢٢ ترتفع إلى ٢٨ قفزةٌ نسبتُها الرُبع، تُرى على خمسٍ وستّين
    /// بوصةً لطخًا له حدّ لا نقشًا. و٠٫٠٠٤ تنزل تحت أرضيّة الثماني بتّاتٍ فلا
    /// يبقى شيءٌ يُرى أصلًا — جُرّبت فخرجت الشاشةُ مسطّحةً كأن لا نقشَ فيها.
    /// و٠٫٠٠٩ درجتان ونصفٌ ونيّف: أدنى فرقٍ يثبت في الثماني بتّات ولا يزيد.
    ///
    /// والمقيسُ في الطوابع الثلاثة التي فُحصت: ٢٫٧٣ للأخضر و٢٫٦٤ للرمليّ و٢٫٧٦
    /// للنيليّ — فلا يختفي في طابعٍ ولا يصرخ في آخر، وهذا ثمرةُ أن يكون الحبرُ
    /// حبرًا لا لونَ طابعٍ ولا ذهبًا.
    static let ornamentOpacity: Double = 0.009

    var body: some View {
        // حبرُ الوضع الداكن مباشرةً: `AtharTVApp` تفرض `.preferredColorScheme(.dark)`
        // فلا وضعَ فاتحَ في هذا الهدف يُسأل عنه. والحبرُ لا الذهبُ ولا لونُ الطابع:
        // الحبرُ وحده يبعد عن أرضه بمقدارٍ واحدٍ في الطوابع الاثني عشر كلِّها، فلا
        // يختفي النقشُ في طابعٍ ولا يصرخ في آخر.
        let ink = Color(hex: theme.ink.dark)
        // والأوزانُ النسبية بين النقوش الستّة (٠٫٩ و٠٫٨٥ و١٫١٥…) بقيت كما هي في
        // الهاتف: الخطُّ يضع حبرًا أقلَّ من المِلء على المساحة نفسها، فبها تتساوى
        // الستّةُ في الأثر. و`boost` يضربها جميعًا فلا يختلّ ما بينها.
        let op = Self.ornamentOpacity * boost

        Group {
            switch pattern {
            case .plain:
                Color.clear

            case .stars:
                Canvas { ctx, size in
                    let s = Self.unit(in: size)
                    // والتمويهُ في السياق لا على المشهد: مقدارُه يتبع الوحدةَ
                    // والوحدةُ لا تُعرف إلا هنا. و`drawLayer` تجمع الرسمَ كلَّه في
                    // طبقةٍ واحدةٍ تُموَّه مرّةً — ولولاها لَلَحِق المرشّحُ كلَّ شكلٍ
                    // وحدَه، ثلاثُمئةِ طبقةٍ في رسمةٍ واحدة.
                    ctx.addFilter(.blur(radius: 0.6 * s))
                    ctx.drawLayer { ctx in
                        let cell: CGFloat = 96 * s, r: CGFloat = 20 * s
                        let color = ink.opacity(op)
                        var row = 0; var y: CGFloat = -cell / 2
                        while y < size.height + cell {
                            let off: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                            var x: CGFloat = -cell / 2 + off
                            while x < size.width + cell {
                                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                                ctx.fill(EightPointStar(innerRatio: 0.64).path(in: rect), with: .color(color))
                                x += cell
                            }
                            y += cell * 0.86; row += 1
                        }
                    }
                }

            case .waves:
                Canvas { ctx, size in
                    let s = Self.unit(in: size)
                    ctx.addFilter(.blur(radius: 0.5 * s))
                    ctx.drawLayer { ctx in
                        // حلقاتُ أثر القطرة — هويّةُ «أثر». و`Canvas` لا يعكس رسمَه
                        // للاتجاه العربيّ (جُرّب فوقعت القطرةُ يمينًا كما كُتبت)،
                        // فـ٠٫٩ من العرض هي الجهةُ الرائدةُ على شاشةٍ عربية: حيث
                        // يدخل النظرُ وحيث يقف عمودُ الوقت.
                        let c = CGPoint(x: size.width * 0.9, y: size.height * 0.12)
                        let color = ink.opacity(op * 0.9)
                        // الهاتفُ يرسم حتى ١٫٧ من العرض لأن شاشته طولية فأبعدُ ركنٍ عن
                        // القطرة بعيد. والتلفازُ عريض، فأبعدُ ركنٍ فيه دون ذلك بكثير:
                        // يُحسب الحدُّ من الركن نفسِه، وما بعده حلقاتٌ تُحسب ولا تُرى.
                        let far = hypot(max(c.x, size.width - c.x), max(c.y, size.height - c.y))
                        var r: CGFloat = 40 * s
                        while r < far {
                            let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                            ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1.2 * s)
                            r += 46 * s
                        }
                    }
                }

            case .lattice:
                Canvas { ctx, size in
                    let s = Self.unit(in: size)
                    ctx.addFilter(.blur(radius: 0.5 * s))
                    ctx.drawLayer { ctx in
                        // تعريشةٌ قُطريّةٌ متشابكة.
                        let step: CGFloat = 52 * s
                        let color = ink.opacity(op * 0.85)
                        var d: CGFloat = -size.height
                        while d < size.width + size.height {
                            var p1 = Path(); p1.move(to: CGPoint(x: d, y: 0)); p1.addLine(to: CGPoint(x: d + size.height, y: size.height))
                            ctx.stroke(p1, with: .color(color), lineWidth: 0.9 * s)
                            var p2 = Path(); p2.move(to: CGPoint(x: d, y: 0)); p2.addLine(to: CGPoint(x: d - size.height, y: size.height))
                            ctx.stroke(p2, with: .color(color), lineWidth: 0.9 * s)
                            d += step
                        }
                    }
                }

            case .dots:
                Canvas { ctx, size in
                    let s = Self.unit(in: size)
                    ctx.addFilter(.blur(radius: 0.4 * s))
                    ctx.drawLayer { ctx in
                        // نقاطٌ ناعمةٌ منتظمة.
                        let cell: CGFloat = 40 * s, r: CGFloat = 2.4 * s
                        let color = ink.opacity(op * 1.15)
                        var row = 0; var y: CGFloat = cell / 2
                        while y < size.height + cell {
                            let off: CGFloat = row.isMultiple(of: 2) ? 0 : cell / 2
                            var x: CGFloat = cell / 2 + off
                            while x < size.width + cell {
                                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                                         with: .color(color))
                                x += cell
                            }
                            y += cell; row += 1
                        }
                    }
                }

            case .scales:
                Canvas { ctx, size in
                    let s = Self.unit(in: size)
                    ctx.addFilter(.blur(radius: 0.5 * s))
                    ctx.drawLayer { ctx in
                        // حراشفُ — أقواسٌ متراكبةٌ صفًّا بعد صفّ.
                        let r: CGFloat = 30 * s
                        let color = ink.opacity(op * 0.9)
                        var row = 0; var y: CGFloat = 0
                        while y < size.height + r {
                            let off: CGFloat = row.isMultiple(of: 2) ? 0 : r
                            var x: CGFloat = -r + off
                            while x < size.width + r {
                                var arc = Path()
                                arc.addArc(center: CGPoint(x: x, y: y), radius: r,
                                           startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
                                ctx.stroke(arc, with: .color(color), lineWidth: 0.9 * s)
                                x += r * 2
                            }
                            y += r; row += 1
                        }
                    }
                }
            }
        }
        // النقشُ في الورق لا فوقه: لا يأخذ لمسًا ولا تركيزًا، ويملأ الشاشة كلَّها.
        // و`ignoresSafeArea` هنا لا عند النداء: للأرضِ امتدادٌ واحدٌ صحيح، وتركُه
        // لموضع الاستعمال بابُ أن يُنسى فيظهر للنقش حدٌّ عند حافّة الأمان.
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

// MARK: - النجمة الثمانية

/// نجمةٌ ثمانيةٌ (رَبّ) — الشكلُ التقليديّ حول أرقام السور في المصاحف.
/// منقولةٌ حرفًا عن `EightPointStar` في `Athar/Views/Components.swift` لأن نقشَ
/// النجوم لا يقوم بغيرها. وهي `private` عمدًا: هندسةٌ خاصّةٌ بهذا النقش، لا
/// اسمٌ عامٌّ ثانٍ يزاحم اسمَ الأصل لو أُدرج ملفُّ المكوّنات يومًا.
private struct EightPointStar: Shape {
    var innerRatio: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let R = min(rect.width, rect.height) / 2
        let r = R * innerRatio
        var p = Path()
        for i in 0..<16 {
            let radius = i.isMultiple(of: 2) ? R : r
            let angle = (.pi / 8) * CGFloat(i) - .pi / 2
            let pt = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}
