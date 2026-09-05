import SwiftUI

// MARK: - ورقة التفسير

/// ورقة التفسير تنزلق من إجراءات الآية: الآية أولًا، ثم اختيار الكتاب، ثم النص.
/// السعدي للمعنى العام الميسّر، والجلالين للبيان الموجز — وكلاهما تراث عام.
/// تتنقّل بين آيات السورة بالسهمين دون إغلاق، فيقرأ المتدبّر السياق متّصلًا.
struct TafsirSheet: View {
    /// لوحة جانبية داخل القارئ (iPad): بلا زرّ إغلاق، وتتبع الآية الجارية.
    var inline: Bool = false
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    /// الآية المعروضة — تبدأ بما فُتحت عليه الورقة وتتحرّك داخل السورة نفسها فقط.
    @State private var current: AyahRef
    /// الكتاب المختار يبقى بين الفتحات، في مجموعة التطبيق المشتركة كسائر الإعدادات.
    @AppStorage("athar.tafsir.edition", store: UserDefaults(suiteName: AtharStore.appGroup))
    private var edition: TafsirEdition = .saadi
    /// تأكيد «نُسخ» يظهر لحظةً على الزرّ ثم يعود.
    @State private var copied = false

    init(ref: AyahRef, inline: Bool = false) {
        self.inline = inline
        _current = State(initialValue: ref)
    }

    private var tint: Color { Theme.accent(for: "sea") }
    private var surahName: String { Quran.surah(current.surah)?.name ?? "" }
    private var ayahCount: Int { Quran.surah(current.surah)?.ayahCount ?? current.ayah }
    /// تُحلّ مرة عند كل تغيّر للآية أو الكتاب لا في كل رسمة: قراءة ملف السورة (حتى نصف ميغا
    /// للبقرة) وفكّ الإحالات لا يليقان بجسم العرض.
    @State private var resolved: TafsirEntry?
    @ObservedObject private var ayahAudio = AyahAudio.shared
    @ObservedObject private var speaker = TafsirSpeaker.shared
    private var entry: TafsirEntry? { resolved }
    private func resolve() {
        resolved = Tafsir.entry(edition, for: current)
        applySoundMode()
    }

    /// خيار المستخدم: تلاوة الآية عند فتحها، أو قراءة تفسيرها بصوت الجهاز، أو لا شيء.
    private func applySoundMode() {
        switch store.ayahSoundMode {
        case .none:
            break
        case .recite:
            speaker.stop()
            ayahAudio.stopAt = current            // آية واحدة لا السورة كلها
            ayahAudio.play(from: current)
        case .tafsir:
            ayahAudio.stop()
            if let e = resolved { speaker.speak(e.text, marks: e.edition.quoteMarks) }
        }
    }

    private var soundActive: Bool {
        (ayahAudio.isActive && ayahAudio.current == current) || speaker.speaking
    }

