import Foundation

// MARK: - مقارنة نصّ منطوق بنصّ الآية (التسميع)

enum ArabicMatch {
    /// تطبيع للمقارنة: بلا تشكيل ولا رموز ضبط المصحف، وتوحيد الهمزات والألف والياء والتاء المربوطة.
    static func normalize(_ s: String) -> String {
        var out = ""
        for u in s.unicodeScalars {
            switch u.value {
            case 0x064B...0x065F, 0x0670, 0x06D6...0x06ED, 0x0640, 0x06DF...0x06E8, 0x08D3...0x08FF: continue
            case 0x0622, 0x0623, 0x0625, 0x0671: out.append("ا")
            case 0x0629: out.append("ه")
            case 0x0649: out.append("ي")
            case 0x0624: out.append("و")
            case 0x0626: out.append("ي")
            case 0x0621: continue
            default: out.unicodeScalars.append(u)
            }
        }
        return out
    }

    /// مسافة تحرير بسيطة.
    static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }; if b.isEmpty { return a.count }
        var prev = Array(0...b.count), cur = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    static func similar(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let n = max(a.count, b.count)
        let d = distance(a, b)
        return n >= 5 ? d <= 1 : (n >= 3 ? d == 0 || (d == 1 && n >= 4) : false)
    }

    enum WordState { case pending, correct, wrong, missed }

    /// يُحاذي كلمات الآية مع الكلمات المنطوقة (أطول تطابق مشترك) ويُعيد حالة كل كلمة من الآية.
    static func align(target: [String], spoken: [String]) -> [WordState] {
        let t = target.map(normalize), s = spoken.map(normalize)
        guard !t.isEmpty else { return [] }
        guard !s.isEmpty else { return Array(repeating: .pending, count: t.count) }
        // LCS
        var dp = Array(repeating: Array(repeating: 0, count: s.count + 1), count: t.count + 1)
        for i in stride(from: t.count - 1, through: 0, by: -1) {
            for j in stride(from: s.count - 1, through: 0, by: -1) {
                dp[i][j] = similar(t[i], s[j]) ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var states = Array(repeating: WordState.pending, count: t.count)
        var i = 0, j = 0
        var lastMatched = -1
        while i < t.count && j < s.count {
            if similar(t[i], s[j]) { states[i] = .correct; lastMatched = i; i += 1; j += 1 }
            else if dp[i + 1][j] >= dp[i][j + 1] { states[i] = .missed; i += 1 }
            else { j += 1 }
        }
        // ما بعد آخر كلمة مطابَقة لم يُقرأ بعد (pending)، وما بينها فُوِّت (missed/wrong)
        for k in 0..<t.count where k > lastMatched { if states[k] == .missed { states[k] = .pending } }
        // كلمة منطوقة بين كلمتين صحيحتين لكنها غير مطابقة: نعدّها خطأ في موضعها
        return states
    }

    static func score(_ states: [WordState]) -> Double {
        let read = states.filter { $0 != .pending }.count
        guard read > 0 else { return 0 }
        return Double(states.filter { $0 == .correct }.count) / Double(read)
    }
}
