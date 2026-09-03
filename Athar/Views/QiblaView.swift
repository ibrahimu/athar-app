import SwiftUI
import CoreLocation

struct QiblaView: View {
    /// true حين تكون تبويبًا في الشريط السفلي (لا تُخفيه)،
    /// false حين تُفتح مدفوعة من شاشة الصلاة (تُخفي الشريط وتُظهر زر الرجوع).
    var isRootTab = false

    @EnvironmentObject private var store: AtharStore
    @StateObject private var compass = HeadingProvider()
    @State private var didAlignHaptic = false

    /// زوايا العرض بعد فكّ الالتفاف: قراءة البوصلة تقفز من ٣٥٩° إلى ٠°، ولو حرّكنا
    /// الرسم على الزاوية الخام لدار القرص والسهم دورة كاملة عكسية عند كل مرور بالشمال.
    /// تبقى nil قبل أول قراءة، فيتبع العرض الزاوية الخام — وجهاز بلا بوصلة يبقى سهمه على زاوية القبلة.
    @State private var shownArrow: Double?
    @State private var shownDial: Double?

    /// منتقي الموقع: يُنشأ عند أول فتح فقط، فشاشة القبلة لا تحتاج خدمات الموقع قبل ذلك.
    @State private var location: LocationProvider?
    @State private var showCityPicker = false

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// حروف الجهات الأربع على القرص — الشمال (ش) أبرزها والبقية مُلمَّحة.
    private let cardinalMarks: [QiblaCardinal] = [
        .init(letter: "ش", angle: 0),
        .init(letter: "ق", angle: 90),
        .init(letter: "ج", angle: 180),
        .init(letter: "غ", angle: 270),
    ]

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

