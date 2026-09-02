import SwiftUI

struct AdhkarIndexView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var query = ""

    private var filtered: [DhikrCategory] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return AdhkarLibrary.categories }
        let needle = query.normalizedArabic
        return AdhkarLibrary.categories.compactMap { category in
            if category.title.normalizedArabic.contains(needle) { return category }
            let hits = category.items.filter { $0.text.normalizedArabic.contains(needle) }
            guard !hits.isEmpty else { return nil }
            return DhikrCategory(id: category.id, title: category.title, subtitle: category.subtitle,
                                 icon: category.icon, accent: category.accent, items: hits)
        }
    }

    var body: some View {
        NavigationStack {
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
                            ContentUnavailableView("لا توجد نتائج", systemImage: "magnifyingglass",
                                                   description: Text("جرّب كلمة أخرى"))
                                .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                    .readableWidth()
                }
            }
            .navigationTitle("الأذكار")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "ابحث في الأذكار")
        }
    }
}

struct CategoryRow: View {
    let category: DhikrCategory
    var completed: Bool

    var body: some View {
        let color = Theme.accent(for: category.accent)
        return AtharCard(padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: category.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(color.opacity(0.13)))

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
    var normalizedArabic: String {
        let stripped = unicodeScalars.filter { scalar in
            !(0x0610...0x061A ~= scalar.value) &&
            !(0x064B...0x065F ~= scalar.value) &&
            scalar.value != 0x0640 && scalar.value != 0x0670
        }
        return String(String.UnicodeScalarView(stripped))
            .replacingOccurrences(of: "أ", with: "ا")
            .replacingOccurrences(of: "إ", with: "ا")
            .replacingOccurrences(of: "آ", with: "ا")
            .replacingOccurrences(of: "ى", with: "ي")
            .replacingOccurrences(of: "ة", with: "ه")
    }
}
