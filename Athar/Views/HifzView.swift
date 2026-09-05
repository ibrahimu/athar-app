import SwiftUI

/// مراحل تلقين الآية: يقرأها، ثم بأوائل الحروف، ثم من حفظه.
enum HifzStage {
    case reading      // النص كاملًا — يكرّره
    case hinted       // أوائل الكلمات فقط
    case testing      // مخفيّ — يسترجع من حفظه
    case revealed     // كشف بعد التعثّر
}

struct HifzView: View {
    var isRootTab = false

    @EnvironmentObject private var store: AtharStore
    @State private var queue: [AyahRef] = []
    @State private var index = 0
    @State private var stage: HifzStage = .reading
    @State private var repeatsLeft = 0
    @State private var showPicker = false
    @State private var sessionPassed = 0
    @State private var sessionStumbled = 0
    @State private var loaded = false
    @State private var loadedDay = -1

    private var current: AyahRef? { index < queue.count ? queue[index] : nil }

    // لون القسم البحري، وترتيب المراحل ولون كلٍّ منها — مصدر واحد لصبغة الشاشة.
    private var sea: Color { Theme.accent(for: "hifz") }
    private let stageOrder: [HifzStage] = [.reading, .hinted, .testing, .revealed]
    private var currentStageIndex: Int { stageOrder.firstIndex(of: stage) ?? 0 }
    private var currentAccent: Color { stageAccent(stage) }

    /// لون كل مرحلة: قراءة بحري، تلميح ذهبي، استرجاع أخضر، كشف كهرماني.
    private func stageAccent(_ s: HifzStage) -> Color {
        switch s {
        case .reading:  return Theme.accent(for: "hifz")
        case .hinted:   return Theme.gold
        case .testing:  return Theme.success
        case .revealed: return Theme.accent(for: "fajr")
        }
    }

    /// تدرّج المرحلة — لأزرارها وخيطها العلوي وحبّتها في الشريط.
    private func stageGradient(_ s: HifzStage) -> LinearGradient {
        switch s {
        case .reading:  return Theme.gradient(for: "hifz")
        case .hinted:   return Theme.gradient(for: "gold")
        case .testing:  return Theme.gradient(for: "success")
        case .revealed: return Theme.gradient(for: "fajr")
        }
    }

