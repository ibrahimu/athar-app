import SwiftUI

/// أسماء الله الحسنى: اسم اليوم في الصدر، وبحث بالاسم، وشبكة التسعة والتسعين،
/// ولكل اسم شرحه وشاهده. الشرح من كلام السعدي حين وُجد، والشاهد نصٌّ شرعي
/// يُعرض بخطّ الذكر وبالحبر لا بلون — كسائر النصّ الشرعي في التطبيق.
struct NamesView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false
    @State private var query = ""

    /// لون القسم كما في شريط التبويب («dusk»)؛ الذهبي للزخرفة وحدها.
    private var tint: Color { Theme.accent(for: "dusk") }
    private var names: [DivineName] { NamesLibrary.all }

    private var filtered: [DivineName] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return names }
        let needle = q.namesSearchKey
        guard !needle.isEmpty else { return names }
        return names.filter { $0.name.namesSearchKey.contains(needle) || String($0.id) == q }
    }

    /// ثلاثة أعمدة ثابتة: الاسم قصير، والبلاطة الصغيرة تُري الشبكة كلها في شاشتين.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 14) {
                    if names.isEmpty {
                        placeholder
                    } else {
                        if let today = NamesLibrary.daily(for: Date()) {
                            dailyCard(today).appearStagger(0)
                        }
                        searchField.appearStagger(1)
                        grid
                        if filtered.isEmpty { noResults }
                        footer
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 6)
                .padding(.bottom, 30)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(loc("الأسماء الحسنى"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }

    // MARK: اسم اليوم

    private func dailyCard(_ n: DivineName) -> some View {
        NavigationLink {
            NameDetailView(name: n)
        } label: {
            AtharCard(padding: 20, elevation: .e2, tint: tint) {
                VStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 12, weight: .semibold))
                        Text(loc("اسم اليوم"))
                            .font(Theme.display(13, weight: .semibold))
                        Spacer()
                        Text(loc("الشرح"))
                            .font(Theme.display(13, weight: .semibold))
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(tint)

                    // خيط ذهبي فوق الاسم — كحاشية المصحف المذهّبة، والاسم نفسه بالحبر
                    Capsule().fill(Theme.goldGradient)
                        .frame(width: 46, height: 3)
                        .opacity(0.8)

                    Text(n.name)
                        .font(Theme.dhikrFont(size: 28))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)

                    Text(n.meaning)
                        .font(Theme.display(14, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        .lineSpacing(4)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .pressable()
    }

    // MARK: البحث

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
            TextField(loc("ابحث عن اسم"), text: $query)
                .font(Theme.display(15, weight: .regular))
                .foregroundStyle(Theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                    Haptics.tap(enabled: store.hapticsEnabled)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loc("مسح البحث"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(CardSurface(radius: Theme.Radius.md))
    }

    // MARK: الشبكة

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(filtered) { n in
                NavigationLink {
                    NameDetailView(name: n)
                } label: {
                    tile(n)
                }
                .pressable()
            }
        }
    }

    private func tile(_ n: DivineName) -> some View {
        VStack(spacing: 8) {
            Text(n.id.counterText)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(tint.opacity(0.13)))
            Text(n.name)
                .font(Theme.dhikrFont(size: 18))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(CardSurface(radius: Theme.Radius.md))
        .accessibilityElement(children: .combine)
    }

    private var noResults: some View {
        ContentUnavailableView(loc("لا توجد نتائج"), systemImage: "magnifyingglass",
                               description: Text(loc("جرّب اسمًا آخر.")))
            .padding(.top, 20)
    }

    // MARK: الذيل والحالة الفارغة

    @ViewBuilder
    private var footer: some View {
        let lines = [NamesLibrary.sourceNote, NamesLibrary.note].filter { !$0.isEmpty }
        if !lines.isEmpty {
            VStack(spacing: 6) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(Theme.display(12, weight: .regular))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
        }
    }

    /// ملفّ الأسماء قد يكون فارغًا أثناء الإعداد — لا شاشة خطأ، بل هدوء.
    private var placeholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.system(size: 30))
                .foregroundStyle(tint.opacity(0.6))
            Text(loc("الأسماء الحسنى"))
                .font(Theme.display(18, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text(loc("المحتوى قيد الإعداد"))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - شرح اسم

/// شرح اسم واحد: الاسم بخيط ذهبي، ومعناه، وشاهده، ومصدر الشرح، وتنقّل بين الأسماء.
struct NameDetailView: View {
    let name: DivineName
    @EnvironmentObject private var store: AtharStore
    @State private var index: Int
    @State private var copied = false

    init(name: DivineName) {
        self.name = name
        _index = State(initialValue: NamesLibrary.all.firstIndex { $0.id == name.id } ?? 0)
    }

    private var tint: Color { Theme.accent(for: "dusk") }
    private var names: [DivineName] { NamesLibrary.all }
    /// الاسم المعروض: من الفهرس إن صحّ، وإلا الاسم الذي فُتحت به الشاشة.
    private var current: DivineName { names.indices.contains(index) ? names[index] : name }
    private var hasPrev: Bool { index > 0 && index < names.count }
    private var hasNext: Bool { index + 1 < names.count }

    private var sourceLine: String {
        current.source == "السعدي"
            ? loc("من كلام الشيخ السعدي — تفسير أسماء الله الحسنى")
            : loc("شرح موجز من إعداد التطبيق")
    }

    private var shareText: String {
        var s = current.name + "\n\n" + current.meaning
        if !current.evidence.isEmpty {
            s += "\n\n" + current.evidence
            if !current.evidenceSource.isEmpty { s += "\n" + current.evidenceSource }
        }
        return s + "\n\n" + sourceLine + "\n\nمن تطبيق أثر"
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 14) {
                    hero.appearStagger(0)
                    meaningCard.appearStagger(1)
                    if !current.evidence.isEmpty { evidenceCard.appearStagger(2) }
                    actions.appearStagger(3)
                    pager.appearStagger(4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 6)
                .padding(.bottom, 34)
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        // «نُسخ» تعود إلى «نسخ» بعد لحظة، فلا تبقى الشارة معلّقة.
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.6))
            copied = false
        }
    }

    // MARK: الاسم

    private var hero: some View {
        AtharCard(padding: 22, elevation: .e2) {
            VStack(spacing: 16) {
                Text(loc("%1$@ من %2$@", current.id.counterText, names.count.counterText))
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(tint.opacity(0.13)))

                goldThread
                Text(current.name)
                    .font(Theme.dhikrFont(size: 44))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 4)
                    .contentTransition(.opacity)
                goldThread
            }
            .frame(maxWidth: .infinity)
        }
        .animation(Motion.smooth, value: index)
    }

    /// خيط شعري يتوسّطه خيط ذهبي متدرّج — زخرفة حول الاسم لا عليه.
    private var goldThread: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.hairline.opacity(0.7)).frame(height: 0.7)
            Capsule().fill(Theme.goldGradient)
                .frame(width: 46, height: 3)
                .opacity(0.85)
            Rectangle().fill(Theme.hairline.opacity(0.7)).frame(height: 0.7)
        }
    }

    // MARK: المعنى

    private var meaningCard: some View {
        AtharCard {
            VStack(alignment: .leading, spacing: 10) {
                SettingsGroupTitle(text: loc("المعنى"), tint: tint)
                Text(current.meaning)
                    .font(Theme.dhikrFont(size: 17, scale: store.fontScale))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                    Text(sourceLine)
                        .font(Theme.display(12, weight: .regular))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.inkFaint)
                .padding(.top, 2)
            }
        }
    }

    // MARK: الشاهد

    private var evidenceCard: some View {
        AtharCard {
            VStack(alignment: .leading, spacing: 10) {
                SettingsGroupTitle(text: loc("الشاهد"), tint: Theme.gold)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: evidenceIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.gold)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(current.evidence)
                            .font(Theme.dhikrFont(size: 17, scale: store.fontScale))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(9)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !current.evidenceSource.isEmpty {
                            Text(current.evidenceSource)
                                .font(Theme.display(12, weight: .regular))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.gold.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.gold.opacity(0.22), lineWidth: 0.5))
                )
            }
        }
    }

    /// أيقونة الشاهد بحسب عزوه: «رواه…» حديث، وما سواه آية.
    private var evidenceIcon: String {
        let s = current.evidenceSource
        let isHadith = s.contains("رواه") || s.contains("أخرجه") || s.contains("متفق")
        return isHadith ? "quote.opening" : "book.closed.fill"
    }

    // MARK: النسخ والمشاركة

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                UIPasteboard.general.string = shareText
                copied = true
                Haptics.done(enabled: store.hapticsEnabled)
            } label: {
                Label(copied ? loc("نُسخ") : loc("نسخ"), systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(Theme.display(14, weight: .semibold))
                    .softButton(tint)
            }
            .pressable()
            .accessibilityLabel(loc("نسخ الاسم وشرحه"))

            ShareLink(item: shareText) {
                Label(loc("مشاركة"), systemImage: "square.and.arrow.up")
                    .font(Theme.display(14, weight: .semibold))
                    .softButton(tint)
            }
            .pressable()
        }
        .animation(Motion.snappy, value: copied)
    }

    // MARK: التنقّل بين الأسماء

    /// السابق على اليمين والتالي على اليسار — اتجاه القراءة العربية.
    private var pager: some View {
        HStack(spacing: 10) {
            Button { go(-1) } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 12, weight: .semibold))
                    if hasPrev {
                        Text(names[index - 1].name)
                            .font(Theme.dhikrFont(size: 15))
                            .lineLimit(1)
                    } else {
                        Text(loc("السابق"))
                            .font(Theme.display(14, weight: .semibold))
                    }
                    Spacer(minLength: 0)
                }
                .foregroundStyle(hasPrev ? Theme.ink : Theme.inkFaint)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(CardSurface(radius: Theme.Radius.md))
            }
            .pressable()
            .disabled(!hasPrev)
            .opacity(hasPrev ? 1 : 0.5)
            .accessibilityLabel(loc("الاسم السابق"))

            Button { go(1) } label: {
                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    if hasNext {
                        Text(names[index + 1].name)
                            .font(Theme.dhikrFont(size: 15))
                            .lineLimit(1)
                    } else {
                        Text(loc("التالي"))
                            .font(Theme.display(14, weight: .semibold))
                    }
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(hasNext ? Theme.ink : Theme.inkFaint)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(CardSurface(radius: Theme.Radius.md))
            }
            .pressable()
            .disabled(!hasNext)
            .opacity(hasNext ? 1 : 0.5)
            .accessibilityLabel(loc("الاسم التالي"))
        }
    }

    private func go(_ step: Int) {
        let target = index + step
        guard names.indices.contains(target) else { return }
        withAnimation(Motion.smooth) { index = target }
        copied = false
        Haptics.tap(enabled: store.hapticsEnabled)
    }
}

// MARK: - مفتاح البحث

private extension String {
    /// مفتاح مطابقة الاسم: بلا تشكيل ولا «ال» التعريف ولا فراغات،
    /// فيجد «رحمن» و«الرحمن» و«الرَّحْمَن» معًا.
    var namesSearchKey: String {
        var s = strippedForSearch.replacingOccurrences(of: " ", with: "")
        if s.hasPrefix("ال") { s.removeFirst(2) }
        return s
    }
}
