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
    private var current: Dhikr { category.items[min(index, category.items.count - 1)] }
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
            AtharBackground()

            VStack(spacing: 0) {
                progressBar

                TabView(selection: $index) {
                    ForEach(Array(category.items.enumerated()), id: \.element.id) { i, dhikr in
                        dhikrPage(dhikr)
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .environment(\.layoutDirection, .rightToLeft)

                bottomBar
            }
        }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("إعادة العدّ", systemImage: "arrow.counterclockwise") { resetCounts() }
                    ShareLink(item: shareText) { Label("مشاركة الذكر", systemImage: "square.and.arrow.up") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear(perform: seed)
        .overlay { if showCompletion { completionOverlay } }
        .animation(.smooth, value: showCompletion)
    }

    // MARK: Pieces

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule().fill(color)
                        .frame(width: max(4, geo.size.width * overallProgress))
                        .animation(.smooth(duration: 0.3), value: overallProgress)
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
                AtharCard(padding: 22) {
                    VStack(alignment: .leading, spacing: 18) {
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
                        color: color, lineWidth: 7
                    )
                    VStack(spacing: 0) {
                        Text(left.counterText)
                            .font(Theme.display(34, weight: .bold))
                            .foregroundStyle(left == 0 ? color : Theme.ink)
                            .contentTransition(.numericText(countsDown: true))
                        if current.count > 1 {
                            Text("من \(current.count.counterText)")
                                .font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                }
                .frame(width: 108, height: 108)
                .background(Circle().fill(Theme.surface))
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.increase, trigger: left)

            Text(left == 0 ? "اسحب للذكر التالي" : "اضغط للعدّ")
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
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 62))
                    .foregroundStyle(color)
                Text("تقبّل الله منك")
                    .font(Theme.display(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("أتممت \(category.title)")
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.inkSoft)

                VStack(spacing: 10) {
                    Button {
                        showCompletion = false
                        dismiss()
                    } label: {
                        Text("تم")
                            .font(Theme.display(16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color))
                            .foregroundStyle(.white)
                    }
                    Button {
                        resetCounts()
                        showCompletion = false
                    } label: {
                        Text("إعادة")
                            .font(Theme.display(15, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                .padding(.top, 6)
            }
            .padding(28)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.hairline))
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
        withAnimation(.smooth) { index += 1 }
    }

    private func resetCounts() {
        withAnimation {
            remaining = Dictionary(uniqueKeysWithValues: category.items.map { ($0.id, $0.count) })
            index = 0
        }
    }

    private var shareText: String {
        current.text + (current.hasReference ? "\n\n\(current.reference)" : "") + "\n\nمن تطبيق أثر"
    }
}
