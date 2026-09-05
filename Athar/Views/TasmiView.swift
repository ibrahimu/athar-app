import SwiftUI

/// التسميع: اقرأ الآية بصوتك، ويظلّل التطبيق ما صحّ وما فاتك — بلا إنترنت حين يدعم الجهاز ذلك.
struct TasmiView: View {
    let refs: [AyahRef]
    @EnvironmentObject private var store: AtharStore
    @ObservedObject private var engine = TasmiEngine.shared
    @State private var hideText = true
    @State private var index = 0

    private var tint: Color { Theme.accent(for: "hifz") }
    private var current: AyahRef { refs[min(index, refs.count - 1)] }
    private var words: [String] { (Quran.text(current) ?? "").ayahWords }
    private var states: [ArabicMatch.WordState] {
        ArabicMatch.align(target: words, spoken: engine.transcript.split(separator: " ").map(String.init))
    }
    private var score: Double { ArabicMatch.score(states) }
    private var done: Bool { !engine.listening && !engine.transcript.isEmpty }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint)
            ScrollView {
                VStack(spacing: 16) {
                    header
                    ayahCard
                    controls
                    if done { result }
                    footer
                }
                .padding(.horizontal, Theme.gutter).padding(.top, 8).padding(.bottom, 32).readableWidth(560)
            }
        }
        .navigationTitle(loc("التسميع"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { engine.reset(); _ = await engine.requestAuthorization() }
        .onDisappear { engine.stop() }
    }

    private var header: some View {
        AtharCard(padding: 14, tint: tint) {
            HStack(spacing: 12) {
                IconChip(icon: "mic.fill", tint: tint, size: .lg)
                VStack(alignment: .leading, spacing: 3) {
                    Text(loc("%1$@ · الآية %2$@", Quran.surah(current.surah)?.name ?? "", current.ayah.counterText))
                        .font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(refs.count > 1 ? loc("%1$@ من %2$@ آيات", (index + 1).counterText, refs.count.counterText)
                                        : (engine.onDevice ? loc("التعرّف على الجهاز — بلا إنترنت") : loc("التعرّف عبر خدمة Apple")))
                        .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                // المفتاح بلا اسم مرئي كان لغزًا: تسمية صغيرة فوقه تقول ما يفعله.
                VStack(spacing: 2) {
                    Text(loc("إخفاء النص")).font(Theme.display(10)).foregroundStyle(Theme.inkFaint)
                    Toggle("", isOn: $hideText).labelsHidden().tint(tint)
                        .accessibilityLabel(loc("إخفاء نصّ الآية"))
                }
            }
        }
    }

    /// كلمات الآية: مخفيّة كلوحٍ صغيرة حتى تُقرأ، ثم خضراء إن صحّت وحمراء إن فاتت.
    private var ayahCard: some View {
        AtharCard(padding: 18, elevation: .e2) {
            FlowLayout(lineSpacing: 12, wordSpacing: 6) {
                ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                    let st = i < states.count ? states[i] : .pending
                    Text(w)
                        .font(Theme.dhikrFont(size: 24, scale: store.mushafFontScale))
                        .foregroundStyle(color(for: st))
                        .opacity(hideText && st == .pending ? 0 : 1)
                        .padding(.horizontal, 3).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(background(for: st)))
                        .overlay {
                            if hideText && st == .pending {
                                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.12))
                                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(tint.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                            }
                        }
                }
            }
            .environment(\.layoutDirection, .leftToRight)   // FlowLayout يرصّ يدويًّا من اليمين
            .frame(maxWidth: .infinity)
        }
    }

    private func color(for s: ArabicMatch.WordState) -> Color {
        switch s { case .correct: return Theme.success; case .wrong, .missed: return Theme.danger; case .pending: return Theme.ink }
    }
    private func background(for s: ArabicMatch.WordState) -> Color {
        switch s { case .correct: return Theme.success.opacity(0.12); case .wrong, .missed: return Theme.danger.opacity(0.12); case .pending: return .clear }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Button {
                if engine.listening { engine.stop() } else { engine.start() }
                Haptics.tap(enabled: store.hapticsEnabled)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: engine.listening ? "stop.fill" : "mic.fill")
                    Text(engine.listening ? loc("إيقاف") : (done ? loc("أعد المحاولة") : loc("ابدأ التسميع")))
                }
                .font(Theme.display(16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .gradientButton(engine.listening ? LinearGradient(colors: [Theme.danger, Theme.danger.opacity(0.8)], startPoint: .top, endPoint: .bottom) : Theme.goldGradient, glow: engine.listening ? Theme.danger : Theme.gold)
            }
            .pressable()
            .disabled(!engine.available)
            if engine.listening {
                HStack(spacing: 6) {
                    Circle().fill(Theme.danger).frame(width: 8, height: 8)
                    Text(loc("يستمع… اقرأ الآية بصوت واضح")).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                }
            }
            if let e = engine.error { Text(e).font(Theme.display(12)).foregroundStyle(Theme.danger).multilineTextAlignment(.center) }
        }
    }

    private var result: some View {
        let pct = Int((score * 100).rounded())
        return AtharCard(padding: 16, tint: pct >= 90 ? Theme.success : (pct >= 60 ? Theme.gold : Theme.danger)) {
            VStack(spacing: 8) {
                Text("\(pct.counterText)٪").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink)
                Text(pct >= 90 ? loc("ما شاء الله — حفظٌ متقن") : (pct >= 60 ? loc("قريب — راجع ما احمرّ") : loc("أعد الحفظ ثم سمّع مرة أخرى")))
                    .font(Theme.display(14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(engine.transcript).font(Theme.display(12)).foregroundStyle(Theme.inkFaint).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if refs.count > 1 && index < refs.count - 1 {
                    Button {
                        index += 1; engine.reset(); Haptics.done(enabled: store.hapticsEnabled)
                    } label: {
                        Text(loc("الآية التالية")).font(Theme.display(14, weight: .semibold)).frame(maxWidth: .infinity).softButton(tint)
                    }
                    .pressable()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var footer: some View {
        Text(loc("التعرّف على الكلام تقريبي؛ الحكم الأخير لأذنك وأذن معلّمك. لا يُحفظ صوتك ولا يُرسل إلا حين لا يدعم الجهاز التعرّف المحلي."))
            .font(Theme.display(11)).foregroundStyle(Theme.inkFaint).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
}
