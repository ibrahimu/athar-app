import SwiftUI

// MARK: - أدوات الملف

/// السطر الأول من نصّ الحكم — للمعاينة في القائمة دون قصّ كلمة في منتصفها.
private func ahkamFirstLine(_ text: String) -> String {
    text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? text
}

/// نصّ الحكم كاملًا للنسخ والمشاركة: العنوان، ثم الحكم، ثم أدلّته من مصدرها،
/// ثم رابط الفتوى إن وُجد. النصوص الشرعية تُقرأ من ملفّاتها لا تُكتب هنا.
private func ahkamShareText(_ item: AhkamItem) -> String {
    var lines: [String] = [item.title, "", item.body]
    let quran = item.evidence.filter(\.isQuran)
    let hadith = item.evidence.filter { !$0.isQuran }
    if !quran.isEmpty || !hadith.isEmpty { lines.append(""); lines.append("الدليل:") }
    for ev in quran {
        for ref in ev.ayahRefs {
            guard let text = Quran.text(ref) else { continue }
            let name = Quran.surah(ref.surah)?.name ?? ""
            lines.append("﴿ \(text) ﴾ [سورة \(name): \(ref.ayah.counterText)]")
        }
    }
    for ev in hadith {
        guard let text = ev.text, !text.isEmpty else { continue }
        if let src = ev.source, !src.isEmpty { lines.append("«\(text)» — \(src)") }
        else { lines.append("«\(text)»") }
    }
    if let fatwa = item.fatwa {
        lines.append("")
        lines.append("للتوسّع: فتوى \(fatwa.scholar) — \(fatwa.title)")
        lines.append(fatwa.url)
    }
    lines.append("")
    lines.append("من تطبيق أثر")
    return lines.joined(separator: "\n")
}

// MARK: - الأحكام — الشاشة الرئيسة

/// أحكام عملية بدليلها: بطاقة تعريف، ثم بلاطات المواضيع (الطهارة، الصلاة، الصيام…).
/// البيانات من ahkam.json، وقد يكون فارغًا أثناء البناء فتُعرض الشاشة هادئةً بلا عطل.
struct AhkamView: View {
    /// حين يكون تبويبًا في الشريط السفلي يبقى الشريط ظاهرًا.
    var isRootTab = false
    /// الشاشة تقرأ ألوان الطابع ساكنةً؛ مراقبة المخزن تُعيد رسمها فور تبديل الطابع.
    @EnvironmentObject private var store: AtharStore

