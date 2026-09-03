import SwiftUI

/// اختيار صوت الأذان مع الاستماع داخل القائمة نفسها: يقارن المستخدم بين
/// الأصوات قبل أن يقرّر، لذا لا يُغلق الاختيارُ الشاشةَ — زرّ «تم» يفعل ذلك.
/// تُدفع داخل مكدّس الإعدادات، فلا تنشئ مكدّسًا خاصًّا بها.
struct AthanSoundPicker: View {
    @EnvironmentObject private var store: AtharStore
    // بالنمط نفسه الذي تراقب به بقية الشاشات المفردات المشتركة (Recitation.shared).
    @StateObject private var preview = AthanPreview.shared
    @Environment(\.dismiss) private var dismiss

    /// يُستدعى عند تغيّر الاختيار — ليعيد الأبُ جدولة تنبيهات الأذان بالصوت الجديد.
    var onChange: () -> Void = {}

    private var tint: Color { Theme.accent(for: "dusk") }
    private let options = AthanSound.allCases

    var body: some View {
        ZStack {
            AtharBackground(tint: tint)
            ScrollView {
                VStack(spacing: 10) {
                    SettingsCard {
                        ForEach(Array(options.enumerated()), id: \.element.id) { i, sound in
                            row(sound)
                            if i < options.count - 1 { SettingsDivider(inset: 46) }
                        }
                    }
                    footnote
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("صوت الأذان"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(loc("done")) { dismiss() } } }
        // مغادرة الشاشة توقف الاستماع: لا يبقى أذان يعمل خلف شاشة أخرى.
        .onDisappear { preview.stop() }
    }

    // MARK: - صف صوت

    private func row(_ sound: AthanSound) -> some View {
        let selected = store.athanSound == sound
        let isPlaying = preview.playing == sound

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    guard !selected else { return }
                    store.athanSound = sound
                    Haptics.tap(enabled: store.hapticsEnabled)
                    onChange()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(selected ? Theme.accent : Theme.hairline)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(sound.title)
                                .font(Theme.display(16, weight: selected ? .semibold : .regular))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Text(sound.detail)
                                .font(Theme.display(12))
                                .foregroundStyle(Theme.inkFaint)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])

                // نغمة النظام لا ملفّ لها فلا زرّ استماع.
                if sound != .system {
                    Button { preview.toggle(sound) } label: {
                        Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(isPlaying ? tint : Theme.accent)
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isPlaying ? loc("إيقاف الاستماع") : loc("استمع"))
                }
            }

            if isPlaying {
                Text(loc("يُشغَّل التسجيل الكامل — التنبيه يستخدم أوّل ٣٠ ثانية"))
                    .font(Theme.display(11))
                    .foregroundStyle(tint)
                    .padding(.top, 8)
                    .padding(.leading, 30)
                    .transition(.opacity)
            }
        }
        .padding(14)
        .animation(Motion.snappy, value: isPlaying)
    }

    // MARK: - حاشية

    private var footnote: some View {
        Text(loc("يصلك التنبيه بأوّل ثلاثين ثانية من الأذان المختار — حدّ iOS لأصوات الإشعارات."))
            .font(Theme.display(11))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
    }
}
