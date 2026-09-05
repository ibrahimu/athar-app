import SwiftUI

/// شريط تلاوة الآية بالآية أسفل المصحف: الموضع، القارئ، تحكّم، وتكرار للحفظ.
struct AyahPlayerBar: View {
    @ObservedObject var audio: AyahAudio
    let palette: ReadingPalette
    @EnvironmentObject private var store: AtharStore

    private var title: String {
        guard let r = audio.current, let s = Quran.surah(r.surah) else { return "" }
        return loc("%1$@ · الآية %2$@", s.name, r.ayah.counterText)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Theme.display(13, weight: .semibold)).foregroundStyle(palette.ink).lineLimit(1)
                Text(audio.isLoading ? loc("جارٍ التحميل…") : audio.reciter.name)
                    .font(Theme.display(11)).foregroundStyle(palette.ink.opacity(0.6)).lineLimit(1)
            }
            Spacer(minLength: 4)

            // زرّ التكرار: ١ ← ٣ ← ٥ ← ١٠
            Button {
                let steps = [1, 3, 5, 10]
                let i = steps.firstIndex(of: audio.repeatCount) ?? 0
                audio.repeatCount = steps[(i + 1) % steps.count]
                Haptics.tap(enabled: store.hapticsEnabled)
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "repeat").font(.system(size: 11, weight: .semibold))
                    Text(audio.repeatCount == 1 ? loc("مرة") : "×\(audio.repeatCount.counterText)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .foregroundStyle(audio.repeatCount > 1 ? palette.paper : palette.accent)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Capsule().fill(audio.repeatCount > 1 ? palette.accent : palette.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("تكرار الآية %1$@ مرات", audio.repeatCount.counterText))

            // الاتجاه ثابت LTR كأزرار المشغّل الكبير: السابق يسارًا والتالي يمينًا.
            HStack(spacing: 2) {
                control("backward.end.fill", label: loc("الآية السابقة")) { audio.previous() }
                control(audio.isPlaying ? "pause.fill" : "play.fill", size: 18, label: audio.isPlaying ? loc("إيقاف مؤقت") : loc("تشغيل")) { audio.toggle() }
                control("forward.end.fill", label: loc("الآية التالية")) { audio.next() }
            }
            .environment(\.layoutDirection, .leftToRight)

            control("xmark", size: 12, label: loc("إنهاء التلاوة")) { audio.stop() }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(palette.paper)
                .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .strokeBorder(palette.accent.opacity(0.25), lineWidth: 0.7))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func control(_ icon: String, size: CGFloat = 14, label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
