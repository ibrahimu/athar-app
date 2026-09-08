import SwiftUI
import UIKit

// MARK: - حصاد اليوم

/// كل ما تعرفه هذه الورقة عن يوم صاحبها: رقمان — كم تمّ من سنن الجمعة وكم جملتها.
/// عُرِّف هنا لا في شاشة السنن حتى لا ترتهن بطاقةُ مشاركةٍ بنماذج شاشةٍ أخرى تتبدّل.
struct FridaySunanProgress: Equatable {
    var done: Int
    var total: Int

    var isComplete: Bool { total > 0 && done >= total }
    /// صفرٌ عند غياب العدد: القسمة على لا شيء لا تصف تقدّمًا.
    var fraction: Double { total > 0 ? min(1, max(0, Double(done) / Double(total))) : 0 }
}

// MARK: - البطاقة الجاهزة وثوبها

/// عبارةٌ في ثوبها. لا تحمل صورةً مرسومة: البطاقة تُصيَّر من StoryCard عند العرض
/// وعند الإرسال سواء، فما رآه الناظر هو ما يخرج إلى إكس وسناب بالحرف.
private struct FridayCard: Identifiable {
    let phrase: Phrase
    let design: StoryDesign
    var id: String { phrase.id }
}

/// ثوب البطاقة: طابعٌ ونقشٌ وشكل.
private struct FridayDress {
    let theme: AppTheme
    let pattern: BackgroundPattern
    let layout: StoryDesign.Layout
}

// MARK: - ورقة بطاقات الجمعة

