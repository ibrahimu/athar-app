import SwiftUI

/// تخطيط يرصّ الكلمات في أسطر تُملأ من اليمين، مع ضبط المسافات لتمتلئ
/// الأسطر كاملة (justified) كما في صفحة المصحف المطبوع.
///
/// **تحذير اتجاهات — سبب خطأ سابق خطير:**
/// SwiftUI يعكس إحداثيات الـLayout المخصص تلقائيًا حين تكون بيئة التخطيط RTL.
/// وهذا الملف يرصّ من اليمين يدويًا، فلو وُضع داخل بيئة RTL انعكس النص
/// انعكاسًا مزدوجًا وصارت الكلمات مقلوبة — وقد حدث فعلًا في آيات المصحف.
/// لذلك يجب لفّ كل استعمال له بـ:
///     .environment(\.layoutDirection, .leftToRight)
/// وهو ما تفعله MushafPage — فيصير الرصّ صحيحًا مهما كانت لغة الجهاز واتجاهه.
struct FlowLayout: Layout {
    var lineSpacing: CGFloat = 10
    var wordSpacing: CGFloat = 5
    /// ملء السطر كاملًا بتوزيع الفراغ على المسافات — عدا آخر سطر.
    var justified: Bool = true

    struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? 320
        let lines = layoutLines(subviews: subviews, maxWidth: maxWidth)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout Void) {
        let lines = layoutLines(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for (li, line) in lines.enumerated() {
            // ضبط المسافة: آخر سطر يبقى طبيعيًا كما في نهاية الفقرة المطبوعة.
            let gaps = CGFloat(max(1, line.indices.count - 1))
            let isLast = li == lines.count - 1
            let extra: CGFloat = (justified && !isLast && line.indices.count > 1)
                ? max(0, (bounds.width - line.width) / gaps) : 0

            var x = bounds.maxX
            for i in line.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                x -= size.width
                subviews[i].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                  proposal: ProposedViewSize(size))
                x -= (wordSpacing + extra)
            }
            y += line.height + lineSpacing
        }
    }

    private func layoutLines(subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var current = Line()

        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            let added = current.indices.isEmpty ? size.width : current.width + wordSpacing + size.width

            if !current.indices.isEmpty && added > maxWidth {
                lines.append(current)
                current = Line(indices: [i], width: size.width, height: size.height)
            } else {
                current.indices.append(i)
                current.width = added
                current.height = max(current.height, size.height)
            }
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }
}
