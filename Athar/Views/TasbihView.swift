import SwiftUI
import WidgetKit

struct TasbihView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var pulse = false
    @State private var bloom = false        // وميض إتمام لمرّة عند بلوغ الهدف
    @State private var bloomToken = 0        // يُجدّد الوميض في كل بلوغ

    private let phrases = [
        loc("سُبْحَانَ اللهِ"),
        loc("الْحَمْدُ للهِ"),
        loc("لَا إِلَهَ إِلَّا اللهُ"),
        loc("اللهُ أَكْبَرُ"),
        loc("أَسْتَغْفِرُ اللهَ"),
        loc("لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ"),
        loc("اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ"),
        loc("سُبْحَانَ اللهِ وَبِحَمْدِهِ")
    ]
    private let targets = [33, 100, 500, 1000]

    private var progress: Double {
        Double(store.tasbihCount % store.tasbihTarget) / Double(store.tasbihTarget)
    }
    private var rounds: Int { store.tasbihCount / store.tasbihTarget }

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: Theme.accent, secondary: Theme.gold)

                VStack(spacing: Theme.Space.xl) {
                    phrasePicker.appearStagger(0)
                    Spacer(minLength: 0)
                    counter.appearStagger(1)
                    Spacer(minLength: 0)
                    targetPicker.appearStagger(2)
                    controls.appearStagger(3)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .readableWidth(560)
            }
            .contentShape(Rectangle())
            .onTapGesture { if store.countTapArea == .screen { increment() } }
            .navigationTitle(loc("المسبحة"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var phrasePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(phrases, id: \.self) { phrase in
                    let selected = store.tasbihPhrase == phrase
                    Button {
                        store.tasbihPhrase = phrase
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        Text(phrase)
                            .font(Theme.dhikrFont(size: 15))
                            .foregroundStyle(selected ? Theme.onAccent : Theme.inkSoft)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(
                                Capsule().fill(selected ? Theme.accentGradient : Theme.surfaceGradient)
                            )
                            .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 0.5))
                            .shadow(color: selected ? Theme.accent.opacity(0.25) : .clear, radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .padding(.top, 6)
    }

    private var counter: some View {
        Button(action: increment) {
            ZStack {
                // هالة ناعمة تنبض مع كل ضغطة
                Circle()
                    .fill(Theme.accent.opacity(0.06))
                    .scaleEffect(pulse ? 1.06 : 1)

                // مكافأة هادئة عند بلوغ الهدف — تظهر وتتلاشى مرّة واحدة
                if bloom {
                    CompletionBloom(tint: Theme.accent)
                        .id(bloomToken)
                }

                // حلقة العدّ: قوس متدرّج يتوهّج كلما اقترب الإتمام
                ProgressRing(progress: progress, color: Theme.accent,
                             lineWidth: 14, gradient: true, glow: true)
                    .padding(16)

                // نجمة ثمانية باهتة جدًا خلف الرقم — نسيج زخرفي لا ينافس
                EightPointStar(innerRatio: 0.68)
                    .fill(Theme.accent.opacity(0.025))
                    .frame(width: 128, height: 128)

                VStack(spacing: Theme.Space.sm) {
                    // النص الشرعي — حبريّ مهيب بخطّ النسخ، لا صبغة عليه
                    Text(store.tasbihPhrase)
                        .font(Theme.dhikrFont(size: 19))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)

                    // الرقم «جوهرة»: تعبئة متدرّجة بلون القسم
                    Text((store.tasbihCount % store.tasbihTarget).counterText)
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.7)],
                                                        startPoint: .top, endPoint: .bottom))
                        .contentTransition(.numericText())

                    Text(loc("الهدف %1$@", store.tasbihTarget.counterText))
                        .font(Theme.display(13))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
            .frame(maxWidth: 300, maxHeight: 300)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var targetPicker: some View {
        HStack(spacing: 8) {
            ForEach(targets, id: \.self) { target in
                let selected = store.tasbihTarget == target
                Button {
                    // العدّاد تراكميّ، والأشواط والرقم المعروض مشتقّان منه بالقسمة
                    // والباقي. فلو غيّرنا الهدف وحده لأُعيدت كتابة ما مضى: شوط تامّ
                    // يختفي والرقم يقفز. لذا نُرحّل الأشواط وبقيّة الشوط إلى الهدف الجديد.
                    let done = store.tasbihCount / store.tasbihTarget
                    let rest = store.tasbihCount % store.tasbihTarget
                    store.tasbihTarget = target
                    store.tasbihCount = done * target + min(rest, target - 1)
                    Haptics.tap(enabled: store.hapticsEnabled)
                } label: {
                    Text(target.counterText)
                        .font(Theme.display(14, weight: .semibold))
                        .foregroundStyle(selected ? Theme.onAccent : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .fill(selected ? Theme.accentGradient : Theme.surfaceGradient))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                            .strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 0.5))
                        .shadow(color: selected ? Theme.accent.opacity(0.22) : .clear, radius: 6, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: Theme.Space.md) {
            Button {
                store.tasbihCount = 0
                Haptics.tap(enabled: store.hapticsEnabled)
            } label: {
                Label(loc("تصفير"), systemImage: "arrow.counterclockwise")
                    .font(Theme.display(15, weight: .semibold))
                    .softButton(Theme.accent)
            }
            .pressable()

            HStack(spacing: 6) {
                Text(loc("الأشواط"))
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkFaint)
                Text(rounds.counterText)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.7)],
                                                    startPoint: .top, endPoint: .bottom))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(Theme.accentSoft)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.14), lineWidth: 0.5))
            )
        }
    }

    private func increment() {
        store.tasbihCount += 1
        store.totalDhikrCount += 1
        store.touchStreak()

        withAnimation(Motion.press) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + Motion.instant) {
            withAnimation(.smooth(duration: Motion.exit)) { pulse = false }
        }

        if store.tasbihCount % store.tasbihTarget == 0 {
            Haptics.done(enabled: store.hapticsEnabled)
            WidgetCenter.shared.reloadAllTimelines()
            // مكافأة الإتمام: وميض واحد يزهر ثم يتلاشى
            bloomToken += 1
            bloom = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                bloom = false
            }
        } else {
            Haptics.step(enabled: store.hapticsEnabled)
        }
    }
}
