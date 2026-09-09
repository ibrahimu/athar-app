import SwiftUI
import UIKit

/// مكتبة نصوص من مصادر التطبيق، مع بحث لا يتأثر بتشكيل العربية.
struct PhrasesView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false
    @State private var category: PhraseCategory?
    @State private var query = ""
    /// العبارة المفتوحة في مصمّم البطاقة (أو نصّ خاص فارغ يكتبه المستخدم).
    @State private var designing: Phrase?

    private var tint: Color { Theme.accent(for: category?.accentKey ?? "gold") }
    private var direction: LayoutDirection {
        AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection
    }
    private var phrases: [Phrase] {
        let key = ArabicSearch.key(query)
        return PhraseLibrary.phrases(in: category).filter {
            key.isEmpty || ArabicSearch.key($0.text + " " + $0.attribution + " " + $0.category.title).contains(key)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                introduction
                designYourOwn
                categories
                HStack {
                    Text(category?.title ?? "كل العبارات")
                        .font(Theme.display(16, weight: .bold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text("النصوص: \(phrases.count.counterText)")
                        .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                }
                if phrases.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    ForEach(phrases) { phrase in
                        PhraseCardView(phrase: phrase, fontScale: store.fontScale, haptics: store.hapticsEnabled) {
                            designing = phrase
                        }
                    }
                }
                Text("الآيات والأحاديث والأذكار من مصادرها في التطبيق. التهاني والمواساة عبارات عامة، ولا تُنسب إلى السنة.")
                    .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, Theme.gutter).padding(.top, 12).padding(.bottom, 32)
            .readableWidth(620)
        }
        .scrollIndicators(.hidden)
        .background { AtharBackground(tint: tint, secondary: Theme.gold) }
        .navigationTitle("عبارات")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "ابحث في النصوص والمصادر")
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .environment(\.layoutDirection, .rightToLeft)
        // مصمّم البطاقة: يُفتح بالشكل المعتمد، فالمشاركة الفورية ضغطة واحدة، والتخصيص لمن أراد.
        .sheet(item: $designing) { phrase in
            StoryDesignerView(phrase: phrase)
                .environment(\.layoutDirection, direction)
                .atharSheetChrome()
        }
    }

    /// نصّ خاص فوق صورة بشكل التطبيق: تهنئة أو كلمة يكتبها المستخدم ثم يختار لونها ونقشها وخطها.
    private var designYourOwn: some View {
        Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            designing = Phrase.custom("", category: .occasions)
        } label: {
            AtharCard(padding: 16, tint: Theme.accent(for: "calm")) {
                HStack(spacing: 14) {
                    IconChip(icon: "paintbrush.pointed.fill", tint: Theme.accent(for: "calm"), size: .md)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("صمّم تهنئتك")
                            .font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text("اكتب نصّك، واختر اللون والنقش والخط، وشاركه صورة")
                            .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .buttonStyle(.plain)
        .pressable()
    }

    private var introduction: some View {
        AtharCard(padding: 20, elevation: .e2, tint: Theme.gold) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "text.quote").foregroundStyle(Theme.gold)
                    Text("كلمة طيبة، وأثر يبقى")
                        .font(Theme.display(22, weight: .bold)).foregroundStyle(Theme.ink)
                }
                Text("آية تذكّر، ودعاء يطمئن، وكلمة تسعد من تحب. اختر نصًا وانسخه أو شاركه بصورة.")
                    .font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                Button {
                    category = PhraseLibrary.defaultCategory()
                    query = ""
                } label: {
                    Label("لوقتك الآن · \(PhraseLibrary.defaultCategory().title)", systemImage: "sparkles")
                        .font(Theme.display(12, weight: .semibold)).foregroundStyle(Theme.gold)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var categories: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                categoryButton(nil)
                ForEach(PhraseCategory.allCases) { categoryButton($0) }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 1)
    }

    private func categoryButton(_ value: PhraseCategory?) -> some View {
        let selected = category == value
        return Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            category = value
        } label: {
            Label(value?.title ?? "الكل", systemImage: value?.icon ?? "square.grid.2x2")
                .font(Theme.display(13, weight: .semibold))
                .foregroundStyle(selected ? Theme.onAccent : Theme.inkSoft)
                .padding(.horizontal, 14).frame(minHeight: 44)
                .background(Capsule().fill(selected ? Theme.accent : Theme.surface))
                .overlay(Capsule().strokeBorder(selected ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct PhraseCardView: View {
    let phrase: Phrase
    let fontScale: Double
    let haptics: Bool
    let onImage: () -> Void
    @State private var copied = false
    @State private var copyGeneration = 0
    private var tint: Color { Theme.accent(for: phrase.category.accentKey) }

    var body: some View {
        AtharCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label(phrase.category.title, systemImage: phrase.category.icon)
                            .font(Theme.display(11, weight: .semibold)).foregroundStyle(tint)
                        Spacer()
                        if !phrase.isSacred {
                            Text("عبارة عامة").font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                        }
                    }
                    Text(phrase.text)
                        .font(phrase.isSacred ? Theme.dhikrFont(size: 21, scale: fontScale) : Theme.display(18, weight: .medium))
                        .foregroundStyle(Theme.ink).lineSpacing(7)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                    if !phrase.attribution.isEmpty {
                        Text(phrase.attribution).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(20)
                Rectangle().fill(Theme.hairline).frame(height: 0.5)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) { actions }
                    VStack(spacing: 0) { actions }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
            }
        }
        .task(id: copyGeneration) {
            guard copied else { return }
            do { try await Task.sleep(for: .seconds(1.5)); copied = false } catch {}
        }
    }

    @ViewBuilder private var actions: some View {
        Button {
            UIPasteboard.general.string = phrase.shareText
            Haptics.done(enabled: haptics)
            copied = true; copyGeneration += 1
        } label: {
            actionLabel(copied ? "تم النسخ" : "نسخ", icon: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? Theme.success : tint)
        }
        .buttonStyle(.plain)
        ShareLink(item: phrase.shareText) {
            actionLabel("مشاركة", icon: "square.and.arrow.up").foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        Button(action: onImage) {
            actionLabel("بطاقة صورة", icon: "photo").foregroundStyle(tint)
        }
        .buttonStyle(.plain)
    }

    private func actionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(Theme.display(12, weight: .semibold))
            .fixedSize().frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
    }
}
