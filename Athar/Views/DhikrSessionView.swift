import SwiftUI
import WidgetKit

/// The reading screen: one dhikr at a time, tap anywhere to count down.
struct DhikrSessionView: View {
    let category: DhikrCategory
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var remaining: [String: Int] = [:]
    @State private var showCompletion = false

    private var color: Color { Theme.accent(for: category.accent) }
    // حارس ضدّ فهرس سالب لو كانت الفئة فارغة (غير ممكن ببيانات مُدرجة، لكن احتياطًا).
    private var current: Dhikr { category.items[max(0, min(index, category.items.count - 1))] }
    private var left: Int { remaining[current.id] ?? current.count }

    private var overallProgress: Double {
        let total = category.totalRepetitions
        guard total > 0 else { return 0 }
        let doneCount = category.items.reduce(0) { acc, item in
            acc + (item.count - (remaining[item.id] ?? item.count))
        }
        return Double(doneCount) / Double(total)
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: color)

            VStack(spacing: 0) {
                progressBar

                TabView(selection: $index) {
                    ForEach(Array(category.items.enumerated()), id: \.element.id) { i, dhikr in
                        dhikrPage(dhikr)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // الأذكار عربية دائمًا، فسحب الصفحات يبقى RTL (التالي يسارًا)
                // مهما كانت لغة الواجهة.
                .environment(\.layoutDirection, .rightToLeft)

                bottomBar
            }
        }
        // ملاحظة مستخدم: الدائرة وحدها تُلزم بمدّ الإبهام إلى أسفل الشاشة.
        .contentShape(Rectangle())
        .onTapGesture { if store.countTapArea == .screen { step() } }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button(loc("إعادة العدّ"), systemImage: "arrow.counterclockwise") { resetCounts() }
                    ShareLink(item: shareText) { Label(loc("مشاركة الذكر"), systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear(perform: seed)
        .overlay { if showCompletion { completionOverlay } }
        .animation(Motion.smooth, value: showCompletion)
    }

    // MARK: Pieces

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(Theme.gradient(for: category.accent))
                        .frame(width: max(4, geo.size.width * overallProgress))
                        .shadow(color: color.opacity(0.28), radius: 4, y: 1)
                        .animation(Motion.smooth, value: overallProgress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("\(Int(overallProgress * 100).counterText)٪")
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
                Text("\((index + 1).counterText) من \(category.items.count.counterText)")
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .readableWidth(720)
    }

    private func dhikrPage(_ dhikr: Dhikr) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AtharCard(padding: 22, elevation: .e2, tint: color) {
                    VStack(alignment: .leading, spacing: 18) {
                        // خيط علوي بلون القسم — حاشية مذهّبة تحت النص لا تنافسه
                        Capsule().fill(Theme.gradient(for: category.accent))
                            .frame(width: 44, height: 3)
                            .opacity(0.85)
                            .frame(maxWidth: .infinity)

                        Text(dhikr.text)
                            .font(Theme.dhikrFont(size: 22, scale: store.fontScale))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(14)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        if dhikr.hasReference {
                            Text(dhikr.reference)
                                .font(Theme.display(12, weight: .medium))
                                .foregroundStyle(color)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(color.opacity(0.12)))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }

                if dhikr.hasVirtue {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.gold)
                            .padding(.top, 3)
                        Text(dhikr.virtue)
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .readableWidth(720)
            .containerRelativeFrame(.vertical, alignment: .center)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            Button(action: step) {
                ZStack {
                    ProgressRing(
                        progress: 1 - Double(left) / Double(max(1, current.count)),
                        color: color, lineWidth: 7, gradient: true, glow: true
                    )
                    VStack(spacing: 0) {
                        Text(left.counterText)
                            .font(Theme.display(34, weight: .bold))
                            .foregroundStyle(left == 0 ? color : Theme.ink)
                            .contentTransition(.numericText(countsDown: true))
                        if current.count > 1 {
                            Text(loc("من %1$@", current.count.counterText))
                                .font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                }
                .frame(width: 108, height: 108)
                .background(Circle().fill(Theme.surfaceTint(color)))
                .overlay(Circle().stroke(color.opacity(0.18), lineWidth: 1))
                .contentShape(Circle())
            }
            .buttonStyle(.plain)

            Text(left == 0 ? loc("اسحب للذكر التالي") : (store.countTapArea == .screen ? loc("اضغط أي مكان للعدّ") : loc("اضغط الدائرة للعدّ")))
                .font(Theme.display(12, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.bottom, 18)
        .padding(.top, 6)
    }

    private var completionOverlay: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    CelebrationHalo(tint: color)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 62))
                        .foregroundStyle(Theme.gradient(for: category.accent))
                }
                .frame(width: 150, height: 150)
                Text(loc("تقبّل الله منك"))
                    .font(Theme.display(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("أتممت %1$@", category.title))
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.inkSoft)

                VStack(spacing: 10) {
                    Button {
                        showCompletion = false
                        dismiss()
                    } label: {
                        Text(loc("تم"))
                            .font(Theme.display(16, weight: .semibold))
                            .gradientButton(Theme.gradient(for: category.accent), glow: color)
                    }
                    .pressable()
                    Button {
                        resetCounts()
                        showCompletion = false
                    } label: {
                        Text(loc("إعادة"))
                            .font(Theme.display(15, weight: .medium))
                            .softButton(color)
                    }
                    .pressable()
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(CardSurface(radius: Theme.Radius.xl, elevation: .e3))
            .padding(36)
            .transition(.scale(scale: 0.92).combined(with: .opacity))
        }
    }

    // MARK: Logic

    private func seed() {
        guard remaining.isEmpty else { return }
        remaining = Dictionary(uniqueKeysWithValues: category.items.map { ($0.id, $0.count) })
    }

    private func step() {
        guard left > 0 else {
            advance()
            return
        }
        remaining[current.id] = left - 1
        store.totalDhikrCount += 1
        store.touchStreak()

        if remaining[current.id] == 0 {
            Haptics.done(enabled: store.hapticsEnabled)
            if isCategoryComplete {
                store.markCompleted(categoryId: category.id)
                WidgetCenter.shared.reloadAllTimelines()
                showCompletion = true
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { advance() }
            }
        } else {
            Haptics.step(enabled: store.hapticsEnabled)
        }
    }

    private var isCategoryComplete: Bool {
        category.items.allSatisfy { (remaining[$0.id] ?? $0.count) == 0 }
    }

    private func advance() {
        guard index < category.items.count - 1 else { return }
        withAnimation(Motion.smooth) { index += 1 }
    }

    private func resetCounts() {
        withAnimation {
            remaining = Dictionary(category.items.map { ($0.id, $0.count) }, uniquingKeysWith: { first, _ in first })
            index = 0
        }
    }

    private var shareText: String {
        current.text + (current.hasReference ? "\n\n\(current.reference)" : "") + "\n\nمن تطبيق أثر"
    }
}
