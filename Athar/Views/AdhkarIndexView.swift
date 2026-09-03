import SwiftUI

struct AdhkarIndexView: View {
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false
    @EnvironmentObject private var store: AtharStore
    @State private var query = ""

    private var filtered: [DhikrCategory] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return AdhkarLibrary.categories }
        let needle = query.normalizedArabic
        return AdhkarLibrary.categories.compactMap { category in
            if category.title.normalizedArabic.contains(needle) { return category }
            // البحث ترشيح للفئات لا بتر لأذكارها: لو دفعنا نسخة تحمل المطابق فقط
            // لختمت الجلسة الفئة كاملة بمعرّفها بعد تكرارات معدودة.
            guard category.items.contains(where: { $0.text.normalizedArabic.contains(needle) }) else { return nil }
            return category
        }
    }

    var body: some View {
        MaybeStack(embedded: embedded) {
            ZStack {
                AtharBackground()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { i, category in
                            NavigationLink {
                                DhikrSessionView(category: category)
                            } label: {
                                CategoryRow(category: category,
                                            completed: store.completedToday.contains(category.id))
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
