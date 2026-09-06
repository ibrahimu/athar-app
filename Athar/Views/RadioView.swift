import SwiftUI

/// إذاعة القرآن الكريم شاشةً مستقلّة: غلاف كبير وزرّ واحد. المشغّل هو RadioPlayer المشترك
/// نفسه الذي تستعمله بطاقة «البث المباشر»، فالبثّ يستمرّ في الخلفية وعلى شاشة القفل
/// أيًّا كان القسم الذي بدأ منه، ولا يُفتح اتصال إلا بضغطة «تشغيل».
struct RadioView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false
    @ObservedObject private var radio = RadioPlayer.shared

    private var tint: Color { Theme.accent(for: "sea") }
    private let source: LiveSource = .radio

    private var isThisSource: Bool { radio.source?.id == source.id }
    private var playing: Bool { isThisSource && radio.isPlaying }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 18) {
                    player.appearStagger(0)
                    note.appearStagger(1)
                    NavigationLink { LiveView() } label: {
                        AtharLinkRow(icon: "dot.radiowaves.left.and.right", tint: tint,
                                     title: loc("البث المباشر"),
                                     subtitle: loc("بثّ الحرمين الشريفين من قناتيهما الرسميتين"))
                    }
                    .pressable()
                    .appearStagger(2)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("إذاعة القرآن"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }

    // MARK: المشغّل

    private var player: some View {
        AtharCard(padding: 18, elevation: .e2, tint: tint) {
            VStack(spacing: 16) {
                artwork
                VStack(spacing: 6) {
                    Text(source.title)
                        .font(Theme.display(22, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(source.subtitle)
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    RadioLivePill(color: Theme.danger)
                        .padding(.top, 2)
                }
                playButton
                status
                if isThisSource {
                    // الإنهاء بيد المستخدم لا بمغادرة الشاشة: البثّ يستمرّ في الخلفية كالتلاوة.
                    Button {
                        Haptics.tap(enabled: store.hapticsEnabled)
                        radio.stop()
                    } label: {
                        Label(loc("إنهاء البثّ"), systemImage: "stop.fill")
                            .font(Theme.display(13, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                    }
                    .pressable()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// غلاف شاشة القفل نفسه، مصبوغًا بلون القسم كي لا يبدو صورةً غريبة عن بقية البطاقة.
    private var artwork: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        return Image("NowPlayingArt")
            .resizable()
            .scaledToFill()
            .frame(width: 168, height: 168)
            .overlay(
                LinearGradient(colors: [tint.opacity(0.10), tint.opacity(0.42)],
                               startPoint: .top, endPoint: .bottom)
            )
            .clipShape(shape)
            .overlay(shape.strokeBorder(tint.opacity(0.22), lineWidth: 0.5))
            .shadow(color: tint.opacity(playing ? 0.35 : 0.14), radius: playing ? 22 : 12, y: 8)
            .animation(Motion.smooth, value: playing)
            .accessibilityHidden(true)
    }

    /// زرّ دائري كبير: متدرّج متوهّج أثناء البثّ (كأزرار gradientButton)، وناعم حين يكون متوقّفًا.
    private var playButton: some View {
        Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            if playing { radio.pause() } else if isThisSource { radio.resume() } else { radio.play(source) }
        } label: {
            ZStack {
                if playing {
                    Circle()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.82)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: tint.opacity(0.32), radius: 14, y: 6)
                } else {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .overlay(Circle().strokeBorder(tint.opacity(0.18), lineWidth: 0.5))
                }
                Image(systemName: playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(playing ? Theme.onAccent : tint)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 96, height: 96)
        }
        .pressable()
        .animation(Motion.snappy, value: playing)
        .accessibilityLabel(playing ? loc("إيقاف مؤقّت") : loc("تشغيل"))
    }

    /// سطر الحالة من المشغّل نفسه لا من ظنّ الواجهة: اتصال، بثّ، توقّف، أو خطأ.
    @ViewBuilder
    private var status: some View {
        if isThisSource, let err = radio.error {
            Text(err)
                .font(Theme.display(12))
                .foregroundStyle(Theme.danger)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        } else if isThisSource, radio.isBuffering {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small).tint(tint)
                Text(loc("جارٍ الاتصال…"))
            }
            .font(Theme.display(12))
            .foregroundStyle(Theme.inkSoft)
        } else if playing {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.system(size: 11, weight: .semibold))
                    .symbolEffect(.variableColor.iterative, isActive: true)
                Text(loc("يُبثّ الآن"))
            }
            .font(Theme.display(12, weight: .semibold))
            .foregroundStyle(tint)
        } else {
            Text(loc("متوقّف"))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
        }
    }

    private var note: some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(icon: "lock.iphone", tint: tint, size: .md)
            Text(loc("يستمر في الخلفية وتتحكّم به من شاشة القفل"))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - شارة «مباشر»

/// نقطة حمراء وكلمة — اللون يُمرَّر قيمةً ليُعاد رسمها مع تبديل الطابع (نظيرة شارة «البث المباشر»).
struct RadioLivePill: View {
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(loc("مباشر"))
        }
        // 11 هو الحدّ الأدنى للتسميات في نظام التصميم.
        .font(Theme.display(11, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}
