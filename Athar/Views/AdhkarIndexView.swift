import SwiftUI

struct AdhkarIndexView: View {
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false
    @EnvironmentObject private var store: AtharStore
    @State private var query = ""

    private var filtered: [DhikrCategory] { AdhkarSearch.categories(matching: query) }

    /// الذكر المطابق في كل باب — من بحث عن «الحمد لله» كان يرى قائمة الأبواب كما هي
    /// بلا خبرٍ عمّا طابق ولا عن موضعه، فيفتح البابَ فيجد أوّله لا ما بحث عنه.
    private func firstMatch(in category: DhikrCategory) -> Dhikr? {
        AdhkarSearch.firstMatch(in: category, query: query)
    }

    var body: some View {
        MaybeStack(embedded: embedded) {
            ZStack {
                AtharBackground()
                ScrollView {
                    // الشبكة الكسولة تخبّئ صفوفها فلا تُعاد صبغتها مع الطابع وإن مُرِّر
                    // اللون قيمةً — والمفتاح يعيد بناءها، كما في «اليوم» و«الأقسام».
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, category in
                            let match = firstMatch(in: category)
                            NavigationLink {
                                DhikrSessionView(category: category, startAt: match?.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    CategoryRow(category: category,
                                                completed: store.completedToday.contains(category.id))
                                    // سطرٌ من الذكر المطابق: يُرى ما طابق، ويُفتح الباب عليه.
                                    if let match {
                                        Text(match.text)
                                            .font(Theme.dhikrFont(size: 14, scale: store.fontScale))
                                            .foregroundStyle(Theme.inkSoft)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 16)
                                            .padding(.bottom, 12)
                                    }
                                }
                            }
                            .pressable()
                            .appearStagger(i)
                        }

                        if filtered.isEmpty {
                            ContentUnavailableView(loc("لا توجد نتائج"), systemImage: "magnifyingglass",
                                                   description: Text(loc("جرّب كلمة أخرى")))
                                .padding(.top, 60)
                        }
                    }
                    .id("\(store.appTheme.rawValue)-\(store.unifyIcons)")
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 32)
                    .readableWidth()
                }
            }
            .navigationTitle(loc("الأذكار"))
            // كل شاشات التطبيق بعنوان مضمَّن، والمصحف يجمعه مع البحث بالشكل نفسه.
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: loc("ابحث في الأذكار"))
        }
    }
}

struct CategoryRow: View {
    let category: DhikrCategory
    var completed: Bool
    /// لون القسم يُقرأ عند الإنشاء في جسد الأب لا داخل الصف: الصف قيمةٌ متساوية قبل تبديل
    /// الطابع وبعده، فلو قرأ اللون ساكنًا في جسده لبقيت أيقونته خضراء بعد اختيار الوردي.
    let color: Color

    init(category: DhikrCategory, completed: Bool, color: Color? = nil) {
        self.category = category
        self.completed = completed
        self.color = color ?? Theme.accent(for: category.accent)
    }

