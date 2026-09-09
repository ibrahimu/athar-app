import SwiftUI

/// شاشة الجمعة: سننها تُعلَّم واحدةً واحدة بدليلها، والكهف ببابين، وعدٌّ للصلاة على
/// النبي ﷺ، ثم الصدقة في آخرها — يومٌ واحد في الأسبوع تجتمع أعماله في صفحة.
struct FridayView: View {
    /// معروضةً تبويبًا في الشريط السفلي — فلا يُخفى الشريط.
    var isRootTab = false
    @EnvironmentObject private var store: AtharStore

    /// لتسمية اليوم في الرأس وحدها. أما القراءة والكتابة في المخزن فبوقتها هي،
    /// فلا يُكتب تعليمُ سنّةٍ في جمعةٍ مضت لأن الشاشة بقيت مفتوحة إلى ما بعد منتصف الليل.
    @State private var now = Date()
    /// السنّة المفتوح دليلها — واحدةٌ لا أكثر، فلا تصير القائمة جدارًا من المتون.
    @State private var expanded: String?
    @State private var openReader = false
    @State private var sharing = false
    @State private var confirmReset = false

    private var tint: Color { Theme.accent(for: "gold") }
    private var direction: LayoutDirection {
        AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection
    }

    private var progress: FridayProgress { store.fridayProgress }
    private var kahfRead: Bool { store.ledger().kahf }
    private var daysToFriday: Int { AtharStore.daysUntilFriday(now) }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.accent)
            ScrollView {
                VStack(spacing: 18) {
                    hero.appearStagger(0)
                    checklist.appearStagger(1)
                    kahfBlock.appearStagger(2)
                    salawatBlock.appearStagger(3)
                    SadaqahCard().appearStagger(4)
                    footer.appearStagger(5)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 6)
                .padding(.bottom, 34)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("الجمعة"))
        .navigationBarTitleDisplayMode(.inline)
        // تبويبًا جذريًّا يبقى الشريط: كانت تُخفيه إخفاءً مطلقًا، فمن جعلها تبويبًا
        // في الشريط اختفى عنه الشريطُ كلُّه وهي جذرُ مكدّسها فلا زرّ رجوع — فيُحبَس
        // فيها حتى يُنهي التطبيق. وسائرُ الشاشات الجذرية تشترطه كذلك.
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.tap(enabled: store.hapticsEnabled)
                    sharing = true
                } label: {
                    Image(systemName: "photo")
                }
                .accessibilityLabel(loc("بطاقة صورة"))
            }
        }
        .onAppear { now = Date() }
        // بابا القراءة يضبطان النمط ثم يدفعان القارئ نفسه، فالوجهة واحدة لهما.
        .navigationDestination(isPresented: $openReader) { SurahReaderView(surahId: 18) }
        // رقمان مجرّدان تُرسَلان إلى ورقة المشاركة — لا تعرف عنّا نموذجًا ولا نعرف عنها.
        .sheet(isPresented: $sharing) {
            FridayShareSheet(progress: (done: progress.done, total: progress.total))
                .atharSheetChrome()
                .environment(\.layoutDirection, direction)
        }
    }

    // MARK: رأس اليوم

    private var hero: some View {
        AtharCard(padding: 18, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    ZStack {
                        ProgressRing(progress: progress.fraction, color: tint,
                                     lineWidth: 5, gradient: true, glow: progress.isComplete)
                            .frame(width: 58, height: 58)
                        Image(systemName: progress.isComplete ? "checkmark" : "sun.max.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(tint)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(mood)
                            .font(Theme.display(21, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(loc("%1$@ من %2$@ من سنن اليوم",
                                 progress.done.counterText, progress.total.counterText))
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    Text(hijriLine)
                        .font(Theme.display(12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Capsule().fill(Theme.surfaceAlt))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    /// مزاج اليوم: تهنئةٌ يومَها، وتنبيهٌ لطيف لمن فتحها قبل موعدها.
    private var mood: String {
        switch daysToFriday {
        case 0:  return progress.isComplete ? loc("تمّت سننُ جمعتك") : loc("جمعة مباركة")
        case 1:  return loc("غدًا الجمعة")
        default: return loc("استعدّ لجمعتك")
        }
    }

    /// يُركَّب تركيبًا كسطر «اليوم»: ضبط المطالع يزيح اليومَ الهجري وحده،
    /// ولو أُزيح التاريخ كلّه لسُمّي اليومُ باسم يومٍ لم يأتِ بعد.
    private var hijriLine: String {
        let c = Occasions.hijriComponents(now)
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "EEEE"
        return "\(f.string(from: now))، \(c.day.counterText) \(Occasions.monthName(c.month)) \(String(c.year)) هـ"
    }

    // MARK: السنن

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("سنن الجمعة"), tint: tint)
            SettingsCard {
                ForEach(Array(FridaySunan.all.enumerated()), id: \.element.id) { i, s in
                    sunnahRow(s)
                    if i < FridaySunan.count - 1 { SettingsDivider(inset: 0) }
                }
            }
            Text(loc("انقر السنّة لتعليمها، ورمزَ الاقتباس لدليلها"))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .padding(.horizontal, 4)
        }
    }

    private func sunnahRow(_ s: FridaySunnah) -> some View {
        let done = store.isFridaySunnahDone(s.id)
        // الكهف لا يُعلَّم باليد: علامته قراءتُه، فضغطتُه تفتح السورة لا تدّعي إتمامها.
        let ledgerLed = s.id == FridaySunan.kahfId
        let open = expanded == s.id
        let evidence = s.hadith.flatMap(HadithLibrary.hadith(id:))
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    if ledgerLed { openReader = true } else { toggle(s) }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(done ? tint : tint.opacity(0.13))
                                .frame(width: 34, height: 34)
                            Image(systemName: done ? "checkmark" : s.icon)
                                .font(.system(size: 15, weight: done ? .bold : .medium))
                                .foregroundStyle(done ? Theme.onAccent : tint)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.title)
                                .font(Theme.display(16, weight: done ? .semibold : .regular))
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                            Text(ledgerLed && done ? loc("سجّلها لك المصحف") : s.detail)
                                .font(Theme.display(12))
                                .foregroundStyle(Theme.inkFaint)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 4)
                        if ledgerLed {
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                                .accessibilityHidden(true)
                        }
                    }
                    .tapTarget()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(s.title)
                .accessibilityValue(done ? loc("أُدّيت") : loc("لم تُؤدَّ"))
                .accessibilityHint(ledgerLed ? loc("اضغط مرّتين لفتح السورة") : loc("اضغط مرّتين للتعليم"))
                .accessibilityAddTraits(done ? .isSelected : [])

                if evidence != nil {
                    Button {
                        Haptics.tap(enabled: store.hapticsEnabled)
                        withAnimation(Motion.snappy) { expanded = open ? nil : s.id }
                    } label: {
                        Image(systemName: "text.quote")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(open ? tint : Theme.inkFaint)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(loc("الدليل"))
                    .accessibilityValue(open ? loc("مفتوح") : loc("مطويّ"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if open, let h = evidence {
                evidenceCard(h)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
            }
        }
    }

    /// الدليل كما هو في hadith.json: متنٌ بخطّ النسخ وتخريجٌ تحته، بلا حرفٍ من عندنا.
    private func evidenceCard(_ h: Hadith) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Capsule().fill(Theme.goldGradient).frame(width: 34, height: 2.5).opacity(0.8)
            Text(h.text)
                .font(Theme.dhikrFont(size: 16, scale: store.fontScale))
                .foregroundStyle(Theme.ink)
                .lineSpacing(8)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(h.citation)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(tint.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
        )
    }

    private func toggle(_ s: FridaySunnah) {
        let done = store.isFridaySunnahDone(s.id)
        withAnimation(Motion.snappy) { store.setFridaySunnah(!done, id: s.id) }
        if done { Haptics.tap(enabled: store.hapticsEnabled) }
        else { Haptics.done(enabled: store.hapticsEnabled) }
    }

    // MARK: سورة الكهف

    private var kahfBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("سورة الكهف"), tint: tint)
            AtharCard(padding: 18, elevation: .e2, tint: tint) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        IconChip(icon: kahfRead ? "checkmark.seal.fill" : "book.closed.fill",
                                 tint: tint, size: .lg)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(kahfRead ? loc("قرأتها اليوم") : loc("لم تُقرأ بعد"))
                                .font(Theme.display(17, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(kahfRead ? loc("تقبّل الله — أُثبتت في إحصائك")
                                          : loc("افتحها كما تحبّ: صفحةً كالمصحف أو آيةً آية"))
                                .font(Theme.display(12))
                                .foregroundStyle(Theme.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }

                    // فضل السورة من بيانات التطبيق (surah_virtues.json) — لا يُكتب هنا حرف.
                    if let virtue = SurahExtras.virtues(of: 18).first {
                        VStack(alignment: .leading, spacing: 6) {
                            Capsule().fill(Theme.goldGradient).frame(width: 34, height: 2.5).opacity(0.8)
                            Text("«\(virtue.text)»")
                                .font(Theme.dhikrFont(size: 16, scale: store.fontScale))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(8)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(virtue.source)
                                .font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }

                    // بابان لا باب: من يقرأ صفحةَ المصحف كما ألِفها، ومن يقرأ آيةً آية.
                    HStack(spacing: 10) {
                        readerDoor(.page)
                        readerDoor(.ayah)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// النمط يُضبط قبل الدفع، فيفتح القارئ على ما اختاره الآن لا على آخر ما تركه.
    private func readerDoor(_ mode: ReadingMode) -> some View {
        Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            store.readingMode = mode
            openReader = true
        } label: {
            Label(mode.title, systemImage: mode.icon)
                .font(Theme.display(14, weight: .semibold))
                .lineLimit(1)
                .softButton(tint)
        }
        .pressable()
        .accessibilityLabel(loc("افتح سورة الكهف — %1$@", mode.title))
    }

    // MARK: الصلاة على النبي ﷺ

    /// النصّ ومرجعه من adhkar.json بمعرّفه — لا يُكتب ذكرٌ في شاشة.
    private var salawatDhikr: Dhikr? {
        AdhkarLibrary.category(id: "salawat")?.items.first { $0.id == "sl02" }
    }

    @ViewBuilder
    private var salawatBlock: some View {
        if let dhikr = salawatDhikr {
            let count = store.fridaySalawatCount
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: loc("الصلاة على النبي ﷺ"), tint: Theme.accent)
                AtharCard(padding: 18, elevation: .e2, tint: Theme.accent) {
                    VStack(spacing: 14) {
                        Text(dhikr.text)
                            .font(Theme.dhikrFont(size: 19, scale: store.fontScale))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(7)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        Text(count.counterText)
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent, Theme.accent.opacity(0.7)],
                                                            startPoint: .top, endPoint: .bottom))
                            .contentTransition(.numericText())
                            .accessibilityHidden(true)

                        Button(action: countSalawat) {
                            Label(loc("صلِّ عليه ﷺ"), systemImage: "plus")
                                .font(Theme.display(16, weight: .semibold))
                                .gradientButton()
                        }
                        .pressable()
                        .accessibilityLabel(loc("الصلاة على النبي ﷺ"))
                        .accessibilityValue(count.counterText)
                        .accessibilityHint(loc("اضغط مرّتين للعدّ"))

                        HStack(spacing: 10) {
                            if dhikr.hasReference {
                                Text(dhikr.reference)
                                    .font(Theme.display(11))
                                    .foregroundStyle(Theme.inkFaint)
                            }
                            Spacer(minLength: 6)
                            if count > 0 {
                                Button { confirmReset = true } label: {
                                    Text(loc("تصفير"))
                                        .font(Theme.display(12, weight: .medium))
                                        .foregroundStyle(Theme.inkFaint)
                                        .tapTarget()
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let category = AdhkarLibrary.category(id: "salawat") {
                            NavigationLink { DhikrSessionView(category: category) } label: {
                                HStack(spacing: 10) {
                                    IconChip(icon: category.icon, tint: Theme.accent, size: .sm)
                                    Text(loc("صيغ الصلاة عليه ﷺ بتخريجها"))
                                        .font(Theme.display(14, weight: .semibold))
                                        .foregroundStyle(Theme.ink)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 6)
                                    Image(systemName: "chevron.forward")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.accent)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .confirmationDialog(loc("تصفير عدّ اليوم؟"), isPresented: $confirmReset, titleVisibility: .visible) {
                Button(loc("تصفير"), role: .destructive) {
                    store.fridaySalawatCount = 0
                    Haptics.tap(enabled: store.hapticsEnabled)
                }
                Button(loc("cancel"), role: .cancel) {}
            } message: {
                Text(loc("يُصفَّر عدّ اليوم وحده، ولا يمسّ إحصاءك."))
            }
        }
    }

    /// كالمسبحة: العدّ يُثبت في الدفتر والمجموع ويحيي التتابع — ذكرٌ كسائر الذكر.
    private func countSalawat() {
        store.addFridaySalawat()
        store.noteDhikr()
        store.totalDhikrCount += 1
        store.touchStreak()
        Haptics.step(enabled: store.hapticsEnabled)
    }

    private var footer: some View {
        Text(loc("تُطوى علامات هذه الصفحة وتُستأنف مع الجمعة القادمة"))
            .font(Theme.display(11))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
    }
}
