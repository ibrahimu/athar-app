import SwiftUI

/// هوية أثر البصرية في الويدجتات: تدرّج يتبع ساعة اليوم، ودوائر أثر القطرة.
enum AtharStyle {

    /// لحظة اليوم — تُشتق من أوقات الصلاة لا من الساعة، فتصدق مع كل موقع.
    enum Moment {
        case night, dawn, morning, noon, afternoon, sunset

        static func at(_ date: Date, times: PrayerTimes?) -> Moment {
            guard let t = times,
                  let fajr = t[.fajr], let sunrise = t[.sunrise], let dhuhr = t[.dhuhr],
                  let asr = t[.asr], let maghrib = t[.maghrib]
            else { return .night }
            if date < fajr        { return .night }
            if date < sunrise     { return .dawn }
            if date < dhuhr       { return .morning }
            if date < asr         { return .noon }
            if date < maghrib     { return .afternoon }
            return .sunset
        }

        /// تدرّج الخلفية — هادئ لا صارخ، يبقى النص فوقه مقروءًا.
        var gradient: [Color] {
            switch self {
            case .night:     return [Color(hex: 0x0B1220), Color(hex: 0x121B2E)]
            case .dawn:      return [Color(hex: 0x1B2340), Color(hex: 0x3A3350)]
            case .morning:   return [Color(hex: 0x123A2E), Color(hex: 0x1B5140)]
            case .noon:      return [Color(hex: 0x14332A), Color(hex: 0x1E4B3A)]
            case .afternoon: return [Color(hex: 0x2A2A20), Color(hex: 0x4A3A24)]
            case .sunset:    return [Color(hex: 0x2B1E2C), Color(hex: 0x3E2438)]
            }
        }

        /// لون التمييز فوق التدرّج.
        var tint: Color {
            switch self {
            case .night:     return Color(hex: 0x8FB4E8)
            case .dawn:      return Color(hex: 0xB9A7E0)
            case .morning:   return Color(hex: 0x6FD3A6)
            case .noon:      return Color(hex: 0x7FD9AE)
            case .afternoon: return Color(hex: 0xE0B06A)
            case .sunset:    return Color(hex: 0xE39BB4)
            }
        }

        var ink: Color { Color(hex: 0xF4F6F5) }
        var inkSoft: Color { Color(hex: 0xF4F6F5).opacity(0.62) }

        var caption: String {
            switch self {
            case .night:     return "قيام الليل"
            case .dawn:      return "قبل الفجر"
            case .morning:   return "بورك لأمتي في بكورها"
            case .noon:      return "طاب يومك"
            case .afternoon: return "أذكار المساء"
            case .sunset:    return "حصّن ليلتك"
            }
        }
    }

    /// أثر القطرة: حلقات متمددة — الشعار نفسه، خافتًا خلف المحتوى.
    struct Ripples: View {
        var tint: Color
        var center: UnitPoint = .init(x: 0.86, y: 0.22)
        var scale: CGFloat = 1

        var body: some View {
            GeometryReader { g in
                let c = CGPoint(x: g.size.width * center.x, y: g.size.height * center.y)
                ZStack {
                    ForEach(0..<4, id: \.self) { i in
                        let r = (28.0 + Double(i) * 26.0) * scale
                        Circle()
                            .stroke(tint.opacity(0.16 - Double(i) * 0.03), lineWidth: 1.4)
                            .frame(width: r * 2, height: r * 2)
                            .position(c)
                    }
                    Circle()
                        .fill(tint.opacity(0.20))
                        .frame(width: 9 * scale, height: 9 * scale)
                        .position(c)
                }
            }
            .allowsHitTesting(false)
        }
    }

    /// خلفية الويدجت كاملة.
    struct Backdrop: View {
        let moment: Moment
        var rippleScale: CGFloat = 1

        var body: some View {
            ZStack {
                LinearGradient(colors: moment.gradient, startPoint: .topTrailing, endPoint: .bottomLeading)
                Ripples(tint: moment.tint, scale: rippleScale)
            }
        }
    }
}