    var body: some View {
        AtharCard(padding: 16) {
            HStack(spacing: 14) {
                IconChip(icon: category.icon, tint: color, size: .lg)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(category.title)
                            .font(Theme.display(17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if completed {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(color)
                        }
                        Spacer()
                    }
                    Text(category.subtitle)
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }
}

// MARK: - ترشيح الأبواب بالبحث

/// بحث الأذكار على ثلاث درجات، تُصعَد واحدةً واحدة ولا تُخلط.
///
/// خارج الواجهة كي يُختبر بالبيانات نفسها: علّتُه لم تكن في الرسم بل في الترتيب.
enum AdhkarSearch {

    /// الدرجات الدقيقة من `ArabicSearch` وحدها: المفتاح، ثمّ النحيل، ثمّ طيّ التكرار،
    /// ثمّ لام الجرّ — بلا الدرجة المتساهلة التي تُسقط الألفات.
    ///
    /// و`matches` تنزل إلى المتساهل من نفسها، فقلّ أن تخيب في متن: «الخلاء» متساهلُها
    /// «لخل» فتقع في «كَلِمَةِ الْإِخْلَاصِ» و«الْخَلِيفَةُ»، فتمتلئ درجةُ المتون بثلاثة
    /// أبوابٍ لا صلة لها، ولا يُبلغ المصدرُ والفضلُ بعدها — وهما وحدهما يقولان أين تُقال
    /// «غُفْرَانَكَ». فالتساهل يُؤخَّر إلى آخر الدرجات، ولا يُخنَق به ما قبله.
    static func precise(_ text: String, _ query: String) -> Bool {
        let n = ArabicSearch.key(query)
        guard !n.isEmpty else { return true }
        let textKey = ArabicSearch.key(text)
        if textKey.contains(n) { return true }
        let slim = ArabicSearch.slim(query)
        let textSlim = ArabicSearch.slim(text)
        if slim.count >= 2, textSlim.contains(slim) { return true }
        let collapsed = ArabicSearch.collapsed(query)
        if collapsed.count >= 2, ArabicSearch.collapsed(text).contains(collapsed) { return true }
        if let lam = ArabicSearch.lamPrefixed(n), textKey.contains(lam) { return true }
        if let lam = ArabicSearch.lamPrefixed(slim), textSlim.contains(lam) { return true }
        return false
    }

    /// آخرُ ما يُلجأ إليه: `ArabicSearch.matches` بدرجاتها كلّها، والمتساهلةُ فيها.
    private static func tolerant(_ text: String, _ query: String) -> Bool {
        ArabicSearch.matches(text, query)
    }

    /// الأبواب التي يقع فيها الاستعلام — أو الأبواب كلّها إن كان فارغًا.
    ///
    /// البحث ترشيح للأبواب لا بتر لأذكارها: لو دفعنا نسخة تحمل المطابق وحده
    /// لختمت الجلسة البابَ كاملًا بمعرّفه بعد تكرارات معدودة.
    static func categories(matching query: String) -> [DhikrCategory] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty,
              !ArabicSearch.key(query).isEmpty else { return AdhkarLibrary.categories }

        let byText = AdhkarLibrary.categories.filter { category in
            precise(category.title, query)
            || precise(category.subtitle, query)
            || category.items.contains { precise($0.text, query) }
        }
        guard byText.isEmpty else { return byText }

        // خابت المتون: يُجرَّب المصدرُ والفضل. وموضوعُ كثيرٍ من الأذكار لا يقع إلا
        // فيهما — «غُفْرَانَكَ» كلمةٌ واحدة، ومصدرها وحده يقول إنّها عند الخروج من
        // الخلاء. ولا يُضمّان من أوّل الأمر لأنّ «رواه مسلم» تُطابق الأبواب كلّها.
        let byMeta = AdhkarLibrary.categories.filter { category in
            category.items.contains { precise($0.reference, query) || precise($0.virtue, query) }
        }
        guard byMeta.isEmpty else { return byMeta }

        // وخابت الدقّةُ كلُّها: هنا وحده يُحتمل ضجيج التساهل، لأنّ البديل لا شيء.
        return AdhkarLibrary.categories.filter { category in
            tolerant(category.title, query) || tolerant(category.subtitle, query)
            || category.items.contains {
                tolerant($0.text, query) || tolerant($0.reference, query) || tolerant($0.virtue, query)
            }
        }
    }

    /// الذكر الذي طابق في هذا الباب — بترتيب الدرجات نفسه، كي يكون المعروض تحت
    /// عنوان الباب هو الذي رشّحه، ويُفتح البابُ عليه.
    static func firstMatch(in category: DhikrCategory, query: String) -> Dhikr? {
        guard !ArabicSearch.key(query).isEmpty, !precise(category.title, query) else { return nil }
        return category.items.first { precise($0.text, query) }
            ?? category.items.first { precise($0.reference, query) || precise($0.virtue, query) }
            ?? category.items.first { tolerant($0.text, query) }
            ?? category.items.first { tolerant($0.reference, query) || tolerant($0.virtue, query) }
    }
}

extension String {
    /// Strips tashkeel and normalizes alef/ya so search matches how people type.
    /// ونُسقِط كذلك علامات الوقف ورقم الآية (۝ ۚ ۖ …) وأرقامها الهندية، لأنّ النصّ
    /// المحفوظ يحملها بين الكلمتين فتُفشل بحث العبارة، ثم نوحّد الفراغات لأنّ
    /// إسقاطها يخلّف فراغًا مزدوجًا ولأنّ النصّ فيه أسطر جديدة.
    var normalizedArabic: String {
        let stripped = unicodeScalars.filter { scalar in
            !(0x0610...0x061A ~= scalar.value) &&
            !(0x064B...0x065F ~= scalar.value) &&
            !(0x06D6...0x06ED ~= scalar.value) &&
            !(0x0660...0x0669 ~= scalar.value) &&
            scalar.value != 0x0640 && scalar.value != 0x0670
        }
        return String(String.UnicodeScalarView(stripped))
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .replacingOccurrences(of: "ة", with: "ه")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
