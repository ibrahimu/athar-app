import SwiftUI

/// اختيار ما يُضاف إلى الحفظ: سورة كاملة أو مدى آيات منها.
struct HifzPicker: View {
    let onAdd: ([AyahRef]) -> Void

    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @State private var surahId = 114
    @State private var from = 1
    @State private var to = 6
    @State private var query = ""

    private var surah: Surah? { Quran.surah(surahId) }
    private var count: Int { max(0, to - from + 1) }

    private var filtered: [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return Quran.surahs }
        let n = q.strippedForSearch
        return Quran.surahs.filter { $0.name.strippedForSearch.contains(n) || String($0.id) == q }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        SettingsGroupTitle(text: "السورة")
                        SettingsCard {
                            ForEach(Array(filtered.prefix(query.isEmpty ? 114 : 12).enumerated()), id: \.element.id) { i, s in
                                Button {
                                    surahId = s.id
                                    from = 1
                                    to = min(s.ayahCount, 10)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: surahId == s.id ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 17))
                                            .foregroundStyle(surahId == s.id ? Theme.accent : Theme.hairline)
                                        Text("\(s.id.counterText). سورة \(s.name)")
                                            .font(Theme.display(15, weight: surahId == s.id ? .semibold : .regular))
                                            .foregroundStyle(Theme.ink)
                                        Spacer()
                                        Text("\(s.ayahCount.counterText) آية")
                                            .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 11)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if i < filtered.prefix(query.isEmpty ? 114 : 12).count - 1 { SettingsDivider() }
                            }
                        }

                        if let s = surah {
                            SettingsGroupTitle(text: "المدى")
                            SettingsCard {
                                stepperRow("من الآية", value: $from, range: 1...s.ayahCount)
                                SettingsDivider()
                                stepperRow("إلى الآية", value: $to, range: 1...s.ayahCount)
                            }

                            Text(count > 0 ? "\(count.counterText) آية ستُضاف إلى الحفظ" : "المدى غير صحيح")
                                .font(Theme.display(12))
                                .foregroundStyle(count > 0 ? Theme.inkFaint : Color.red.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 6)
                    .padding(.bottom, 30)
                    .readableWidth(560)
                }
                .scrollIndicators(.hidden)
            }
            .searchable(text: $query, prompt: "ابحث عن سورة")
            .navigationTitle("ما تريد حفظه")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("أضِف") {
                        guard count > 0 else { return }
                        let refs = (from...to).map { AyahRef(surah: surahId, ayah: $0) }
                        onAdd(refs)
                        dismiss()
                    }
                    .disabled(count <= 0)
                }
            }
        }
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title).font(Theme.display(15)).foregroundStyle(Theme.ink)
            Spacer()
            Stepper(value: value, in: range) {
                Text(value.wrappedValue.counterText)
                    .font(Theme.display(16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }
            .labelsHidden()
            Text(value.wrappedValue.counterText)
                .font(Theme.display(16, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .monospacedDigit()
                .frame(minWidth: 34)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
