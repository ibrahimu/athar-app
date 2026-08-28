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