    private func toggleSound() {
        if soundActive { ayahAudio.stop(); speaker.stop(); return }
        switch store.ayahSoundMode {
        case .none, .recite:
            ayahAudio.stopAt = current
            ayahAudio.play(from: current)
        case .tafsir:
            if let e = resolved { speaker.speak(e.text, marks: e.edition.quoteMarks) }
        }
    }
    private var rangeTitle: String {
        entry?.rangeTitle ?? loc("الآية %1$@", current.ayah.counterText)
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: Theme.Space.lg) {
                        header.id("top")
                        ayahCard
                        editionPicker
                        if let entry {
                            TafsirTextCard(entry: entry, scale: store.fontScale)
                            actionRow(for: entry)
                        } else {
                            emptyState
                        }
                        attribution
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 22)        // تحت مؤشّر السحب الذي يرسمه النظام
                    .padding(.bottom, 28)
                    .readableWidth()
                }
                .scrollIndicators(.hidden)
                .task { resolve() }
                .onDisappear { ayahAudio.stop(); speaker.stop() }   // لا صوت يتيم بعد إغلاق الورقة
                .onChange(of: edition) { _, _ in resolve() }
                .onChange(of: current) { _, _ in
                    resolve()
                    // آية جديدة تبدأ من أعلى الورقة لا من حيث توقّف تمرير السابقة.
                    withAnimation(Motion.smooth) { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
        .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
    }

    // MARK: الرأس

    private var header: some View {
        HStack(spacing: 12) {
            IconChip(icon: "text.book.closed.fill", tint: tint, size: .md)
            VStack(alignment: .leading, spacing: 2) {
                Text(loc("التفسير"))
                    .font(Theme.display(18, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("\(surahName) · \(rangeTitle)")
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            Spacer(minLength: 8)
            // الصوت: زرّ تشغيل/إيقاف بحسب الخيار، وقائمة تختار الخيار (يُحفظ).
            Button { toggleSound() } label: {
                Image(systemName: soundActive ? "stop.fill" : (store.ayahSoundMode == .tafsir ? "text.bubble.fill" : "play.fill"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(soundActive ? Theme.onAccent : tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(soundActive ? tint : tint.opacity(0.12)))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .pressable(scale: 0.9)
            .accessibilityLabel(soundActive ? loc("إيقاف الصوت") : (store.ayahSoundMode == .tafsir ? loc("قراءة التفسير بالصوت") : loc("تلاوة الآية")))
            Menu {
                ForEach(AyahSoundMode.allCases) { m in
                    Button {
                        store.ayahSoundMode = m
                        ayahAudio.stop(); speaker.stop()
                        applySoundMode()
                    } label: {
                        if store.ayahSoundMode == m { Label(m.title, systemImage: "checkmark") } else { Label(m.title, systemImage: m.icon) }
                    }
                }
            } label: {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.surfaceAlt))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(loc("خيار الصوت عند فتح الآية: %1$@", store.ayahSoundMode.title))
            if !inline { Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Theme.surfaceAlt))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .pressable(scale: 0.9)
            .accessibilityLabel(loc("إغلاق"))
            }
        }
    }

    // MARK: بطاقة الآية

    /// الآية سيّدة البطاقة بخطّ النسخ ولون الحبر، وتحتها متصفّح الآيات:
    /// السابقة على اليمين والتالية على اليسار، كاتجاه القراءة.
    private var ayahCard: some View {
        AtharCard(padding: Theme.Space.lg, elevation: .e2) {
            VStack(spacing: Theme.Space.md) {
                Capsule().fill(Theme.goldGradient)
                    .frame(width: 46, height: 3)
                    .opacity(0.8)

                Text(Quran.text(current) ?? "")
                    .font(Theme.dhikrFont(size: 20, scale: store.fontScale))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)

                HStack(spacing: Theme.Space.sm) {
                    pagerButton("chevron.backward", enabled: current.ayah > 1,
                                label: loc("الآية السابقة")) { step(-1) }
                    Text(loc("الآية %1$@", current.ayah.counterText))
                        .font(Theme.display(13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .frame(maxWidth: .infinity)
                    pagerButton("chevron.forward", enabled: current.ayah < ayahCount,
                                label: loc("الآية التالية")) { step(1) }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func pagerButton(_ icon: String, enabled: Bool, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? tint : Theme.inkFaint.opacity(0.4))
                .frame(width: 36, height: 36)
                .background(Circle().fill(tint.opacity(enabled ? 0.12 : 0.05)))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .pressable(scale: 0.9)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// التنقّل محصور في السورة المفتوحة — عبور السور من إجراءات الآية لا من هنا.
    private func step(_ delta: Int) {
        let target = current.ayah + delta
        guard target >= 1, target <= ayahCount else { return }
        withAnimation(Motion.smooth) { current = AyahRef(surah: current.surah, ayah: target) }
        copied = false
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    // MARK: اختيار الكتاب

    private var editionPicker: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ForEach(TafsirEdition.allCases) { e in
                    let on = edition == e
                    Button {
                        guard !on else { return }
                        edition = e
                        copied = false
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        Text(e.title)
                            .font(Theme.display(14, weight: on ? .semibold : .regular))
                            .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                                .fill(on ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.surfaceAlt)))
                    }
                    .pressable()
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text(edition.subtitle)
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
        }
        .animation(Motion.snappy, value: edition)
    }

    // MARK: النسخ والمشاركة

    private func actionRow(for entry: TafsirEntry) -> some View {
        HStack(spacing: Theme.Space.sm) {
            Button {
                UIPasteboard.general.string = copyText(entry)
                Haptics.done(enabled: store.hapticsEnabled)
                withAnimation(Motion.snappy) { copied = true }
                // يعود الزرّ إلى «نسخ» بعد لحظة تكفي لرؤية التأكيد.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(Motion.snappy) { copied = false }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? loc("نُسخ") : loc("نسخ"))
                }
                .font(Theme.display(15, weight: .semibold))
                .softButton(copied ? Theme.success : tint)
            }
            .pressable()
            .accessibilityLabel(loc("نسخ التفسير"))

            ShareLink(item: shareText(entry)) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text(loc("مشاركة"))
                }
                .font(Theme.display(15, weight: .semibold))
                .softButton(tint)
            }
            .pressable()
            .accessibilityLabel(loc("مشاركة التفسير"))
        }
    }

    /// «تفسير السعدي — الفاتحة:2» أو «الآيات 4–7» حين يشرح المفسّر آياتٍ مجتمعةً.
    private func locator(_ entry: TafsirEntry) -> String {
        let ayahs = entry.coversRange
            ? "\(entry.coversFrom.counterText)–\(entry.coversTo.counterText)"
            : entry.ref.ayah.counterText
        return "\(entry.edition.title) — \(surahName):\(ayahs)"
    }

    /// نصّ للنسخ والمشاركة: أقواس المصدر { } تُبدَّل بالقوسين المزخرفين ﴿ ﴾ المعهودين
    /// في الاستشهاد بالآيات (الحاسوب يعرضهما بخطوطه، بخلاف خطّنا المضمَّن).
    private func exportable(_ entry: TafsirEntry) -> String {
        let m = entry.edition.quoteMarks
        var out = ""
        for ch in entry.text {
            if ch == m.open { out.append("﴿ ") } else if ch == m.close { out.append(" ﴾") } else { out.append(ch) }
        }
        return out.replacingOccurrences(of: "﴿  ", with: "﴿ ").replacingOccurrences(of: "  ﴾", with: " ﴾")
    }

    private func copyText(_ entry: TafsirEntry) -> String {
        "\(exportable(entry))\n\n\(locator(entry))"
    }

    private func shareText(_ entry: TafsirEntry) -> String {
        "\(Quran.text(current) ?? "")\n[\(surahName): \(current.ayah.counterText)]\n\n\(exportable(entry))\n\n\(locator(entry))\n\nمن تطبيق أثر"
    }

    // MARK: الحالة الفارغة والعزو

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Theme.inkFaint)
            Text(loc("لا تفسير متاح لهذه الآية"))
                .font(Theme.display(15, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(Tafsir.isAvailable(edition)
                 ? loc("جرّب الكتاب الآخر أو آيةً مجاورة.")
                 : loc("نصوص هذا الكتاب غير مضمّنة في هذه النسخة."))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var attribution: some View {
        VStack(spacing: 5) {
            Text(edition.fullTitle)
                .font(Theme.display(12, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            Text(edition.author)
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
            Text(loc("تراث عام"))
                .font(Theme.display(10, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(Capsule().fill(Theme.surfaceAlt))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - بطاقة نصّ التفسير

/// نصّ التفسير في بطاقته. ابنُ قيمٍ: ألوان الطابع تُمرَّر إليه قيمًا لا تُقرأ ساكنةً
/// في الجسم، وإلا تخطّى SwiftUI إعادة رسمه بعد تبديل الثيم (قاعدة CardSurface).
private struct TafsirTextCard: View {
    let entry: TafsirEntry
    let scale: Double
    var ink: Color = Theme.ink
    var accent: Color = Theme.accent
    var faint: Color = Theme.inkFaint

    var body: some View {
        AtharCard {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack(spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 11, weight: .semibold))
                    Text(entry.rangeTitle)
                        .font(Theme.display(12, weight: .semibold))
                    Spacer(minLength: 0)
                    if entry.coversRange {
                        Text(loc("شرحٌ للآيات مجتمعةً"))
                            .font(Theme.display(11))
                            .foregroundStyle(faint)
                    }
                }
                .foregroundStyle(accent)

                Text(TafsirMarkup.attributed(entry.text, marks: entry.edition.quoteMarks,
                                             size: 17, scale: scale, ink: ink, accent: accent))
                    .font(Theme.dhikrFont(size: 17, scale: scale))
                    .foregroundStyle(ink)
                    .lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - إبراز الاستشهاد بالآيات

/// تهيئة نصّ التفسير للعرض: ما بين قوسي الاستشهاد في الكتاب يُبرَز بلون الطابع
/// ووزن أثقل، وتُوحَّد أقواسه على ﴿ ﴾ في الكتابين (السعدي يستعمل { } في مصدره).
/// النص نفسه لا يُمسّ — الأقواس علامات طباعية والفراغات الملاصقة لها فقط تُشذَّب.
enum TafsirMarkup {
    static func attributed(_ text: String, marks: (open: Character, close: Character),
                           size: CGFloat, scale: Double, ink: Color, accent: Color) -> AttributedString {
        var segments: [(text: String, quoted: Bool)] = []
        var buffer = ""
        var inQuote = false
        for ch in text {
            if !inQuote, ch == marks.open {
                if !buffer.isEmpty { segments.append((text: buffer, quoted: false)) }
                buffer = ""
                inQuote = true
            } else if inQuote, ch == marks.close {
                segments.append((text: buffer, quoted: true))
                buffer = ""
                inQuote = false
            } else {
                buffer.append(ch)
            }
        }
        // قوس فُتح ولم يُغلق (سهو طباعي في المصدر): ما بعده كلامُ المفسّر لا آية،
        // فيُعرض عاديًّا — لئلا يُلبَس كلام البشر لباس القرآن.
        if !buffer.isEmpty { segments.append((text: buffer, quoted: false)) }

        var out = AttributedString()
        for seg in segments {
            if seg.quoted {
                let inner = seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !inner.isEmpty else { continue }
                // بلا قوسين مزخرفين: خطّ Noto Naskh المضمَّن لا يحوي ﴿ ﴾ فتظهر نقاطًا صغيرة
                // مشوّهة. اللون ووزن الخط كافيان لتمييز الآية، وبينها وبين ما حولها فراغ.
                var run = AttributedString(inner)
                run.foregroundColor = accent
                run.font = Theme.naskhFont(size: size, scale: scale)
                out.append(run)
            } else {
                // قوس إغلاق بلا فتح: علامة طباعية شاردة تُحذف من العرض لا من النص.
                var plain = seg.text
                plain.removeAll { $0 == marks.close || $0 == marks.open }
                var run = AttributedString(plain)
                run.foregroundColor = ink
                run.font = Theme.dhikrFont(size: size, scale: scale)
                out.append(run)
            }
        }
        return out
    }
}

/// بروتوكول صفوف الاختيار يعيش في التطبيق لا في Shared (الودجة لا تعرفه).
extension AyahSoundMode: SettingsChoice {}