    private var tint: Color { Theme.accent(for: "green") }
    private var topics: [AhkamTopic] { AhkamLibrary.topics }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 14) {
                    intro.appearStagger(0)
                    if topics.isEmpty {
                        emptyState.appearStagger(1)
                    } else {
                        grid
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("الأحكام"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }

    /// بطاقة التعريف: ملاحظة الملف إن وُجدت، وإلا سطر واحد يشرح القسم.
    private var intro: some View {
        let note = AhkamLibrary.note.trimmingCharacters(in: .whitespacesAndNewlines)
        return AtharCard(padding: 16, elevation: .e2, tint: tint) {
            HStack(alignment: .top, spacing: 14) {
                IconChip(icon: "list.bullet.clipboard.fill", tint: tint, size: .lg)
                VStack(alignment: .leading, spacing: 5) {
                    Text(loc("الأحكام العملية"))
                        .font(Theme.display(18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(note.isEmpty ? loc("أحكام عملية بدليلها") : note)
                        .font(Theme.display(13))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// حالة فارغة هادئة — الملف قد يكون بلا مواضيع أثناء التطوير.
    private var emptyState: some View {
        AtharCard(padding: 22) {
            VStack(spacing: 8) {
                Image(systemName: "text.badge.checkmark")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.inkFaint)
                Text(loc("لا أحكام مضافة بعد"))
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// بلاطات المواضيع في عمودين — كشاشة «الأقسام».
    private var grid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top),
                            GridItem(.flexible(), spacing: 12, alignment: .top)], spacing: 12) {
            ForEach(Array(topics.enumerated()), id: \.element.id) { i, topic in
                let color = Theme.accent(for: topic.accent)
                NavigationLink {
                    AhkamTopicView(topic: topic)
                } label: {
                    AhkamTopicTile(topic: topic, tint: color)
                }
                .pressable()
                .appearStagger(i + 1)
            }
        }
        // الشبكة الكسولة تخبّئ بلاطاتها بألوان الطابع السابق؛ المفتاح يعيد بناءها مع الثيم.
        .id("\(store.appTheme.rawValue)-\(store.unifyIcons)")
    }
}

// MARK: - بلاطة موضوع

/// بلاطة موضوع: رقاقة كبيرة بلون الموضوع، عنوان، ووصف بسطرين محجوزين
/// حتى تشترك بلاطات الصفّ في ارتفاع واحد.
private struct AhkamTopicTile: View {
    let topic: AhkamTopic
    /// اللون يُمرَّر قيمةً من الأب لا يُقرأ ساكنًا، ليُعاد رسم البلاطة فور تبديل الطابع.
    let tint: Color

    var body: some View {
        AtharCard(padding: 14, tint: tint) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                IconChip(icon: topic.icon, tint: tint, size: .lg)
                Text(topic.title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(topic.summary)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - موضوع: أقسامه وأحكامه

/// فقرة تعريف بالموضوع، ثم كل قسم عنوانًا صغيرًا وبطاقةً تضمّ أحكامه.
struct AhkamTopicView: View {
    let topic: AhkamTopic
    @EnvironmentObject private var store: AtharStore

    private var tint: Color { Theme.accent(for: topic.accent) }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 18) {
                    header.appearStagger(0)
                    if topic.sections.isEmpty {
                        Text(loc("لا أحكام في هذا الموضوع بعد"))
                            .font(Theme.display(13))
                            .foregroundStyle(Theme.inkFaint)
                            .padding(.top, 6)
                            .appearStagger(1)
                    }
                    ForEach(Array(topic.sections.enumerated()), id: \.element.id) { i, section in
                        sectionCard(section).appearStagger(i + 1)
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var header: some View {
        AtharCard(padding: 16, elevation: .e2, tint: tint) {
            HStack(alignment: .top, spacing: 14) {
                IconChip(icon: topic.icon, tint: tint, size: .lg)
                VStack(alignment: .leading, spacing: 5) {
                    Text(topic.title)
                        .font(Theme.display(18, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(topic.summary)
                        .font(Theme.display(14))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func sectionCard(_ section: AhkamSection) -> some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: section.title, tint: tint)
            SettingsCard {
                ForEach(Array(section.items.enumerated()), id: \.element.id) { i, item in
                    NavigationLink {
                        AhkamItemView(section: section, index: i, tint: tint)
                    } label: {
                        itemRow(item, number: i + 1)
                    }
                    .buttonStyle(.plain)
                    if i < section.items.count - 1 { SettingsDivider() }
                }
            }
        }
    }

    /// صف حكم: رقمه في دائرة بلون الموضوع، عنوانه، والسطر الأول من نصّه.
    /// المقاسات مقاسات SettingsRow نفسها حتى يبدأ الفاصل حيث يبدأ النص.
    private func itemRow(_ item: AhkamItem, number: Int) -> some View {
        HStack(spacing: 13) {
            Text(number.counterText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(Circle().fill(tint.opacity(0.13)))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Theme.display(16, weight: .regular))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Text(ahkamFirstLine(item.body))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - حكم واحد: نصّه ودليله وفتواه

/// صفحة الحكم: العنوان والنصّ، ثم «الدليل» آيةً من المصحف المضمَّن أو حديثًا بعزوه،
/// ثم بطاقة فتوى للتوسّع، وأزرار النسخ والمشاركة، والتنقّل بين أحكام القسم.
struct AhkamItemView: View {
    let section: AhkamSection
    let tint: Color
    @State private var index: Int
    @State private var copied = false
    @EnvironmentObject private var store: AtharStore

    init(section: AhkamSection, index: Int, tint: Color) {
        self.section = section
        self.tint = tint
        _index = State(initialValue: index)
    }

    private var item: AhkamItem? {
        section.items.indices.contains(index) ? section.items[index] : nil
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        // مرساة أعلى الصفحة: التنقّل بين الأحكام يعيد التمرير إلى البداية.
                        Color.clear.frame(height: 0).id("top")
                        if let item {
                            content(item)
                        } else {
                            Text(loc("لا أحكام في هذا القسم بعد"))
                                .font(Theme.display(13))
                                .foregroundStyle(Theme.inkFaint)
                                .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 34)
                    .readableWidth(620)
                }
                .scrollIndicators(.hidden)
                .onChange(of: index) { _, _ in
                    withAnimation(Motion.smooth) { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    @ViewBuilder
    private func content(_ item: AhkamItem) -> some View {
        titleCard(item).appearStagger(0)
        if !item.evidence.isEmpty {
            evidenceBlock(item).appearStagger(1)
        }
        if let fatwa = item.fatwa, let url = URL(string: fatwa.url) {
            fatwaCard(fatwa, url: url).appearStagger(2)
        }
        actions(item).appearStagger(3)
        if section.items.count > 1 {
            pager.appearStagger(4)
        }
    }

    // MARK: العنوان والنصّ

    private func titleCard(_ item: AhkamItem) -> some View {
        AtharCard(padding: 18, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(Theme.display(21, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.body)
                    .font(Theme.display(16))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: الدليل

    private func evidenceBlock(_ item: AhkamItem) -> some View {
        VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("الدليل"), tint: tint)
            ForEach(item.evidence) { ev in
                if ev.isQuran {
                    quranCard(ev)
                } else if let text = ev.text, !text.isEmpty {
                    hadithCard(text: text, source: ev.source)
                }
            }
        }
    }

    /// آية أو آيات تُقرأ من المصحف المضمَّن بمرجعها — لا تُكتب في الملف.
    @ViewBuilder
    private func quranCard(_ ev: AhkamEvidence) -> some View {
        let refs = ev.ayahRefs.filter { Quran.text($0) != nil }
        if !refs.isEmpty {
            AtharCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    evidenceHeader(icon: "book.closed.fill", label: loc("من القرآن"))
                    ForEach(refs) { ref in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(Quran.text(ref) ?? "")
                                .font(Theme.dhikrFont(size: 19))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(10)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(loc("سورة %1$@: %2$@",
                                     Quran.surah(ref.surah)?.name ?? "",
                                     ref.ayah.counterText))
                                .font(Theme.display(12, weight: .semibold))
                                .foregroundStyle(tint)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// حديث بنصّه كما في مصدره وعزوه («رواه البخاري»، «متفق عليه»…).
    private func hadithCard(text: String, source: String?) -> some View {
        AtharCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                evidenceHeader(icon: "quote.opening", label: loc("من السنّة"))
                Text(text)
                    .font(Theme.dhikrFont(size: 18))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(9)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let source, !source.isEmpty {
                    Text(source)
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func evidenceHeader(icon: String, label: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(Theme.display(12, weight: .semibold))
        }
        .foregroundStyle(tint.opacity(0.85))
    }

    // MARK: الفتوى

    /// بطاقة للتوسّع: عنوان الفتوى ورابطها يفتح موقع الشيخ في المتصفح.
    private func fatwaCard(_ fatwa: FatwaLink, url: URL) -> some View {
        AtharCard(padding: 16, tint: tint) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconChip(icon: "text.book.closed.fill", tint: tint, size: .sm)
                    Text(loc("للتوسّع: فتوى %1$@", fatwa.scholar))
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(tint)
                }
                Text(fatwa.title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Text(loc("قراءة الفتوى")).font(Theme.display(13, weight: .semibold))
                        Image(systemName: "arrow.up.forward").font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(tint.opacity(0.13)))
                }
                .pressable()
                Text(loc("يفتح موقع الشيخ في المتصفح"))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: النسخ والمشاركة

    private func actions(_ item: AhkamItem) -> some View {
        let text = ahkamShareText(item)
        return HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = text
                Haptics.done(enabled: store.hapticsEnabled)
                withAnimation(Motion.snappy) { copied = true }
                // تعود الكلمة إلى «نسخ» بعد لحظة، فلا يبقى الزر معلَّقًا على حالة قديمة.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(Motion.snappy) { copied = false }
                }
            } label: {
                Label(copied ? loc("نُسخ") : loc("نسخ"),
                      systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(Theme.display(14, weight: .semibold))
                    .softButton(tint, radius: Theme.Radius.sm)
            }
            .pressable()

            ShareLink(item: text) {
                Label(loc("مشاركة"), systemImage: "square.and.arrow.up")
                    .font(Theme.display(14, weight: .semibold))
                    .softButton(tint, radius: Theme.Radius.sm)
            }
            .pressable()
        }
    }

    // MARK: التنقّل داخل القسم

    /// السابق والتالي داخل القسم نفسه، وبينهما موضع الحكم.
    private var pager: some View {
        let count = section.items.count
        return HStack(spacing: 10) {
            pagerButton(title: loc("السابق"), icon: "chevron.backward", iconFirst: true,
                        enabled: index > 0) { move(-1) }
            Spacer(minLength: 4)
            Text(loc("%1$@ من %2$@", (index + 1).counterText, count.counterText))
                .font(Theme.display(12, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
                .monospacedDigit()
            Spacer(minLength: 4)
            pagerButton(title: loc("التالي"), icon: "chevron.forward", iconFirst: false,
                        enabled: index < count - 1) { move(1) }
        }
        .padding(.top, 4)
    }

    private func pagerButton(title: String, icon: String, iconFirst: Bool,
                             enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if iconFirst { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(Theme.display(13, weight: .semibold))
                if !iconFirst { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
            }
            .foregroundStyle(enabled ? tint : Theme.inkFaint)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Capsule().fill(enabled ? tint.opacity(0.12) : Theme.surfaceAlt))
        }
        .pressable()
        .disabled(!enabled)
    }

    private func move(_ delta: Int) {
        let next = index + delta
        guard section.items.indices.contains(next) else { return }
        copied = false
        withAnimation(Motion.snappy) { index = next }
        Haptics.tap(enabled: store.hapticsEnabled)
    }
}
