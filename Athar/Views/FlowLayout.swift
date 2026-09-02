import SwiftUI

/// تخطيط يرصّ العناصر في أسطر متتابعة وينتقل للسطر التالي عند امتلائه —
/// كما يتدفّق النص في صفحة المصحف، لكن كل كلمة عنصر مستقل يمكن لمسه وتظليله.
struct FlowLayout: Layout {
    var lineSpacing: CGFloat = 10
    var wordSpacing: CGFloat = 5
    /// المصحف عربي: تُملأ الأسطر من اليمين إلى اليسار.
    var rightToLeft: Bool = true

    struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let lines = layoutLines(subviews: subviews, maxWidth: maxWidth)
        let height = lines.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, lines.count - 1))
        return CGSize(width: maxWidth == .infinity ? lines.map(\.width).max() ?? 0 : maxWidth,
                      height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout Void) {
        let lines = layoutLines(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for line in lines {
            // محاذاة من حافة السطر لا توسيط: التوسيط يجعل بدايات الأسطر
            // متفاوتة فتتشتّت العين ويبدو الترتيب مضطربًا.
            var x = rightToLeft ? bounds.maxX : bounds.minX

            for i in line.indices {
                let size = subviews[i].sizeThatFits(.unspecified)
                if rightToLeft {
                    x -= size.width
                    subviews[i].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                    x -= wordSpacing
                } else {
                    subviews[i].place(at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                    x += size.width + wordSpacing
                }
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