/// معرضٌ من عبارات الجمعة جاهزةً للإرسال بضغطتين: واحدة تختار وأخرى ترسل.
/// ومن أراد أن يبدّل اللون والنقش والخط فبابه المصمّم نفسه (StoryDesignerView)
/// لا نسخةٌ منه هنا — محرّرٌ واحد للبطاقة في التطبيق كله.
struct FridayShareSheet: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    let progress: FridaySunanProgress

    @State private var chosen = 0
    @State private var asSticker = false
    @State private var share: StoryShareItem?
    @State private var designing: Phrase?
    @State private var renderFailed = false
    @State private var copied = false
    @State private var copyGeneration = 0

    init(progress: FridaySunanProgress) {
        self.progress = progress
    }

    /// النداء من شاشة السنن يحمل رقمين مجرّدين؛ يُقبلان زوجًا كما يُقبلان بنيةً،
    /// فلا تُلزَم الشاشة الأخرى بمعرفة اسم نوعٍ عندنا لتفتح ورقة مشاركة.
    init(progress: (done: Int, total: Int)) {
        self.progress = FridaySunanProgress(done: progress.done, total: progress.total)
    }

    private var tint: Color { Theme.accent(for: PhraseCategory.friday.accentKey) }
    private var direction: LayoutDirection {
        AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection
    }

    // MARK: المعرض

    /// أثواب الجمعة: رمليٌّ وعسليّ — ورقٌ دافئ وذهب، من لوحة الطوابع نفسها فلا يدخل
    /// لونٌ غريب على هوية التطبيق. تتناوب على البطاقات فلا يخرج الشريط بثوبٍ واحد.
    private static let dresses: [FridayDress] = [
        FridayDress(theme: .sand,  pattern: .stars,   layout: .classic),
        FridayDress(theme: .sand,  pattern: .lattice, layout: .paper),
        FridayDress(theme: .amber, pattern: .scales,  layout: .classic),
        FridayDress(theme: .amber, pattern: .stars,   layout: .paper),
    ]

    /// عبارات الجمعة تُرشَّح مرّةً لا مع كل رسمة: الترشيح خطّيٌّ على المكتبة كلها.
    private static let phrases: [Phrase] = PhraseLibrary.phrases(in: .friday)

    /// الخطّ يُقرأ هنا لا يوم بُنيت القائمة: من بدّل خطّ التطبيق رأى بطاقاته بخطّه.
    private func card(at index: Int) -> FridayCard {
        let phrase = Self.phrases[index]
        let dress = Self.dresses[index % Self.dresses.count]
        // «جمعة مباركة» تعلو النصّ الشرعي وحده؛ بطاقات التهنئة تقولها في متنها فلا تُثنّى.
        let eyebrow = phrase.isSacred ? loc("جمعة مباركة") : ""
        return FridayCard(phrase: phrase,
                          design: StoryDesign(theme: dress.theme,
                                              pattern: dress.pattern,
                                              layout: asSticker ? .sticker : dress.layout,
                                              font: AppFont.current,
                                              eyebrow: eyebrow))
    }

    private var selected: FridayCard? {
        guard Self.phrases.indices.contains(chosen) else { return nil }
        return card(at: chosen)
    }

    // MARK: الجسم

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    if let selected {
                        preview(selected)
                        formPicker
                        gallery
                        actions(selected)
                    } else {
                        unavailable
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 10)
                .padding(.bottom, 32)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
            .background { AtharBackground(tint: tint, secondary: Theme.gold) }
            .navigationTitle(loc("بطاقات الجمعة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("إغلاق")) { dismiss() }
                }
            }
            .sheet(item: $share) { item in
                ShareSheet(items: [item.payload])
                    .ignoresSafeArea()
                    .environment(\.layoutDirection, direction)
            }
            .alert(loc("تعذّر إنشاء الصورة"), isPresented: $renderFailed) {
                Button(loc("حسنًا"), role: .cancel) {}
            } message: {
                Text(loc("حاول مرة أخرى، أو شارك العبارة كنص."))
            }
            .task(id: copyGeneration) {
                guard copied else { return }
                do { try await Task.sleep(for: .seconds(1.5)); copied = false } catch {}
            }
        }
        // المصمّم يُفتح من الجذر لا من داخل اللوح: ورقتان معلّقتان على عنصر واحد تتزاحمان.
        .sheet(item: $designing) { phrase in
            StoryDesignerView(phrase: phrase)
                .environment(\.layoutDirection, direction)
                .atharSheetChrome()
        }
        // الورقة تكتسي بنفسها: تُفتح من أكثر من موضع، فلا تُترك كسوتها واتجاهها لمن ناداها.
        .environment(\.layoutDirection, direction)
        .atharSheetChrome()
    }

    // MARK: الرأس وحصاد السنن

    private var header: some View {
        AtharCard(padding: 18, elevation: .e2, tint: Theme.gold) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconChip(icon: "sparkles", tint: Theme.gold, size: .lg)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loc("بطاقة من جمعتك"))
                            .font(Theme.display(18, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        Text(loc("اختر بطاقة وأرسلها كما هي، أو صمّمها بلونك وخطّك."))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // لا يُذكر الحصاد إن لم يُمرَّر عددٌ أصلًا: صفرٌ من صفر خبرٌ لا معنى له.
                if progress.total > 0 {
                    SettingsDivider(inset: 0)
                    sunanRow
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// سطرُ اليوم: حلقةٌ تُري ما تمّ، وسطرٌ يقوله بالأرقام — فمن أتمّ سننه شارك وهو مطمئن.
    private var sunanRow: some View {
        HStack(spacing: 12) {
            ZStack {
                ProgressRing(progress: progress.fraction, color: tint, lineWidth: 5)
                    .frame(width: 40, height: 40)
                Image(systemName: progress.isComplete ? "checkmark" : "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.isComplete ? loc("أتممت سنن الجمعة") : loc("سنن الجمعة اليوم"))
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(loc("%1$@ من %2$@", progress.done.counterText, progress.total.counterText))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        // الحلقة والسطران خبرٌ واحد؛ تفريقها ثلاثَ محطّات يطيل الطريق بلا فائدة.
        .accessibilityElement(children: .combine)
    }

    // MARK: المعاينة

    /// البطاقة نفسها مصغّرة — لا رسمةٌ تحاكيها، فما يُرى هو ما يُرسل.
    private func preview(_ card: FridayCard) -> some View {
        face(card, scale: 0.23)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
            .padding(.top, 2)
            // البطاقة صورةٌ تُصيَّر لا نصٌّ يُتصفَّح: تُطوى في عنصر واحد ينطق بما فيها.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(loc("معاينة البطاقة — %1$@", card.phrase.text))
            .accessibilityValue(asSticker ? loc("ملصق شفاف") : loc("بطاقة"))
    }

    /// وجه البطاقة مصغّرًا. الملصق يُعرض فوق رماديٍّ يمثّل صورة صاحبه، وإلا بدا نصًّا
    /// معلّقًا في الفراغ لا ملصقًا شفّافًا يُحكَم على وضوحه قبل إرساله.
    private func face(_ card: FridayCard, scale: CGFloat) -> some View {
        ZStack {
            if card.design.isSticker { photoBackdrop }
            StoryCard(phrase: card.phrase, design: card.design)
                .frame(width: StoryCard.size.width, height: StoryCard.size.height)
                .scaleEffect(scale)
        }
        .frame(width: StoryCard.size.width * scale, height: StoryCard.size.height * scale)
        .clipped()
    }

    private var photoBackdrop: some View {
        LinearGradient(colors: [Color(hex: 0x9AA3AE), Color(hex: 0x5B6570), Color(hex: 0xC9CFD6)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: شكل المشاركة

    /// بطاقةٌ أم ملصق: الشريط كلّه يتبع الاختيار، فلا يُرى في المعرض شيء ويُرسل غيره.
    private var formPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                chip(loc("بطاقة"), icon: "rectangle.portrait", selected: !asSticker) { asSticker = false }
                chip(loc("ملصق شفاف"), icon: "rectangle.dashed", selected: asSticker) { asSticker = true }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("شكل المشاركة"))
            if asSticker {
                Text(loc("نصٌّ بلا خلفية، يُحفظ PNG شفّافًا — ألصقه فوق صورتك في سناب أو إكس."))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .animation(Motion.smooth, value: asSticker)
    }

    // MARK: شريط البطاقات

    private var gallery: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("بطاقات جاهزة"), tint: tint)
            ScrollView(.horizontal) {
                // كسولٌ عمدًا: كل مصغّرة بطاقةٌ حيّة بتدرّجها ونقشها، فلا تُرسم إلا ما دخل النظر.
                LazyHStack(spacing: 10) {
                    ForEach(Self.phrases.indices, id: \.self) { index in
                        thumbnail(index)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 1)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("بطاقات جاهزة"))
        }
    }

    private func thumbnail(_ index: Int) -> some View {
        let card = self.card(at: index)
        let on = index == chosen
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Button {
            chosen = index
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            face(card, scale: 0.088)
                .clipShape(shape)
                .overlay(shape.strokeBorder(on ? tint : Theme.hairline, lineWidth: on ? 2.5 : 0.5))
                .shadow(color: .black.opacity(on ? 0.16 : 0.06), radius: on ? 9 : 4, y: 3)
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(card.phrase.text)
        .accessibilityHint(loc("اختر البطاقة لمعاينتها ومشاركتها"))
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: الأزرار

    private func actions(_ card: FridayCard) -> some View {
        VStack(spacing: 10) {
            Button { shareCard(card) } label: {
                Label(asSticker ? loc("مشاركة الملصق") : loc("مشاركة البطاقة"),
                      systemImage: "square.and.arrow.up")
                    .font(Theme.display(16, weight: .semibold))
                    .gradientButton(Theme.goldGradient, glow: Theme.gold)
            }
            .pressable()

            HStack(spacing: 10) {
                Button {
                    Haptics.tap(enabled: store.hapticsEnabled)
                    designing = card.phrase
                } label: {
                    Label(loc("صمّمها"), systemImage: "paintbrush.pointed.fill")
                        .font(Theme.display(15, weight: .semibold))
                        .softButton(tint)
                }
                .pressable()

                Button {
                    UIPasteboard.general.string = card.phrase.shareText
                    Haptics.done(enabled: store.hapticsEnabled)
                    copied = true
                    copyGeneration += 1
                } label: {
                    Label(copied ? loc("تم النسخ") : loc("نسخ النص"),
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(Theme.display(15, weight: .semibold))
                        .softButton(copied ? Theme.success : tint)
                }
                .pressable()
            }
        }
        .padding(.top, 4)
    }

    /// لو غابت بيانات المصحف والحديث عن الحزمة لم يبقَ ما يُشارك — يُقال ذلك ولا تُترك الورقة خاوية.
    private var unavailable: some View {
        AtharCard(padding: 22) {
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.inkFaint)
                    .accessibilityHidden(true)
                Text(loc("لا بطاقات جاهزة الآن"))
                    .font(Theme.display(16, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(loc("تعذّر تحميل نصوص الجمعة من مصادرها."))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: أدوات

    private func chip(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            HStack(spacing: 6) {
                // الرمز زينةٌ إلى جانب الاسم؛ لولا إخفاؤه لسبق اسمُه النصَّ في القراءة.
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityHidden(true)
                Text(title).font(Theme.display(13, weight: .semibold))
            }
            .foregroundStyle(selected ? Theme.onAccent : Theme.inkSoft)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .tapTarget()
            .background(Capsule().fill(selected ? tint : Theme.surface))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shareCard(_ card: FridayCard) {
        Haptics.tap(enabled: store.hapticsEnabled)
        if card.design.isSticker {
            // الملصق يخرج ملفًّا لا صورة: بعض الوجهات تحوّل UIImage إلى JPEG فتذهب شفافيته.
            if let url = StoryCard.stickerFile(phrase: card.phrase, design: card.design) {
                share = StoryShareItem(payload: url)
            } else {
                renderFailed = true
            }
        } else if let image = StoryCard.render(phrase: card.phrase, design: card.design) {
            share = StoryShareItem(payload: image)
        } else {
            renderFailed = true
        }
    }
}
