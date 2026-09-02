import SwiftUI
import CoreLocation

struct QiblaView: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var compass = HeadingProvider()
    @State private var didAlignHaptic = false

    private var qiblaBearing: Double? { Qibla.bearing(from: store.coordinate) }
    private var distanceKm: Double { Qibla.distanceKm(from: store.coordinate) }
    private var atKaaba: Bool { Qibla.isAtKaaba(store.coordinate) }

    /// زاوية سهم القبلة على الشاشة: اتجاه القبلة ناقص اتجاه الجهاز.
    private var arrowAngle: Double {
        guard let q = qiblaBearing else { return 0 }
        guard let h = compass.heading else { return q }
        return q - h
    }

    /// الفرق بين ما يشير إليه الجهاز والقبلة، ٠ إلى ١٨٠.
    private var offBy: Double? {
        guard let q = qiblaBearing, let h = compass.heading else { return nil }
        var d = abs(q - h).truncatingRemainder(dividingBy: 360)
        if d > 180 { d = 360 - d }
        return d
    }

    private var isAligned: Bool { (offBy ?? 999) <= 4 }

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                VStack(spacing: 22) {
                    if atKaaba {
                        atKaabaCard
                    } else if qiblaBearing == nil {
                        unavailableCard
                    } else {
                        dial
                        readout
                        if compass.isAvailable, compass.needsCalibration { calibrationNote }
                        if !compass.isAvailable { noCompassNote }
                        if compass.isAvailable, !compass.usesTrueNorth, compass.heading != nil {
                            magneticNote
                        }
                    }
                    accuracyNote
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(520)
            }
        }
        .navigationTitle("القبلة")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { compass.start() }
        .onDisappear { compass.stop() }
        .onChange(of: isAligned) { _, aligned in
            // اهتزازة واحدة عند الانطباق، ولا تتكرر حتى يبتعد ثم يعود.
            if aligned, !didAlignHaptic {
                Haptics.done(enabled: store.hapticsEnabled)
                didAlignHaptic = true
            } else if !aligned {
                didAlignHaptic = false
            }
        }
    }

    // MARK: البوصلة

    // ملاحظة: حركة البوصلة تتبع قراءة الحسّاس المستمرة لا حدثًا، فمدتها
    // قصيرة ثابتة (٠٫٢٥ث) لتلاحق الدوران بسلاسة دون أن تتخلّف عن اليد.
    private var dial: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))

            // تدريج كل ١٥ درجة، يدور مع الجهاز
            ForEach(0..<24, id: \.self) { i in
                let major = i % 6 == 0
                Capsule()
                    .fill(major ? Theme.inkSoft : Theme.hairline)
                    .frame(width: major ? 2.5 : 1.5, height: major ? 14 : 8)
                    .offset(y: -128)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
            .rotationEffect(.degrees(-(compass.heading ?? 0)))
            .animation(.smooth(duration: 0.25), value: compass.heading)

            // حرف الشمال
            Text("ش")
                .font(Theme.display(13, weight: .bold))
                .foregroundStyle(Theme.inkSoft)
                .offset(y: -152)
                .rotationEffect(.degrees(-(compass.heading ?? 0)))
                .animation(.smooth(duration: 0.25), value: compass.heading)

            // سهم القبلة
            QiblaArrow()
                .fill(isAligned ? Theme.accent : Theme.gold)
                .frame(width: 46, height: 128)
                .offset(y: -46)
                .rotationEffect(.degrees(arrowAngle))
                .animation(.smooth(duration: 0.25), value: arrowAngle)
                .animation(.smooth(duration: 0.2), value: isAligned)

            // القلب: الكعبة
            Circle()
                .fill(isAligned ? Theme.accentSoft : Theme.surfaceAlt)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "cube.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(isAligned ? Theme.accent : Theme.inkSoft)
                )
                .animation(.smooth(duration: 0.2), value: isAligned)
        }
        // البوصلة شكل هندسي لا نص: بيئة RTL تعكس دوراتها أفقيًا فيشير السهم
        // إلى (٣٦٠ − الزاوية). نثبّتها على اتجاه تخطيط ثابت.
        .environment(\.layoutDirection, .leftToRight)
        .frame(width: 300, height: 300)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    // MARK: القراءة

    private var readout: some View {
        VStack(spacing: 10) {
            if let q = qiblaBearing {
                Text(String(format: "%.0f°", q))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(isAligned ? Theme.accent : Theme.ink)
                    .contentTransition(.numericText())

                Text("\(Qibla.compassName(for: q)) من الشمال\(compass.usesTrueNorth ? " الحقيقي" : "")")
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkSoft)
            }

            if isAligned {
                Label("أنت تواجه القبلة", systemImage: "checkmark.seal.fill")
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.accentSoft))
                    .transition(.scale.combined(with: .opacity))
            } else if let off = offBy {
                Text(String(format: "أدِر الجهاز %.0f° %@", off,
                            turnDirection == .right ? "يمينًا" : "يسارًا"))
                    .font(Theme.display(13, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Image(systemName: "location.fill").font(.system(size: 10))
                Text(store.placeName)
                Text("·")
                Text(distanceText)
            }
            .font(Theme.display(12))
            .foregroundStyle(Theme.inkFaint)
            .padding(.top, 2)
        }
        .animation(.smooth(duration: 0.2), value: isAligned)
    }

    private enum Turn { case left, right }
    private var turnDirection: Turn {
        guard let q = qiblaBearing, let h = compass.heading else { return .right }
        let diff = (q - h + 360).truncatingRemainder(dividingBy: 360)
        return diff <= 180 ? .right : .left
    }

    private var distanceText: String {
        let km = distanceKm
        if km < 1 { return String(format: "%.0f م إلى الكعبة", km * 1000) }
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: km)) ?? "\(Int(km))") كم إلى الكعبة"
    }

    // MARK: حالات خاصة

    private var atKaabaCard: some View {
        AtharCard(padding: 24) {
            VStack(spacing: 12) {
                Image(systemName: "cube.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.accent)
                Text("أنت عند الكعبة")
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("استقبل البيت مباشرة — لا حاجة إلى بوصلة.")
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var unavailableCard: some View {
        AtharCard(padding: 22) {
            Text("تعذّر تحديد اتجاه القبلة لهذا الموقع.")
                .font(Theme.display(15))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity)
        }
    }

    private func note(_ icon: String, _ text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .padding(.top, 2)
            Text(text)
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceAlt))
    }

    private var calibrationNote: some View {
        note("dot.circle.and.hand.point.up.left.fill",
             "البوصلة تحتاج معايرة — حرّك الجهاز على هيئة الرقم ٨ في الهواء، وابتعد عن المعادن والمغانط.",
             color: Theme.gold)
    }

    private var noCompassNote: some View {
        note("exclamationmark.triangle.fill",
             "لا توجد بوصلة في هذا الجهاز، فالسهم ثابت. استعن بزاوية القبلة أعلاه مع بوصلة أخرى.",
             color: Theme.gold)
    }

    private var magneticNote: some View {
        note("info.circle.fill",
             "القراءة بالشمال المغناطيسي لأن خدمات الموقع مغلقة. فعّل الموقع لقراءة أدق بالشمال الحقيقي.",
             color: Theme.inkFaint)
    }

    private var accuracyNote: some View {
        Text("الاتجاه محسوب بالدائرة العظمى إلى الكعبة من موقعك المحدَّد. دقّته تتبع دقّة موقعك ودقّة بوصلة جهازك.")
            .font(Theme.display(11))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// سهم مدبّب برأس عريض وذيل رفيع.
private struct QiblaArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        p.move(to: CGPoint(x: w / 2, y: 0))                 // الرأس
        p.addLine(to: CGPoint(x: w, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.42))
        p.addLine(to: CGPoint(x: w * 0.62, y: h))
        p.addLine(to: CGPoint(x: w * 0.38, y: h))
        p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.42))
        p.addLine(to: CGPoint(x: 0, y: h * 0.42))
        p.closeSubpath()
        return p
    }
}
