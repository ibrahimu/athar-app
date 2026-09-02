import SwiftUI
import WidgetKit

struct TasbihView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var pulse = false

    private let phrases = [
        "سُبْحَانَ اللهِ",
        "الْحَمْدُ للهِ",
        "لَا إِلَهَ إِلَّا اللهُ",
        "اللهُ أَكْبَرُ",
        "أَسْتَغْفِرُ اللهَ",
        "لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللهِ",
        "اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ",
        "سُبْحَانَ اللهِ وَبِحَمْدِهِ"
    ]
    private let targets = [33, 100, 500, 1000]

    private var progress: Double {
        Double(store.tasbihCount % store.tasbihTarget) / Double(store.tasbihTarget)
    }
    private var rounds: Int { store.tasbihCount / store.tasbihTarget }

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground()

                VStack(spacing: 20) {
                    phrasePicker
                    Spacer(minLength: 0)
                    counter
                    Spacer(minLength: 0)
                    targetPicker
                    controls
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .readableWidth(560)
            }
            .contentShape(Rectangle())
            .onTapGesture { if store.countTapArea == .screen { increment() } }
            .navigationTitle("المسبحة")
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
                            .foregroundStyle(selected ? .white : Theme.inkSoft)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(
                                Capsule().fill(selected ? Theme.accent : Theme.surface)
                            )
                            .overlay(Capsule().stroke(selected ? .clear : Theme.hairline))
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
                Circle()
                    .fill(Theme.accent.opacity(0.06))
                    .scaleEffect(pulse ? 1.06 : 1)
                ProgressRing(progress: progress, color: Theme.accent, lineWidth: 14)
                    .padding(16)

                VStack(spacing: 8) {
                    Text(store.tasbihPhrase)
                        .font(Theme.dhikrFont(size: 19))
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 34)

                    Text((store.tasbihCount % store.tasbihTarget).counterText)
                        .font(.system(size: 68, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())

                    Text("الهدف \(store.tasbihTarget.counterText)")
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
                    store.tasbihTarget = target
                    Haptics.tap(enabled: store.hapticsEnabled)
                } label: {
                    Text(target.counterText)
                        .font(Theme.display(14, weight: .semibold))
                        .foregroundStyle(selected ? .white : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selected ? Theme.accent : Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? .clear : Theme.hairline))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                store.tasbihCount = 0
                Haptics.tap(enabled: store.hapticsEnabled)
            } label: {
                Label("تصفير", systemImage: "arrow.counterclockwise")
                    .font(Theme.display(14, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hairline))
                    .foregroundStyle(Theme.inkSoft)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Text("الأشواط")
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkFaint)
                Text(rounds.counterText)
                    .font(Theme.display(16, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accentSoft))
        }
    }

    private func increment() {
        store.tasbihCount += 1
        store.totalDhikrCount += 1
        store.touchStreak()

        withAnimation(.spring(duration: 0.18)) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(duration: 0.18)) { pulse = false }
        }

        if store.tasbihCount % store.tasbihTarget == 0 {
            Haptics.done(enabled: store.hapticsEnabled)
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            Haptics.step(enabled: store.hapticsEnabled)
        }
    }
}
