import SwiftUI
import UIKit

/// ما يُشارك من بطاقة القصّة: صورة (البطاقة)، أو ملف PNG (الملصق الشفّاف — حتى لا تضيع شفافيته).
struct StoryShareItem: Identifiable {
    let id = UUID()
    let payload: Any
}

/// مصمّم بطاقة القصّة: معاينة حيّة، ثم الشكل واللون والنقش والخط والتوقيع — أو مشاركة فورية
/// بالشكل المعتمد كما يُفتح. النص الشرعي لا يُحرَّر ولا يغيّر خطّه (النسخ دائمًا)؛ العبارات
/// العامة والنص الخاص تُكتب هنا وتُغيَّر خطوطها.
struct StoryDesignerView: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?

    private enum Field { case text, signature }

    let base: Phrase
    @State private var text: String
    @State private var design: StoryDesign = .standard
    @State private var share: StoryShareItem?
    @State private var renderFailed = false
    @State private var copied = false
    @State private var copyGeneration = 0

    init(phrase: Phrase) {
        base = phrase
        _text = State(initialValue: phrase.text)
    }

    /// النص الشرعي كما هو من مصدره؛ غيره من الحقل.
    private var phrase: Phrase {
        if base.isSacred { return base }
        return Phrase.custom(text.trimmingCharacters(in: .whitespacesAndNewlines), category: base.category, id: base.id)
    }
    private var canShare: Bool { !phrase.text.isEmpty }
    private var tint: Color { Theme.accent(for: base.category.accentKey) }
    private var direction: LayoutDirection {
        AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    preview
                    if !base.isSacred { textEditor }
                    layoutPicker
                    if design.isSticker { stickerInkPicker } else { colorPicker }
                    if design.isSticker && design.stickerInk == .theme { colorPicker }
                    if !design.isSticker { patternPicker }
                    fontPicker
                    signatureField
                    shareButtons
                }
                .animation(Motion.smooth, value: design.isSticker)
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 12)
                .padding(.bottom, 32)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background { AtharBackground(tint: tint) }
            .navigationTitle(loc("بطاقة صورة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("إغلاق")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { shareImage() } label: {
                        Label(loc("مشاركة"), systemImage: "square.and.arrow.up")
                    }
                    .disabled(!canShare)
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
        .environment(\.layoutDirection, direction)
    }

    // MARK: المعاينة

    /// البطاقة نفسها التي تُصيَّر، مصغّرة — فما يُرى هو ما يُشارك بالحرف. الملصق يُعرض فوق
    /// «صورة» رمادية مموّهة تمثّل صورة المستخدم، فيُرى أنه شفّاف وأن ظلّه يُبقيه مقروءًا.
    private var preview: some View {
        let scale: CGFloat = 0.27
        return ZStack {
            if design.isSticker {
                LinearGradient(colors: [Color(hex: 0x9AA3AE), Color(hex: 0x5B6570), Color(hex: 0xC9CFD6)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                VStack {
                    Spacer()
                    Text(loc("يُلصق فوق أي صورة في سناب أو إنستغرام"))
                        .font(Theme.display(11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.bottom, 12)
                }
            }
            StoryCard(phrase: phrase, design: design)
                .frame(width: StoryCard.size.width, height: StoryCard.size.height)
                .scaleEffect(scale)
        }
        .frame(width: StoryCard.size.width * scale, height: StoryCard.size.height * scale)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
        .padding(.top, 4)
        .animation(Motion.smooth, value: design)
        // البطاقة صورةٌ تُصيَّر، لا نصٌّ يُقرأ: تُطوى في عنصر واحد يسمّي ما اختير فيها،
        // وإلا سمع مستعمل VoiceOver العبارةَ مكرّرةً بلا خبر عن الشكل واللون.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(previewLabel)
    }

    /// وصف المعاينة: ما لا يُرى يُقال. الملصق بلا خلفية فلا نقش له ولا لون بطاقة.
    private var previewLabel: String {
        design.isSticker
            ? loc("معاينة البطاقة — الشكل %1$@، لون النص %2$@، الخط %3$@",
                  design.layout.title, design.stickerInk.title, design.font.title)
            : loc("معاينة البطاقة — الشكل %1$@، اللون %2$@، النقش %3$@، الخط %4$@",
                  design.layout.title, design.theme.title, design.pattern.title, design.font.title)
    }

    // MARK: النص الخاص

    private var textEditor: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("النص"), tint: tint)
            SettingsCard {
                TextField(loc("اكتب تهنئتك أو كلمتك…"), text: $text, axis: .vertical)
                    .font(Theme.display(16))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2...6)
                    .multilineTextAlignment(.leading)
                    .focused($focus, equals: .text)
                    .padding(16)
            }
            Text(loc("عبارة عامة من عندك — لا تُنسب إلى القرآن أو السنة."))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: الشكل

    private var layoutPicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الشكل"), tint: tint)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(StoryDesign.Layout.allCases) { layout in
                        chip(layout.title, icon: layout.icon, selected: design.layout == layout) {
                            design.layout = layout
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 1)
            // صفّ الرقائق مجموعةٌ واحدة باسمها، فلا تتناثر خياراتها بلا سياق يجمعها.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("الشكل"))
            if design.isSticker {
                Text(loc("نصّ وحده بلا خلفية — يُحفظ PNG شفّافًا، فأضفه ملصقًا فوق صورتك."))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: لون نص الملصق

    private var stickerInkPicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("لون النص"), tint: tint)
            HStack(spacing: 8) {
                ForEach(StoryDesign.StickerInk.allCases) { ink in
                    chip(ink.title, selected: design.stickerInk == ink) { design.stickerInk = ink }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("لون النص"))
        }
    }

    // MARK: اللون

    /// طوابع التطبيق نفسها — البطاقة بلون طابعك أو أيّ طابع آخر.
    private var colorPicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("اللون"), tint: tint)
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(AppTheme.allCases) { theme in
                        let on = design.theme == theme
                        let a = Color(hex: theme.accent.light), b = Color(hex: theme.accent2.light)
                        Button {
                            design.theme = theme
                            Haptics.tap(enabled: store.hapticsEnabled)
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(LinearGradient(colors: [b, a], startPoint: .top, endPoint: .bottom))
                                    .frame(width: 40, height: 40)
                                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: on ? 3 : 0))
                                    .overlay(Circle().strokeBorder(on ? a : .clear, lineWidth: 2).padding(-3))
                                    .overlay {
                                        if on {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                Text(theme.title)
                                    .font(Theme.display(11, weight: on ? .semibold : .regular))
                                    .foregroundStyle(on ? Theme.ink : Theme.inkSoft)
                                    .lineLimit(1)
                            }
                            .frame(width: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(theme.title)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 1)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("اللون"))
        }
    }

    // MARK: النقش

    private var patternPicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("النقش"), tint: tint)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(BackgroundPattern.allCases) { pattern in
                        chip(pattern.title, selected: design.pattern == pattern) {
                            design.pattern = pattern
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 1)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("النقش"))
        }
    }

    // MARK: الخط

    /// كل رقاقة مكتوبة بخطّها. النص الشرعي يبقى بالنسخ؛ الخط هنا للعبارات العامة والتوقيع.
    private var fontPicker: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الخط"), tint: tint)
            HStack(spacing: 8) {
                ForEach(AppFont.allCases) { font in
                    chip(font.title, selected: design.font == font, font: font.font(size: 14, weight: .semibold)) {
                        design.font = font
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(loc("الخط"))
            if base.isSacred {
                Text(loc("القرآن والحديث والذكر بخط النسخ دائمًا؛ الخط هنا للتوقيع."))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: التوقيع

    private var signatureField: some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("توقيع"), tint: tint)
            SettingsCard {
                TextField(loc("اسمك أو إهداء (اختياري)"), text: $design.signature)
                    .font(Theme.display(16))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .focused($focus, equals: .signature)
                    .submitLabel(.done)
                    .padding(16)
            }
        }
    }

    // MARK: المشاركة

    private var shareButtons: some View {
        VStack(spacing: 10) {
            Button(action: shareImage) {
                Label(design.isSticker ? loc("مشاركة الملصق") : loc("مشاركة الصورة"), systemImage: "square.and.arrow.up")
                    .font(Theme.display(16, weight: .semibold))
                    .gradientButton()
            }
            .pressable()
            .disabled(!canShare)
            .opacity(canShare ? 1 : 0.5)

            Button {
                UIPasteboard.general.string = phrase.shareText
                Haptics.done(enabled: store.hapticsEnabled)
                copied = true
                copyGeneration += 1
            } label: {
                Label(copied ? loc("تم النسخ") : loc("نسخ النص"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(Theme.display(15, weight: .semibold))
                    .softButton(copied ? Theme.success : tint)
            }
            .pressable()
            .disabled(!canShare)
        }
        .padding(.top, 6)
    }

    // MARK: أدوات

    private func chip(_ title: String, icon: String? = nil, selected: Bool, font: Font? = nil,
                      action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            HStack(spacing: 6) {
                // الرمز زينةٌ إلى جانب الاسم؛ لولا إخفاؤه لسبق اسمُه النصَّ في القراءة.
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                        .accessibilityHidden(true)
                }
                Text(title).font(font ?? Theme.display(13, weight: .semibold))
            }
            .foregroundStyle(selected ? Theme.onAccent : Theme.inkSoft)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .frame(maxWidth: icon == nil ? nil : .infinity)
            .background(Capsule().fill(selected ? tint : Theme.surface))
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func shareImage() {
        focus = nil
        guard canShare else { return }
        Haptics.tap(enabled: store.hapticsEnabled)
        if design.isSticker {
            if let url = StoryCard.stickerFile(phrase: phrase, design: design) {
                share = StoryShareItem(payload: url)
            } else {
                renderFailed = true
            }
        } else if let image = StoryCard.render(phrase: phrase, design: design) {
            share = StoryShareItem(payload: image)
        } else {
            renderFailed = true
        }
    }
}
