import SwiftUI

// MARK: - تدبّراتي

/// ما كتبه القارئ على الآيات مجموعًا في موضع واحد — فالتدبّر المتفرّق في المصحف
/// كلّه لا يُنتفع به إن لم يكن له باب يُفتح.
struct NotesView: View {
    @EnvironmentObject private var store: AtharStore

    /// هوية الشاشة: بنفسجيّ الغسق — لون التأمّل في بقية التطبيق.
    private var tint: Color { Theme.accent(for: "dusk") }

    private var refs: [AyahRef] { store.notedRefs }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint)

            if refs.isEmpty {
                ContentUnavailableView(
                    loc("لا تدبّرات بعد"),
                    systemImage: "square.and.pencil",
                    description: Text(loc("انقر آيةً في المصحف ثم «اكتب تدبّرك» لتقيّد ما فُتح لك فيها."))
                )
            } else {
                // قائمة النظام لا كومةً في ScrollView: السحب للحذف من عندها،
                // والصفوف تبقى بطاقات أثر — خلفيةٌ شفّافة وبلا فواصل نظام.
                List {
                    ForEach(refs) { ref in
                        NavigationLink { SurahReaderView(surahId: ref.surah, scrollTo: ref) } label: {
                            row(ref)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: Theme.gutter, bottom: 5, trailing: Theme.gutter))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.setNote(nil, for: ref)
                                Haptics.tap(enabled: store.hapticsEnabled)
                            } label: {
                                Label(loc("حذف"), systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .animation(Motion.smooth, value: refs)
        .navigationTitle(loc("تدبّراتي"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private func row(_ ref: AyahRef) -> some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("سورة %1$@ · آية %2$@ · ص %3$@",
                         Quran.surah(ref.surah)?.name ?? "",
                         ref.ayah.counterText,
                         Quran.page(of: ref).counterText))
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(tint)

                Text(NotesView.firstLine(store.note(for: ref) ?? ""))
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .readableWidth(620)
    }

    /// أوّل سطرٍ من التدبّر — ما بعده يُقرأ في موضعه من المصحف.
    static func firstLine(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: true).first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }
}

// MARK: - محرّر التدبّر

/// ورقة كتابة التدبّر على آية — تُفتح من خيارات الآية في المصحف.
struct AyahNoteEditor: View {
    let ref: AyahRef

    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var writing: Bool

    private var tint: Color { Theme.accent(for: "dusk") }
    private var existing: String? { store.note(for: ref) }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint)
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    ayahCard

                    TextField(loc("اكتب ما فُتح لك في هذه الآية…"), text: $text, axis: .vertical)
                        .font(Theme.display(16, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(4...14)
                        .focused($writing)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.surfaceAlt))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
                        .accessibilityLabel(loc("تدبّرك في الآية"))

                    Label(loc("تدبّرك لك وحدك — يبقى في جهازك ولا يُرسل إلى أحد."), systemImage: "lock.fill")
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        store.setNote(text, for: ref)
                        Haptics.done(enabled: store.hapticsEnabled)
                        dismiss()
                    } label: {
                        Text(loc("حفظ"))
                            .font(Theme.display(16, weight: .semibold))
                            .gradientButton(Theme.accentGradient, glow: Theme.accent)
                    }
                    .pressable()

                    if existing != nil {
                        Button(role: .destructive) {
                            store.setNote(nil, for: ref)
                            Haptics.tap(enabled: store.hapticsEnabled)
                            dismiss()
                        } label: {
                            Text(loc("حذف التدبّر"))
                                .font(Theme.display(15, weight: .medium))
                                .softButton(Theme.danger)
                        }
                        .pressable()
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, Theme.Space.xl)
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        // القلم أوّل ما يُطلب هنا؛ ولوحة المفاتيح لا ترتفع إن طُلب التركيز قبل
        // استقرار الورقة، فتُمهَل لحظة ثم يُنقر الحقل من تلقائه.
        .task {
            text = existing ?? ""
            try? await Task.sleep(for: .milliseconds(350))
            writing = true
        }
        .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
    }

    /// الآية فوق الحقل: يُكتب التدبّر والنصّ بين يديه.
    private var ayahCard: some View {
        AtharCard(padding: Theme.Space.lg, elevation: .e2) {
            VStack(spacing: Theme.Space.sm) {
                Text(loc("%1$@ · الآية %2$@", Quran.surah(ref.surah)?.name ?? "", ref.ayah.counterText))
                    .font(Theme.display(13, weight: .semibold))
                    .foregroundStyle(tint)
                Text(Quran.text(ref) ?? "")
                    .font(Theme.dhikrFont(size: 19))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
