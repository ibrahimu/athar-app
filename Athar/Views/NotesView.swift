import SwiftUI

// MARK: - تدبّراتي

/// آيةٌ وما كُتب عليها — صفٌّ واحد في القائمة. يُبنى مرّةً من إسقاطة الأرشيف،
/// فلا يُسأل المخزنُ عن كل صفٍّ على حدة كلما أُعيد رسم الشاشة.
private struct NoteEntry: Identifiable, Equatable {
    let ref: AyahRef
    let text: String
    var id: String { ref.id }
}

/// ما كتبه القارئ على الآيات مجموعًا في موضع واحد — فالتدبّر المتفرّق في المصحف
/// كلّه لا يُنتفع به إن لم يكن له باب يُفتح.
struct NotesView: View {
    @EnvironmentObject private var store: AtharStore

    /// هوية الشاشة: بنفسجيّ الغسق — لون التأمّل في بقية التطبيق.
    private var tint: Color { Theme.accent(for: "dusk") }

    private var entries: [NoteEntry] {
        let all = store.notes
        return store.notedRefs.compactMap { ref in
            all[ref.id].map { NoteEntry(ref: ref, text: $0) }
        }
    }

    var body: some View {
        let rows = entries
        ZStack {
            AtharBackground(tint: tint)

            if rows.isEmpty {
                ContentUnavailableView(
                    loc("لا تدبّرات بعد"),
                    systemImage: "square.and.pencil",
                    description: Text(loc("انقر آيةً في المصحف ثم «اكتب تدبّرك» لتقيّد ما فُتح لك فيها."))
                )
            } else {
                // قائمة النظام لا كومةً في ScrollView: السحب للحذف من عندها،
                // والصفوف تبقى بطاقات أثر — خلفيةٌ شفّافة وبلا فواصل نظام.
                List {
                    ForEach(rows) { entry in
                        NavigationLink { SurahReaderView(surahId: entry.ref.surah, scrollTo: entry.ref) } label: {
                            row(entry)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 5, leading: Theme.gutter, bottom: 5, trailing: Theme.gutter))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.setNote(nil, for: entry.ref)
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
        .animation(Motion.smooth, value: rows)
        .navigationTitle(loc("تدبّراتي"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { NoteRecoveryView() } label: {
                    Label(loc("المحذوف والنسخ السابقة"), systemImage: "clock.arrow.circlepath")
                }
            }
        }
    }

    private func row(_ entry: NoteEntry) -> some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("سورة %1$@ · آية %2$@ · ص %3$@",
                         Quran.surah(entry.ref.surah)?.name ?? "",
                         entry.ref.ayah.counterText,
                         Quran.page(of: entry.ref).counterText))
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(tint)

                Text(NotesView.firstLine(entry.text))
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

    /// «2:255» مرجعُ آلةٍ لا عنوانُ قارئ؛ يُقرأ سورةً وآية.
    static func title(forReference reference: String) -> String {
        let parts = reference.split(separator: ":")
        guard parts.count == 2, let s = Int(parts[0]), let a = Int(parts[1]) else { return reference }
        return loc("سورة %1$@ · آية %2$@", Quran.surah(s)?.name ?? "", a.counterText)
    }
}

// MARK: - محرّر التدبّر

/// ورقة كتابة التدبّر على آية — تُفتح من خيارات الآية في المصحف.
struct AyahNoteEditor: View {
    let ref: AyahRef

    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var text = ""
    @State private var loaded = false
    @State private var deleted = false
    @State private var saved = true
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

                    // سطرٌ واحد خافت: الكتابة مقامُ سكينة لا موضعُ تقريرٍ عن الحفظ.
                    // يصمت على حقلٍ فارغ — لا خبر بعدُ — ويبقى مكانه محجوزًا فلا
                    // يقفز الزرّ تحته كلّما نطق.
                    Text(saved ? loc("محفوظ") : loc("يُحفظ تلقائيًا"))
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(text.isEmpty ? 0 : 1)
                        .animation(Motion.gentle, value: saved)

                    if store.notesNearCloudLimit {
                        Text(loc("قاربت التدبّرات سعة المزامنة؛ هي محفوظة على جهازك، وصدّر نسخةً من بياناتك."))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
                            deleted = true
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
            loaded = true
            try? await Task.sleep(for: .milliseconds(350))
            writing = true
        }
        .onChange(of: text) { _, _ in if loaded { saved = false } }
        // حفظٌ بعد سكتة الكاتب. مسوّدةٌ لا نسخةٌ دائمة: مجلسُ كتابةٍ واحد يُخلّف
        // في الأرشيف نسخةً واحدة، لا نسخةً عن كل سكتةٍ بين كلمتين.
        .task(id: text) {
            guard loaded, !deleted else { return }
            do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            store.setNote(text, for: ref, draft: true)
            saved = true
        }
        // إغلاق الورقة يُثبّت ما استقرّ عليه: ما بعده مجلسٌ جديد لا ذيلُ هذا.
        .onDisappear { if loaded && !deleted { store.setNote(text, for: ref) } }
        // ومغادرةُ التطبيق كإغلاقها: لو أُقفل وهو في الخلفية لم تبقَ مسوّدةً
        // معلّقة يطويها مجلسٌ آخر — والمسوّدات لا تُعرض في الاستعادة.
        .onChange(of: phase) { _, now in
            if now != .active, loaded, !deleted { store.setNote(text, for: ref) }
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

// MARK: - المحذوف والنسخ السابقة

/// ما كُتب يومًا ولم يعد ظاهرًا. لا يُعرض ليُنبش، بل ليطمئنّ من محا سطرًا بغير قصده.
private struct NoteRecoveryView: View {
    @EnvironmentObject private var store: AtharStore

    private var tint: Color { Theme.accent(for: "dusk") }

    /// أرقام غربية في تاريخ النسخة كما في بقية أرقام التطبيق، وميلاديٌّ صريح:
    /// هذا ختمُ ساعةٍ لا موعدَ عبادة، فلا يُحوَّل إلى الهجري.
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "d MMMM yyyy · HH:mm"
        return f
    }()

    var body: some View {
        let revisions = store.noteRecovery
        ZStack {
            AtharBackground(tint: tint)

            if revisions.isEmpty {
                ContentUnavailableView(
                    loc("لا نسخ سابقة"),
                    systemImage: "clock.arrow.circlepath",
                    description: Text(loc("ما تكتبه ثم تبدّله أو تمحوه يبقى هنا حتى تطمئنّ إليه."))
                )
            } else {
                List {
                    Section {
                        Text(loc("تبقى النسخ السابقة والمحذوفة هنا. الاستعادة تكتب نسخةً جديدة ولا تمحو ما هو قائم."))
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkSoft)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 8, leading: Theme.gutter, bottom: 4, trailing: Theme.gutter))
                    }
                    ForEach(revisions) { revision in
                        row(revision)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 5, leading: Theme.gutter, bottom: 5, trailing: Theme.gutter))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle(loc("استعادة التدبّرات"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
    }

    private func row(_ revision: NoteRevision) -> some View {
        AtharCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NotesView.title(forReference: revision.reference))
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(tint)

                Text(revision.text ?? "")
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    // النسخة المهاجرة من الصيغة القديمة لا تاريخ لها؛ لا يُختلق لها ختم.
                    if revision.date > .distantPast {
                        Text(Self.stamp.string(from: revision.date))
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 0)
                    Button(loc("استعادة")) {
                        store.restoreNote(revision)
                        Haptics.done(enabled: store.hapticsEnabled)
                    }
                    .font(Theme.display(14, weight: .semibold))
                    .foregroundStyle(tint)
                    .buttonStyle(.plain)
                    .tapTarget(36)
                }
            }
        }
        .readableWidth(620)
    }
}
