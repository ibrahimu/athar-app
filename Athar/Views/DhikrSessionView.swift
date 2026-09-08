import SwiftUI
import WidgetKit

/// The reading screen: one dhikr at a time, tap anywhere to count down.
struct DhikrSessionView: View {
    let category: DhikrCategory
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @ObservedObject private var ayahAudio = AyahAudio.shared
    @ObservedObject private var recorded = DhikrAudio.shared
    /// ما بقي من تكرار التلاوة القرآنية — العدّ يقع عند تمام المقطع لا عند كل آية.
    @State private var recitingLeft = 0
    @State private var remaining: [String: Int] = [:]
    @State private var showCompletion = false
    /// الذكر المفتوح في مصمّم بطاقة الصورة، وبطاقة المحفظة المعروضة — كلاهما يُبنى
    /// من المعرّف لا من نصّ يُعاد كتابته هنا.
    @State private var designing: Phrase?
    @State private var walletPreview: WalletCard?
    /// ورقة الإتمام لم تكن «حاجزة» لقارئ الشاشة: التركيز يبقى على زرّ العدّ خلفها.
    @AccessibilityFocusState private var focusDone: Bool

    private var color: Color { Theme.accent(for: category.accent) }
    private var direction: LayoutDirection {
        AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection
    }
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
            // خلف ورقة الإتمام تبقى الصفحة في شجرة الإتاحة، فتُحجب عن VoiceOver ما دامت الورقة ظاهرة.
            .accessibilityHidden(showCompletion)
        }
        // ملاحظة مستخدم: الدائرة وحدها تُلزم بمدّ الإبهام إلى أسفل الشاشة.
        .contentShape(Rectangle())
        .onTapGesture { if store.countTapArea == .screen { step() } }
        .navigationTitle(category.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onDisappear { stopSound() }
        .toolbar {
            // قراءة الذكر بصوت الجهاز وعدّه تلقائيًّا — لمن يداه مشغولتان.
            // لا يُعرض إلا حيث خلفه صوتُ إنسان: تسجيلٌ أو تلاوة. وما لا صوت له فلا زرّ
            // له — وعرضُ زرٍّ ينطق بصوت آلةٍ خشن أسوأ من ألّا يكون.
            if hasHumanVoice {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if sounding { stopSound() } else { startSound() }
                    } label: { Image(systemName: sounding ? "speaker.slash.fill" : "speaker.wave.2.fill") }
                    .accessibilityLabel(sounding ? loc("إيقاف الصوت") : loc("تلاوة الذكر مع العدّ"))
                }
            }
            // أزرار الشاشات المدفوعة تأتي في الطرف الأخير، بعيدًا عن سهم الرجوع.
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(loc("إعادة العدّ"), systemImage: "arrow.counterclockwise") { resetCounts() }
                    ShareLink(item: shareText) { Label(loc("مشاركة الذكر"), systemImage: "square.and.arrow.up") }
                    Button(loc("بطاقة صورة"), systemImage: "photo") { designing = dhikrPhrase }
                    // البطاقة الموقَّعة موجودة في قسم المحفظة؛ نقرّبها إلى الذكر الذي يُقرأ
                    // الآن بدل أن يبحث عنها بين خمسٍ وستين بطاقة.
                    if let card = walletCard {
                        Button(loc("أضف إلى المحفظة"), systemImage: "wallet.pass") { walletPreview = card }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(loc("المزيد"))
            }
        }
        .onAppear(perform: seed)
        // السحب يغيّر الصفحة دون عدّ، فنحفظ الموضع أيضًا ليعود المستخدم حيث ترك.
        .onChange(of: index) { _, _ in saveSession(); stopSound() }   // لا يُكمل قراءة الذكر السابق على عدّ اللاحق
        .overlay { if showCompletion { completionOverlay } }
        .animation(Motion.smooth, value: showCompletion)
        .sheet(item: $designing) { phrase in
            StoryDesignerView(phrase: phrase)
                .atharSheetChrome()
                .environment(\.layoutDirection, direction)
        }
        .sheet(item: $walletPreview) { card in
            WalletCardPreview(card: card)
                .atharSheetChrome()
                .presentationDetents([.large])
                .environment(\.layoutDirection, direction)
        }
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

            // الرقمان يقيسان شيئين لا شيئًا واحدًا: الأيسرُ موضعُك من الأذكار، والأيمنُ
            // ما قلتَه من مجموع التكرار — وذكرٌ يُقال مئةً ليس كذكرٍ يُقال مرّة. فكانا
            // بلا اسمٍ يُقرآن جملةً واحدة متناقضة («٨ من ٢٥» و«٣٪»)، فسُمّي كلٌّ بما يقيس.
            HStack {
                Text(loc("الذكر %1$@ من %2$@", (index + 1).counterText, category.items.count.counterText))
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Text(loc("%1$@٪ من التكرار", Int(overallProgress * 100).counterText))
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, 8)
        .readableWidth(720)
    }

    private func dhikrPage(_ dhikr: Dhikr) -> some View {
        // ارتفاع أدنى لا ثابت: الذكر القصير يبقى في الوسط، والطويل (آية الكرسي
        // وأذكار النوم) يمتدّ فيتحرّك التمرير بدل أن يُبتر نصفه بلا أيّ إشارة.
        GeometryReader { geo in
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
                .padding(.horizontal, Theme.gutter)
                .padding(.vertical, 16)
                .readableWidth(720)
                .frame(minHeight: geo.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
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

            // لو تخطّى المستخدم أذكارًا بالسحب ثم فرغ عدّ الأخير، لا «تالٍ» يسحب
            // إليه — فندلّه على ما بقي بدل تلميح لا يقود إلى شيء.
            Text(left == 0
                 ? (isLastPageWithUnfinished
                    ? (store.countTapArea == .screen
                       ? loc("بقيت أذكار لم تكتمل — اضغط أي مكان للرجوع إليها")
                       : loc("بقيت أذكار لم تكتمل — اضغط الدائرة للرجوع إليها"))
                    : loc("اسحب للذكر التالي"))
                 : (store.countTapArea == .screen ? loc("اضغط أي مكان للعدّ") : loc("اضغط الدائرة للعدّ")))
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
                    .accessibilityFocused($focusDone)
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
        // ورقة حاجزة: قارئ الشاشة يبقى داخلها ولا يصل إلى زرّ العدّ خلفها.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: Logic

    private func seed() {
        guard remaining.isEmpty else { return }
        // نستعيد عدّ اليوم إن وُجد: مَن بلغ ٣٤٠ من ٣٦٧ ثم خرج لا يُطالَب بالبدء من الصفر.
        guard !restoreSession() else { return }
        remaining = Dictionary(uniqueKeysWithValues: category.items.map { ($0.id, $0.count) })
    }

    // MARK: الصوت — القرآن يُتلى، وسواه يُنطَق

    /// موضع الذكر من المصحف إن كان قرآنًا (مستخرَجٌ من عزو الدليل).
    private var quranRange: AyahRange? {
        DhikrRecitation.range(category: category.id, dhikr: current.id)
    }

    private var sounding: Bool { recitingLeft > 0 || recorded.playing }

    /// أصوات الأذكار المسجَّلة لم تُنجَز بعد، والنطق المركَّب لا يليق بذكرٍ يُتعبَّد به —
    /// فيُخفى الزرّ إلا حيث يوجد تسجيلٌ في الحزمة أو تلاوةٌ لقرآن. ومتى أُضيفت
    /// التسجيلات عاد الزرّ من نفسه بلا تعديل، فالشرط هو وجود الملف.
    private var hasHumanVoice: Bool { hasRecording || quranRange != nil }

    /// أفضل ما يُسمع به هذا الذكر: تسجيلٌ إن وُجد، فتلاوةٌ إن كان قرآنًا، فنطقٌ أخيرًا.
    private var hasRecording: Bool { DhikrAudio.has(category: category.id, dhikr: current.id) }

    /// صوتُ آلةٍ يقرأ القرآن نشاز، فما كان قرآنًا يُتلى بصوت قارئٍ من محرّك التلاوة
    /// نفسه الذي في المصحف، وما سواه يبقى على النطق. والعدّ في الحالين عند التمام.
    private func startSound() {
        stopSound()
        // تسجيلُ قارئٍ أولى من كل تركيب، فإن وُجد فهو المقدَّم على ما سواه.
        if hasRecording {
            recorded.start(category: category.id, dhikr: current.id, times: max(1, left)) { step() }
            return
        }
        guard let range = quranRange else { return }
        recitingLeft = max(1, left)
        reciteOnce(range)
    }

    private func reciteOnce(_ range: AyahRange) {
        ayahAudio.repeatCount = 1
        ayahAudio.stopAt = range.last
        ayahAudio.play(from: range.first, onAdvance: nil) {
            // تمّ المقطع: يُعدّ مرّة، فإن بقي من عدده شيء أُعيد.
            step()
            recitingLeft = max(0, recitingLeft - 1)
            if recitingLeft > 0 { reciteOnce(range) }
        }
    }

    private func stopSound() {
        recorded.stop()
        if recitingLeft > 0 { recitingLeft = 0; ayahAudio.stop() }
    }

    private func step() {
        guard left > 0 else {
            advance()
            return
        }
        remaining[current.id] = left - 1
        store.totalDhikrCount += 1
        store.noteDhikr()
        store.touchStreak()
        saveSession()

        if remaining[current.id] == 0 {
            Haptics.done(enabled: store.hapticsEnabled)
            if isCategoryComplete {
                store.markCompleted(categoryId: category.id)
                WidgetCenter.shared.reloadAllTimelines()
                showCompletion = true
                // يُنقل تركيز VoiceOver بعد أن تُبنى الورقة، لا في اللحظة نفسها.
                DispatchQueue.main.async { focusDone = true }
            } else {
                // نلتقط الصفحة التي أُجّل الانتقال منها: لو سحب المستخدم خلال
                // ثلث الثانية لقفز التأجيل فوق ذكر كامل ولم يُعدّ أبدًا.
                let from = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    if index == from { advance() }
                }
            }
        } else {
            Haptics.step(enabled: store.hapticsEnabled)
        }
    }

    private var isCategoryComplete: Bool {
        category.items.allSatisfy { (remaining[$0.id] ?? $0.count) == 0 }
    }

    /// آخر صفحة وقد فرغ عدّها بينما خلفها أذكار لم تُعدّ — الحالة التي لا «تالٍ» فيها.
    private var isLastPageWithUnfinished: Bool {
        index >= category.items.count - 1 && !isCategoryComplete
    }

    private func advance() {
        if index < category.items.count - 1 {
            withAnimation(Motion.smooth) { index += 1 }
        } else if let next = category.items.firstIndex(where: { (remaining[$0.id] ?? $0.count) > 0 }) {
            // نهاية القائمة وقد بقي ما لم يُعدّ: نرجع إليه بدل ضغطٍ لا يفعل شيئًا.
            withAnimation(Motion.smooth) { index = next }
        }
    }

    private func resetCounts() {
        withAnimation {
            remaining = Dictionary(category.items.map { ($0.id, $0.count) }, uniquingKeysWith: { first, _ in first })
            index = 0
        }
        saveSession()
    }

    // MARK: حفظ عدّ اليوم

    /// العدّ المتبقّي كان في @State وحده، فكان الخروج من الشاشة يمحو جهد الجلسة كلّها.
    /// نحفظه بطابع اليوم كما تُحفظ الفئات المكتملة، فيسقط تلقائيًا مع يوم جديد.
    private var sessionDayKey: String { "athar.session.day.\(category.id)" }
    private var sessionKey: String { "athar.session.\(category.id)" }
    private var sessionIndexKey: String { "athar.session.index.\(category.id)" }

    private func saveSession() {
        let defaults = store.defaults
        defaults.set(AtharStore.dayStamp(), forKey: sessionDayKey)
        defaults.set(remaining, forKey: sessionKey)
        defaults.set(index, forKey: sessionIndexKey)
    }

    /// يُرجع true إن استُعيدت جلسة اليوم. نُعيد بناء القاموس من أذكار الفئة نفسها
    /// كي لا يفسد المحفوظ الحسابَ لو تغيّرت البيانات في تحديث.
    private func restoreSession() -> Bool {
        let defaults = store.defaults
        guard defaults.string(forKey: sessionDayKey) == AtharStore.dayStamp(),
              let saved = defaults.dictionary(forKey: sessionKey) as? [String: Int]
        else { return false }

        let restored = Dictionary(uniqueKeysWithValues: category.items.map {
            ($0.id, min(max(0, saved[$0.id] ?? $0.count), $0.count))
        })
        // الجلسة المكتملة لا تُستعاد: «أذكار بعد الصلاة» تُعاد بعد كل صلاة،
        // فلو أعدنا أصفارها لفُتحت الشاشة على عدّ لا يستجيب لضغطة.
        guard restored.values.contains(where: { $0 > 0 }) else { return false }
        // موضع محفوظ بلا عدّ لا يُستعاد: مَن تصفّح الأذكار فقط — أو أعاد فتحها بعد
        // إتمامها — يبدأ من الأول لا من الصفحة التي وقف عندها والشريط على ٠٪.
        guard category.items.contains(where: { (restored[$0.id] ?? $0.count) < $0.count }) else { return false }

        remaining = restored
        index = max(0, min(defaults.integer(forKey: sessionIndexKey), category.items.count - 1))
        return true
    }

    private var shareText: String {
        current.text + (current.hasReference ? "\n\n\(current.reference)" : "") + "\n\nمن تطبيق أثر"
    }

    // MARK: بطاقة صورة وبطاقة محفظة

    /// المصمّم يبني بطاقته من المعرّف: اللفظ يبقى من adhkar.json حرفًا، ولا يُكتب هنا.
    private var dhikrPhrase: Phrase {
        Phrase(id: "d-\(current.id)", category: phraseCategory, source: .dhikr(id: current.id))
    }

    /// الصنف يصبغ المصمّم لا غير، فنتبع فيه تصنيف مكتبة العبارات نفسه.
    private var phraseCategory: PhraseCategory {
        switch category.id {
        case "morning": return .morning
        case "evening": return .evening
        default:        return .dua
        }
    }

    /// بطاقة المحفظة لهذا الذكر بعينه — تُطابَق بالفئة والمعرّف معًا، فأذكار
    /// الصباح والمساء تشترك في ألفاظ ولا تشترك في بطاقاتها.
    private var walletCard: WalletCard? {
        WalletCardLibrary.cards.first { $0.dhikrCategory == category.id && $0.dhikrId == current.id }
    }
}