    /// أقرب زاوية مكافئة للهدف انطلاقًا من الزاوية الحالية (الفرق ضمن ±١٨٠°)،
    /// حتى يسلك الدوران الطريق الأقصر بدل الالتفاف الكامل.
    private static func unwound(_ current: Double, toward target: Double) -> Double {
        var d = (target - current).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 } else if d < -180 { d += 360 }
        return current + d
    }

    /// ما يُرسم فعلًا: الزاوية المفكوكة إن وُجدت، وإلا الزاوية الخام.
    private var arrowRotation: Double { shownArrow ?? arrowAngle }
    private var dialRotation: Double { shownDial ?? -(compass.heading ?? 0) }

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
        .navigationTitle(loc("القبلة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .onAppear { compass.start() }
        .onDisappear { compass.stop() }
        .onChange(of: offBy) { _, off in
            guard let off else { return }
            // اهتزازة واحدة عند الانطباق (≤٤°)، ولا تعود إلا بعد ابتعاد حقيقي (>١٢°).
            // نراقب الزاوية لا الحالة، لأن اهتزاز اليد حول الحدّ يقلب الحالة كل ثانية مرارًا.
            if off <= 4, !didAlignHaptic {
                Haptics.done(enabled: store.hapticsEnabled)
                didAlignHaptic = true
            } else if off > 12 {
                didAlignHaptic = false
            }
        }
        .onChange(of: arrowAngle) { old, new in
            shownArrow = Self.unwound(shownArrow ?? old, toward: new)
        }
        .onChange(of: compass.heading) { old, new in
            shownDial = Self.unwound(shownDial ?? -(old ?? 0), toward: -(new ?? 0))
        }
        .sheet(isPresented: $showCityPicker) {
            if let location {
                // الأوراق لا ترث اتجاه التخطيط من الجذر، فنثبّته صراحةً كما في شاشة الصلاة.
                LocationPickerView(location: location)
                    .environment(\.layoutDirection,
                                 AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
            }
        }
    }

    /// يفتح منتقي الموقع، ويُنشئ مزوّد الموقع عند أول مرة.
    private func openCityPicker() {
        if location == nil { location = LocationProvider(store: store) }
        showCityPicker = true
    }

    // MARK: البوصلة

    // ملاحظة: حركة البوصلة تتبع قراءة الحسّاس المستمرة لا حدثًا، فمدتها
    // قصيرة ثابتة (٠٫٢٥ث) لتلاحق الدوران بسلاسة دون أن تتخلّف عن اليد.
    private var dial: some View {
        ZStack {
            // وجه البوصلة: سطح مرفوع، بريق علوي يمنحه حجمًا، وإطار خارجي متدرّج خلف التدريج
            Circle()
                .fill(Theme.surface)
                .overlay(
                    Circle().fill(
                        RadialGradient(colors: [Color.white.opacity(scheme == .dark ? 0.10 : 0.55), .clear],
                                       center: .top, startRadius: 0, endRadius: 210)
                    )
                )
                .overlay(
                    Circle().strokeBorder(
                        AngularGradient(colors: [Theme.gold.opacity(0.30),
                                                 Theme.accent.opacity(0.18),
                                                 Theme.gold.opacity(0.30)],
                                        center: .center),
                        lineWidth: 14)
                )
                .overlay(Circle().strokeBorder(Theme.hairline.opacity(0.7), lineWidth: 1))
                .atharElevation(.e2)

            // علامة مائية: نجمة ثمانية باهتة جدًا في القلب خلف السهم
            EightPointStar(innerRatio: 0.68)
                .fill(Theme.gold.opacity(0.04))
                .frame(width: 148, height: 148)

            // تدريج كل ١٥ درجة، يدور مع الجهاز
            ForEach(0..<24, id: \.self) { i in
                let major = i % 6 == 0
                Capsule()
                    .fill(major ? Theme.inkSoft : Theme.hairline)
                    .frame(width: major ? 2.5 : 1.5, height: major ? 14 : 8)
                    .offset(y: -128)
                    .rotationEffect(.degrees(Double(i) * 15))
            }
            .rotationEffect(.degrees(dialRotation))
            .animation(.smooth(duration: 0.25), value: dialRotation)

            // حروف الجهات الأربع، تدور مع الجهاز — الشمال أبرزها والبقية مُلمَّحة
            ForEach(cardinalMarks) { mark in
                Text(mark.letter)
                    .font(Theme.display(mark.angle == 0 ? 13 : 12, weight: mark.angle == 0 ? .bold : .semibold))
                    .foregroundStyle(Theme.inkSoft.opacity(mark.angle == 0 ? 1 : 0.4))
                    .offset(y: -152)
                    .rotationEffect(.degrees(mark.angle))
            }
            .rotationEffect(.degrees(dialRotation))
            .animation(.smooth(duration: 0.25), value: dialRotation)

            // علامة القبلة الثابتة على الإطار — ماسة ذهبية عند زاوية القبلة، تدور مع القرص
            Image(systemName: "diamond.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.gold)
                .shadow(color: Theme.gold.opacity(0.35), radius: 3)
                .offset(y: -142)
                .rotationEffect(.degrees(arrowRotation))
                .animation(.smooth(duration: 0.25), value: arrowRotation)

            // سهم القبلة — أكبر عنصر في الشاشة، فيلبس لون الطابع دائمًا لا عند الانطباق فقط.
            // الانطباق يزيد شدّة الظلّ والتوهّج، ولا يغيّر اللون (الذهبي يبقى للزخرفة الصغيرة).
            QiblaArrow()
                .fill(Theme.accentGradient)
                .frame(width: 46, height: 128)
                .shadow(color: Theme.accent.opacity(isAligned ? 0.30 : 0.18),
                        radius: isAligned ? 8 : 5, y: 3)
                .overlay(alignment: .top) {
                    Circle()
                        .fill(Theme.accent)
                        .opacity(isAligned ? 1 : 0.75)
                        .frame(width: 7, height: 7)
                        .blur(radius: 2)
                        .offset(y: -2)
                }
                .offset(y: -46)
                .rotationEffect(.degrees(arrowRotation))
                .animation(.smooth(duration: 0.25), value: arrowRotation)
                .animation(.smooth(duration: 0.2), value: isAligned)

            // القلب: الكعبة — توهّج محيطي عند الانطباق، وهالة تتمدّد مرّة واحدة احتفاءً
            ZStack {
                if isAligned, !reduceMotion {
                    QiblaAlignHalo(tint: Theme.accent)
                }
                Circle()
                    .fill(isAligned ? Theme.accentSoft : Theme.surfaceAlt)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(Theme.accent.opacity(isAligned ? 0.22 : 0))
                            .frame(width: 82, height: 82)
                            .blur(radius: 10)
                    )
                    .overlay(Circle().strokeBorder(Theme.accent.opacity(isAligned ? 0.4 : 0), lineWidth: 1.5))
                    .overlay(
                        Image(systemName: "cube.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(isAligned ? Theme.accent : Theme.inkSoft)
                    )
                    .animation(.smooth(duration: 0.25), value: isAligned)
            }
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
                Label(loc("أنت تواجه القبلة"), systemImage: "checkmark.seal.fill")
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Theme.accentSoft))
                    .transition(.scale.combined(with: .opacity))
            } else if let off = offBy {
                Text(String(format: loc("أدِر الجهاز %.0f° %@"), off,
                            turnDirection == .right ? loc("يمينًا") : loc("يسارًا")))
                    .font(Theme.display(13, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .monospacedDigit()
            }

            // رقاقة الموقع/المسافة — بنفس نبرة رقاقات الصلاة، تربط الشاشتين معًا.
            // وهي زرّ يفتح منتقي الموقع، فالاتجاه كلّه مبنيّ على هذا الموقع ولا بدّ من طريق لتغييره.
            Button { openCityPicker() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text(store.placeName)
                    Text("·")
                    Text(distanceText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
                .font(Theme.display(12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Theme.accentSoft))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("الموقع: %1$@ — اضغط لتغييره", store.placeName))
            .padding(.top, 4)
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
                Text(loc("أنت عند الكعبة"))
                    .font(Theme.display(22, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("استقبل البيت مباشرة — لا حاجة إلى بوصلة."))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var unavailableCard: some View {
        AtharCard(padding: 22) {
            Text(loc("تعذّر تحديد اتجاه القبلة لهذا الموقع."))
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
             loc("البوصلة تحتاج معايرة — حرّك الجهاز على هيئة الرقم ٨ في الهواء، وابتعد عن المعادن والمغانط."),
             color: Theme.gold)
    }

    private var noCompassNote: some View {
        note("exclamationmark.triangle.fill",
             loc("لا توجد بوصلة في هذا الجهاز، فالسهم ثابت. استعن بزاوية القبلة أعلاه مع بوصلة أخرى."),
             color: Theme.gold)
    }

    private var magneticNote: some View {
        note("info.circle.fill",
             loc("القراءة بالشمال المغناطيسي لأن خدمات الموقع مغلقة. فعّل الموقع لقراءة أدق بالشمال الحقيقي."),
             color: Theme.inkFaint)
    }

    private var accuracyNote: some View {
        Text(loc("الاتجاه محسوب بالدائرة العظمى إلى الكعبة من موقعك المحدَّد. دقّته تتبع دقّة موقعك ودقّة بوصلة جهازك."))
            .font(Theme.display(11))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}

/// حرف جهة على قرص البوصلة مع زاويته من الشمال.
private struct QiblaCardinal: Identifiable {
    let letter: String
    let angle: Double
    var id: String { letter }
}

/// هالة تتمدّد مرّة واحدة خلف الكعبة لحظة الانطباق ثم تتلاشى (٠٫٦ ← ١٫٤، ٠٫٢٨ ← ٠).
/// تُركَّب فقط حين ينطبق الاتجاه ومع تعطيل «تقليل الحركة»، فتُشغَّل حركتها عند الظهور.
private struct QiblaAlignHalo: View {
    var tint: Color
    @State private var expand = false

    var body: some View {
        Circle()
            .fill(tint.opacity(0.28))
            .frame(width: 72, height: 72)
            .scaleEffect(expand ? 1.4 : 0.6)
            .opacity(expand ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.5)) { expand = true } }
            .allowsHitTesting(false)
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
