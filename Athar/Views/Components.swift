import SwiftUI

// MARK: - Screen background

struct AtharBackground: View {
    var body: some View {
        Theme.canvas
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Theme.accent.opacity(0.10), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()
    }
}

// MARK: - Card

struct AtharCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }
}

// MARK: - Progress ring

struct ProgressRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.smooth(duration: 0.35), value: progress)
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)?
    var actionTitle: String = "الكل"

    var body: some View {
        HStack {
            Text(title)
                .font(Theme.display(19, weight: .bold))
                .foregroundStyle(Theme.ink)
            Spacer()
            if let action {
                Button(actionTitle, action: action)
                    .font(Theme.display(14, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
    }
}

// MARK: - Readable width

extension View {
    /// Caps content at a comfortable measure so iPad does not stretch cards edge to edge.
    func readableWidth(_ max: CGFloat = 680) -> some View {
        frame(maxWidth: max)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func step(enabled: Bool) {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    static func done(enabled: Bool) {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Settings building blocks
//
// شاشة الإعدادات كانت Form افتراضيًا وسط تصميم مخصص. هذه اللبنات تجعلها
// من نفس نسيج بقية التطبيق: بطاقات هادئة، فواصل شعرية، ومساحة تتنفّس.

/// عنوان مجموعة: صغير، خافت، ومتباعد الحروف.
struct SettingsGroupTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.display(12, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Theme.inkFaint)
            .padding(.horizontal, 6)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// بطاقة تضمّ صفوفًا، بفواصل شعرية بينها تلقائيًا.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }
}

/// فاصل شعري مُزاح ليحاذي بداية النص لا حافة البطاقة.
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
            .padding(.leading, 60)
    }
}

/// صف إعداد: أيقونة في دائرة ملوّنة ناعمة، عنوان، ووصف اختياري، ثم عنصر التحكم.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.display(16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, tint: Color = Theme.accent, title: String, subtitle: String? = nil) {
        self.init(icon: icon, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// قيمة نصية هادئة في نهاية الصف.
struct SettingsValue: View {
    let text: String
    var body: some View {
        Text(text)
            .font(Theme.display(15, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            .monospacedDigit()
    }
}

// MARK: - Settings picker
//
// القوائم المنسدلة كانت تلتف وتغطّي الصفوف تحتها حين يطول اسم الخيار.
// هذا الصف يعرض المختار مختصرًا، ويفتح شاشة اختيار مريحة فيها الشرح كاملًا.

protocol SettingsChoice: Hashable, Identifiable {
    var title: String { get }
    var shortTitle: String { get }
    var detail: String { get }
}

struct SettingsPickerRow<T: SettingsChoice>: View {
    let icon: String
    var tint: Color = Theme.accent
    let title: String
    let options: [T]
    @Binding var selection: T

    var body: some View {
        NavigationLink {
            SettingsChoiceList(title: title, options: options, selection: $selection)
        } label: {
            SettingsRow(icon: icon, tint: tint, title: title) {
                HStack(spacing: 6) {
                    Text(selection.shortTitle)
                        .font(Theme.display(15, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .lineLimit(1)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsChoiceList<T: SettingsChoice>: View {
    let title: String
    let options: [T]
    @Binding var selection: T
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                VStack(spacing: 8) {
                    SettingsCard {
                        ForEach(Array(options.enumerated()), id: \.element.id) { i, option in
                            Button {
                                selection = option
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: selection == option ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundStyle(selection == option ? Theme.accent : Theme.hairline)
                                        .padding(.top, 1)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(option.title)
                                            .font(Theme.display(16, weight: selection == option ? .semibold : .regular))
                                            .foregroundStyle(Theme.ink)
                                            .multilineTextAlignment(.leading)
                                        Text(option.detail)
                                            .font(Theme.display(12))
                                            .foregroundStyle(Theme.inkFaint)
                                            .multilineTextAlignment(.leading)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(14)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if i < options.count - 1 { SettingsDivider() }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }
}
