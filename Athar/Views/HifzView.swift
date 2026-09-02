import SwiftUI

/// مراحل تلقين الآية: يقرأها، ثم بأوائل الحروف، ثم من حفظه.
enum HifzStage {
    case reading      // النص كاملًا — يكرّره
    case hinted       // أوائل الكلمات فقط
    case testing      // مخفيّ — يسترجع من حفظه
    case revealed     // كشف بعد التعثّر
}

struct HifzView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var queue: [AyahRef] = []
    @State private var index = 0
    @State private var stage: HifzStage = .reading
    @State private var repeatsLeft = 0
    @State private var showPicker = false
    @State private var sessionPassed = 0
    @State private var sessionStumbled = 0

    private var current: AyahRef? { index < queue.count ? queue[index] : nil }

    var body: some View {
        ZStack {
            AtharBackground()
            if queue.isEmpty {
                emptyState
            } else if let ref = current {
                session(ref)
            } else {
                finished
            }
        }
        .navigationTitle("الحفظ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showPicker = true } label: { Image(systemName: "plus.circle") }
            }
        }
        .sheet(isPresented: $showPicker) {
            HifzPicker { refs in
                for r in refs where store.card(for: r) == nil {
                    store.recordReview(r, passed: false)   // تدخل الطابور اليوم
                }
                loadQueue()
            }
        }
        .onAppear(perform: loadQueue)
    }

    // MARK: الجلسة

    private func session(_ ref: AyahRef) -> some View {
        VStack(spacing: 0) {
            progressBar

            ScrollView {
                VStack(spacing: 20) {
                    Text("\(Quran.surah(ref.surah)?.name ?? "") · الآية \(ref.ayah.counterText)")
                        .font(Theme.display(13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.top, 8)

                    AtharCard(padding: 22) {
                        Group {
                            switch stage {
                            case .reading, .revealed:
                                Text(Quran.text(ref) ?? "")
                            case .hinted:
                                Text(hint(for: ref))
                            case .testing:
                                Text("· · ·")
                                    .foregroundStyle(Theme.inkFaint)
                            }
                        }
                        .font(Theme.dhikrFont(size: 23, scale: store.mushafFontScale))
                        .foregroundStyle(stage == .revealed ? Theme.accent : Theme.ink)
                        .lineSpacing(15)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .animation(Motion.snappy, value: stage)
                    }

                    stageHint

                    if let card = store.card(for: ref), card.lapses > 0 {
                        Label("تعثّرت فيها \(card.lapses.counterText) مرة — كرّرها",
                              systemImage: "arrow.trianglehead.counterclockwise")
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.gold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)

            controls(ref)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent.opacity(0.15))
                    Capsule().fill(Theme.accent)
                        .frame(width: max(4, g.size.width * Double(index) / Double(max(1, queue.count))))
                        .animation(Motion.smooth, value: index)
                }
            }
            .frame(height: 6)
            HStack {
                Text("\((index + 1).counterText) من \(queue.count.counterText)")
                Spacer()
                if sessionStumbled > 0 {
                    Text("تعثّر \(sessionStumbled.counterText)")
                        .foregroundStyle(Theme.gold)
                }
            }
            .font(Theme.display(12, weight: .medium))
            .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var stageHint: some View {
        switch stage {
        case .reading:
            Text(repeatsLeft > 0
                 ? "اقرأها بصوتك — بقي \(repeatsLeft.counterText) من \(store.hifzRepeatCount.counterText)"
                 : "أحسنت — انتقل للتلميح")
                .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
        case .hinted:
            Text("أوائل الكلمات — أكملها من حفظك")
                .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
        case .testing:
            Text("استرجعها كاملة من حفظك")
                .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
        case .revealed:
            Text("لا بأس — اقرأها مرة أخرى، وستعود عليك قريبًا")
                .font(Theme.display(13)).foregroundStyle(Theme.gold)
        }
    }

    private func controls(_ ref: AyahRef) -> some View {
        VStack(spacing: 10) {
            switch stage {
            case .reading:
                bigButton(repeatsLeft > 0 ? "قرأتها" : "التالي", Theme.accent) {
                    Haptics.step(enabled: store.hapticsEnabled)
                    if repeatsLeft > 1 { repeatsLeft -= 1 }
                    else { repeatsLeft = 0; stage = .hinted }
                }
            case .hinted:
                bigButton("أخفِ الكل", Theme.accent) {
                    Haptics.step(enabled: store.hapticsEnabled)
                    stage = .testing
                }
            case .testing:
                HStack(spacing: 10) {
                    smallButton("علقت", Theme.gold) {
                        Haptics.tap(enabled: store.hapticsEnabled)
                        store.recordReview(ref, passed: false)
                        sessionStumbled += 1
                        stage = .revealed
                    }
                    smallButton("تذكرتها", Theme.accent) {
                        Haptics.done(enabled: store.hapticsEnabled)
                        store.recordReview(ref, passed: true)
                        sessionPassed += 1
                        advance()
                    }
                }
            case .revealed:
                bigButton("أعِدها الآن", Theme.gold) {
                    // «إذا علق يعيدها» — ترجع الآية نفسها من أولها.
                    repeatsLeft = store.hifzRepeatCount
                    stage = .reading
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private func bigButton(_ title: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.display(16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(tint))
        }
        .buttonStyle(.plain)
    }

    private func smallButton(_ title: String, _ tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.display(16, weight: .semibold))
                .foregroundStyle(tint == Theme.accent ? .white : tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint == Theme.accent ? tint : tint.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: الحالات

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(Theme.accent.opacity(0.5))
            Text("ابدأ حفظك")
                .font(Theme.display(22, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("اختر سورة أو مدى من الآيات، ونلقّنك إياها بالتكرار ثم التلميح ثم الاسترجاع.\nوما تعثّرت فيه يعود عليك حتى يثبت.")
                .font(Theme.display(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
            Button { showPicker = true } label: {
                Label("اختر ما تحفظ", systemImage: "plus")
                    .font(Theme.display(16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 26).padding(.vertical, 14)
                    .background(Capsule().fill(Theme.accent))
            }
            .buttonStyle(.plain)

            if store.memorizedCount > 0 {
                Text("\(store.memorizedCount.counterText) آية ثبتت معك")
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 6)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56)).foregroundStyle(Theme.accent)
            Text("أتممت مراجعة اليوم")
                .font(Theme.display(22, weight: .bold)).foregroundStyle(Theme.ink)
            Text("ثبت \(sessionPassed.counterText) · تعثّر \(sessionStumbled.counterText)")
                .font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
            Text("المتعثّر يعود عليك اليوم، وما ثبت يعود بعد أيام.")
                .font(Theme.display(12)).foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button { loadQueue() } label: {
                Text("تحديث")
                    .font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain).padding(.top, 4)
        }
    }

    // MARK: المنطق

    private func loadQueue() {
        queue = store.dueForReview
        index = 0
        sessionPassed = 0
        sessionStumbled = 0
        startAyah()
    }

    private func startAyah() {
        guard let ref = current else { return }
        // الجديدة والمتعثّرة تبدأ بالتلقين؛ الثابتة تُختبر مباشرة.
        let box = store.card(for: ref)?.box ?? 0
        stage = box == 0 ? .reading : .testing
        repeatsLeft = box == 0 ? store.hifzRepeatCount : 0
    }

    private func advance() {
        if index + 1 < queue.count {
            index += 1
            startAyah()
        } else {
            // أعد تحميل ما بقي مستحقًا اليوم (المتعثّر عاد للطابور)
            let remaining = store.dueForReview
            if remaining.isEmpty || remaining == queue {
                index = queue.count
            } else {
                queue = remaining
                index = 0
                startAyah()
            }
        }
    }

    /// أوائل الحروف: يبقي أول حرف من كل كلمة ويستبدل الباقي بنقاط.
    private func hint(for ref: AyahRef) -> String {
        (Quran.text(ref) ?? "").ayahWords.map { w in
            let bare = w.strippedForSearch
            guard let first = bare.first else { return w }
            return bare.count <= 1 ? String(first) : "\(first)ـ"
        }.joined(separator: " ")
    }
}