    private func stageLabel(_ s: HifzStage) -> String {
        switch s {
        case .reading:  return loc("اقرأ")
        // اسمٌ لا أمرٌ: في هذه المرحلة التطبيق هو الذي يلمّح والمستخدم يُكمل.
        case .hinted:   return loc("التلميح")
        case .testing:  return loc("استرجع")
        case .revealed: return loc("راجع")
        }
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: sea)
            // شاشة البداية لمن لا حفظ عنده فقط؛ ومن عنده بطاقات ولا مستحقّ اليوم يرى حالة راحة.
            if store.memoryCards.isEmpty {
                emptyState
            } else if queue.isEmpty {
                restState
            } else if let ref = current {
                session(ref)
            } else {
                finished
            }
        }
        .navigationTitle(loc("الحفظ"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let ref = current {
                    NavigationLink { TasmiView(refs: [ref]) } label: { Image(systemName: "mic.fill") }
                        .accessibilityLabel(loc("تسميع الآية"))
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button { showPicker = true } label: { Image(systemName: "plus.circle") }
                    .accessibilityLabel(loc("أضِف آيات"))
            }
        }
        .sheet(isPresented: $showPicker) {
            HifzPicker { refs in
                enroll(refs)
                loadQueue()
            }
            // الأوراق لا ترث اتجاه الواجهة من الجذر، فنفرضه صراحةً.
            .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
        // الحفظ تبويب مقيم، فلا يكفي التحميل مرة واحدة: نصون الجلسة الجارية وحدها،
        // ونعيد التحميل عند أول ظهور، أو بعد انقلاب اليوم، أو حين يكون الطابور فارغًا
        // (آيات أُضيفت من شاشة القراءة لن تصل إلى `queue` وهو @State).
        .onAppear {
            let today = AtharStore.dayNumber()
            guard !loaded || loadedDay != today || queue.isEmpty else { return }
            loaded = true
            loadedDay = today
            loadQueue()
        }
    }

    // MARK: الجلسة

    private func session(_ ref: AyahRef) -> some View {
        VStack(spacing: 0) {
            progressBar
            stageRail

            // ارتفاع أدنى لا ثابت (كما في صفحة الذكر): الآية القصيرة تتوسّط المساحة بدل أن
            // تلتصق بالأعلى ويبقى بينها وبين التوجيه والزرّ فراغ ٢٤٥ نقطة؛ والطويلة تمرّر.
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: 20) {
                        Text("\(Quran.surah(ref.surah)?.name ?? "") · الآية \(ref.ayah.counterText)")
                            .font(Theme.display(13, weight: .semibold))
                            .foregroundStyle(sea)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(Capsule().fill(sea.opacity(0.10)))
                            .padding(.top, 8)

                        ayahCard(ref)

                        if let card = store.card(for: ref), card.lapses > 0 {
                            Label(lapseText(card.lapses), systemImage: "arrow.trianglehead.counterclockwise")
                                .font(Theme.display(12, weight: .medium))
                                .foregroundStyle(Theme.gold)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(Theme.gold.opacity(0.12)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .readableWidth(620)
                    .frame(minHeight: geo.size.height, alignment: .center)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }

            // التوجيه ثابت فوق الأزرار (خارج التمرير) فلا يُقصّ خلف الزر.
            stageHint
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)

            controls(ref)
        }
    }

    // MARK: شريط التقدّم — تعبئة متدرّجة وحافة مدوّرة ونجمات أرباع تُذهَّب

    private var progressBar: some View {
        let frac = Double(index) / Double(max(1, queue.count))
        return VStack(spacing: 10) {
            GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(sea.opacity(0.14))
                    Capsule()
                        .fill(Theme.gradient(for: "hifz"))
                        .frame(width: max(6, w * frac))
                        .animation(Motion.smooth, value: index)

                    // علامات الأرباع: نجمة ثمانية تُذهَّب حين تتجاوزها التعبئة.
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { m in
                        Color.clear
                            .frame(width: max(1, w * m))
                            .overlay(alignment: .trailing) {
                                milestoneStar(lit: frac >= m - 0.0001)
                            }
                    }
                }
            }
            .frame(height: 6)

            HStack {
                Text("\((index + 1).counterText) من \(queue.count.counterText)")
                Spacer()
                if sessionStumbled > 0 {
                    Text(loc("تعثّر %1$@", sessionStumbled.counterText))
                        .foregroundStyle(Theme.gold)
                }
            }
            .font(Theme.display(12, weight: .medium))
            .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func milestoneStar(lit: Bool) -> some View {
        EightPointStar(innerRatio: 0.5)
            .fill(lit ? AnyShapeStyle(Theme.goldGradient) : AnyShapeStyle(sea.opacity(0.28)))
            .frame(width: 9, height: 9)
            .scaleEffect(lit ? 1 : 0.82)
            .animation(Motion.press, value: lit)
    }

    // MARK: شريط المراحل — أربع حبّات ملوّنة (اقرأ/التلميح/استرجع/راجع)

    private var stageRail: some View {
        HStack(spacing: 8) {
            ForEach(Array(stageOrder.enumerated()), id: \.offset) { i, s in
                let acc = stageAccent(s)
                let active = s == stage
                let passed = i < currentStageIndex

                Text(stageLabel(s))
                    .font(Theme.display(12, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? Theme.onAccent : (passed ? acc : Theme.inkFaint))
                    .lineLimit(1).minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(active ? AnyShapeStyle(stageGradient(s))
                                  : passed ? AnyShapeStyle(acc.opacity(0.18))
                                           : AnyShapeStyle(Theme.surfaceAlt))
                            .overlay(
                                Capsule().strokeBorder(
                                    (active || passed) ? Color.clear : Theme.hairline.opacity(0.6),
                                    lineWidth: 0.6)
                            )
                    )
                    .shadow(color: active ? acc.opacity(0.35) : .clear,
                            radius: active ? 8 : 0, y: active ? 3 : 0)
                    .scaleEffect(active ? 1.04 : 1)
                    .animation(Motion.press, value: stage)
            }
        }
        .animation(Motion.snappy, value: stage)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 2)
    }

    // MARK: بطاقة الآية — سطح مصبوغ بلون المرحلة، خيط علويّ، ونجمة مائية خلف النص

    private func ayahCard(_ ref: AyahRef) -> some View {
        let acc = currentAccent
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
        return Group {
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
        .foregroundStyle(Theme.ink)
        .lineSpacing(15)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 150)
        .animation(Motion.snappy, value: stage)
        .padding(22)
        .background {
            shape
                .fill(Theme.surfaceGradient)
                .overlay { shape.fill(acc.opacity(0.04)) }
                .overlay {
                    EightPointStar(innerRatio: 0.66)
                        .fill(acc.opacity(0.016))
                        .frame(width: 180, height: 180)
                }
                .overlay(alignment: .top) {
                    Rectangle().fill(acc).frame(height: 2)
                }
                .animation(Motion.gentle, value: stage)   // تلاشٍ متقاطع للصبغة مع تبدّل المرحلة
                .clipShape(shape)
                .overlay(shape.strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
                .atharElevation(.e2)
        }
    }

    @ViewBuilder
    private var stageHint: some View {
        switch stage {
        case .reading:
            Text(repeatsLeft > 0
                 ? loc("اقرأها بصوتك — بقي %1$@ من %2$@", repeatsLeft.counterText, store.hifzRepeatCount.counterText)
                 : loc("أحسنت — انتقل للتلميح"))
                .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
        case .hinted:
            Text(loc("أوائل الكلمات — أكملها من حفظك"))
                .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
        case .testing:
            Text(loc("استرجعها كاملة من حفظك"))
                .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
        case .revealed:
            Text(loc("لا بأس — اقرأها مرة أخرى، وستعود عليك قريبًا"))
                .font(Theme.display(13)).foregroundStyle(stageAccent(.revealed))
        }
    }

    // MARK: أزرار التحكّم

    private func controls(_ ref: AyahRef) -> some View {
        VStack(spacing: 10) {
            switch stage {
            case .reading:
                bigButton(repeatsLeft > 0 ? loc("قرأتها") : loc("التالي"),
                          icon: repeatsLeft > 0 ? "checkmark" : "arrow.forward",
                          gradient: stageGradient(.reading), glow: stageAccent(.reading)) {
                    Haptics.step(enabled: store.hapticsEnabled)
                    if repeatsLeft > 1 { repeatsLeft -= 1 }
                    else { repeatsLeft = 0; stage = .hinted }
                }
            case .hinted:
                bigButton(loc("أخفِ الكل"), icon: "eye.slash",
                          gradient: stageGradient(.hinted), glow: stageAccent(.hinted)) {
                    Haptics.step(enabled: store.hapticsEnabled)
                    stage = .testing
                }
            case .testing:
                HStack(spacing: 10) {
                    // علقت — زر ذهبي ناعم بسهم عكسي.
                    Button {
                        Haptics.tap(enabled: store.hapticsEnabled)
                        store.recordReview(ref, passed: false)
                        sessionStumbled += 1
                        stage = .revealed
                    } label: {
                        Label(loc("علقت"), systemImage: "arrow.counterclockwise")
                            .font(Theme.display(16, weight: .semibold))
                            .softButton(Theme.gold)
                    }
                    .pressable()

                    // تذكرتها — زر أخضر متدرّج بعلامة صحّ.
                    Button {
                        Haptics.done(enabled: store.hapticsEnabled)
                        store.recordReview(ref, passed: true)
                        sessionPassed += 1
                        advance()
                    } label: {
                        Label(loc("تذكرتها"), systemImage: "checkmark.circle.fill")
                            .font(Theme.display(16, weight: .semibold))
                            .gradientButton(Theme.gradient(for: "success"), glow: Theme.success)
                    }
                    .pressable()
                }
            case .revealed:
                bigButton(loc("أعِدها الآن"), icon: "arrow.counterclockwise",
                          gradient: stageGradient(.revealed), glow: stageAccent(.revealed)) {
                    // «إذا علق يعيدها» — ترجع الآية نفسها من أولها.
                    repeatsLeft = store.hifzRepeatCount
                    stage = .reading
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    private func bigButton(_ title: String, icon: String? = nil,
                           gradient: LinearGradient, glow: Color,
                           _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let icon { Label(title, systemImage: icon) }
                else { Text(title) }
            }
            .font(Theme.display(16, weight: .semibold))
            .gradientButton(gradient, glow: glow)
        }
        .pressable()
    }

    // MARK: الحالات

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(Theme.gradient(for: "hifz"))
                .frame(width: 120, height: 120)
                .background(
                    EightPointStar(innerRatio: 0.66)
                        .fill(sea.opacity(0.04))
                )
                .appearStagger(0)
            Text(loc("ابدأ حفظك"))
                .font(Theme.display(22, weight: .bold))
                .foregroundStyle(Theme.ink)
                .appearStagger(1)
            Text(loc("اختر سورة أو مدى من الآيات، ونلقّنك إياها بالتكرار ثم التلميح ثم الاسترجاع.\nوما تعثّرت فيه يعود عليك حتى يثبت."))
                .font(Theme.display(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .appearStagger(2)
            AtharPrimaryButton(title: loc("اختر ما تحفظ"), icon: "plus",
                               gradient: Theme.gradient(for: "hifz"), glowTint: sea) {
                showPicker = true
            }
            .frame(maxWidth: 300)
            .padding(.horizontal, 40)
            .appearStagger(3)

            if store.memorizedCount > 0 {
                // العدد هنا يبدأ من واحد، فلا يصلح تمييز عدد آيات السورة (٣ فأكثر):
                // نُفرد ونُثنّي مع مطابقة الفعل — «آية ثبتت» و«آيتان ثبتتا».
                Text(store.memorizedCount == 1 ? "آية ثبتت معك"
                     : store.memorizedCount == 2 ? "آيتان ثبتتا معك"
                     : "\(store.memorizedCount.ayahCountText) ثبتت معك")
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 6)
                    .appearStagger(4)
            }
        }
    }

    private var finished: some View {
        VStack(spacing: 16) {
            ZStack {
                CelebrationHalo(tint: Theme.gold)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.gradient(for: "hifz"))
            }
            .frame(height: 130)
            Text(loc("أتممت مراجعة اليوم"))
                .font(Theme.display(22, weight: .bold)).foregroundStyle(Theme.ink)
            Text(loc("ثبت %1$@ · تعثّر %2$@", sessionPassed.counterText, sessionStumbled.counterText))
                .font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
            Text(loc("المتعثّر يعود عليك اليوم، وما ثبت يعود بعد أيام."))
                .font(Theme.display(12)).foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            // «تحديث» كان يعيد التحميل فيسقط في شاشة البداية؛ الخروج بزر الرجوع،
            // وما ينفع هنا هو إضافة آيات جديدة.
            Button { showPicker = true } label: {
                Text(loc("أضِف آيات"))
                    .font(Theme.display(15, weight: .semibold)).foregroundStyle(sea)
            }
            .buttonStyle(.plain).padding(.top, 4)
        }
    }

    /// لا مستحقّ اليوم والحفظ قائم: حالة راحة لا شاشة البداية، حتى لا يقرأ العائد
    /// «ابدأ حفظك» وعنده بطاقات قيد الحفظ لم تثبت بعد (لا يعدّها memorizedCount).
    private var restState: some View {
        let today = AtharStore.dayNumber()
        let nextDue = store.memoryCards.values.map(\.dueDay).min() ?? today
        let inProgress = store.memoryCards.count - store.memorizedCount
        return VStack(spacing: 18) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 52))
                .foregroundStyle(Theme.gradient(for: "hifz"))
                .frame(width: 120, height: 120)
                .background(
                    EightPointStar(innerRatio: 0.66)
                        .fill(sea.opacity(0.04))
                )
                .appearStagger(0)
            Text(loc("لا مراجعة اليوم"))
                .font(Theme.display(22, weight: .bold))
                .foregroundStyle(Theme.ink)
                .appearStagger(1)
            Text(nextReviewText(daysAhead: nextDue - today))
                .font(Theme.display(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)
                .appearStagger(2)
            Text(loc("ثبت %1$@ · قيد الحفظ %2$@", store.memorizedCount.counterText, inProgress.counterText))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .appearStagger(3)
            AtharPrimaryButton(title: loc("أضِف آيات"), icon: "plus",
                               gradient: Theme.gradient(for: "hifz"), glowTint: sea) {
                showPicker = true
            }
            .frame(maxWidth: 300)
            .padding(.horizontal, 40)
            .appearStagger(4)
        }
    }

    /// تمييز العدد للأيام: غدًا، بعد يومين، بعد ٣–١٠ أيام، ثم ١١ فأكثر يومًا.
    private func nextReviewText(daysAhead n: Int) -> String {
        switch n {
        case ...1:   return loc("المراجعة القادمة غدًا")
        case 2:      return loc("المراجعة القادمة بعد يومين")
        case 3...10: return loc("المراجعة القادمة بعد %1$@ أيام", n.counterText)
        default:     return loc("المراجعة القادمة بعد %1$@ يومًا", n.counterText)
        }
    }

    /// تمييز العدد للتعثّر: مرة، مرتين، ٣–١٠ مرات، ثم ١١ فأكثر مرة — التعثّر يبدأ
    /// من واحد ويزيد واحدًا، فالأعداد الصغيرة هي الشائعة.
    private func lapseText(_ n: Int) -> String {
        switch n {
        case 1:      return loc("تعثّرت فيها مرة — كرّرها")
        case 2:      return loc("تعثّرت فيها مرتين — كرّرها")
        case 3...10: return loc("تعثّرت فيها %1$@ مرات — كرّرها", n.counterText)
        default:     return loc("تعثّرت فيها %1$@ مرة — كرّرها", n.counterText)
        }
    }

    // MARK: المنطق

    /// إضافة ما اختاره إلى الحفظ كبطاقات جديدة — لا كتعثّر.
    /// `MemoryCard.new` موعدها اليوم أصلًا، فتدخل طابور اليوم دون أن يُوسم
    /// ما لم يره بعد بأنه «تعثّرت فيه»، ودون تضخيم عدّاد التعثّر لاحقًا.
    private func enroll(_ refs: [AyahRef]) {
        let today = AtharStore.dayNumber()
        var all = store.memoryCards
        for r in refs where all[r.id] == nil { all[r.id] = MemoryCard.new(today: today) }
        store.memoryCards = all
    }

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
            let bare = bareLetters(w)
            guard let first = bare.first else { return w }
            return bare.count <= 1 ? String(first) : "\(first)ـ"
        }.joined(separator: " ")
    }

    /// تجريد التشكيل وحده — دون توحيد صور الهمزة كما يفعل تجريد البحث،
    /// ليبقى أول الحرف كما رُسم في المصحف (أَحَدٌ ← أ، لا ا).
    private func bareLetters(_ w: String) -> String {
        var out = String.UnicodeScalarView()
        for u in w.unicodeScalars {
            let v = u.value
            if (0x064B...0x065F).contains(v) || v == 0x0670 || v == 0x0640 { continue } // تشكيل + ألف خنجرية + تطويل
            if (0x06D6...0x06ED).contains(v) { continue }                                // علامات وقف وتجويد
            out.append(u)
        }
        return String(out)
    }
}
