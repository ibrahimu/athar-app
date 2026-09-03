import SwiftUI

/// اختيار ما يُضاف إلى الحفظ: سورة كاملة أو مدى آيات منها.
struct HifzPicker: View {
    let onAdd: ([AyahRef]) -> Void

    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    /// لا سورة مختارة عند الفتح: كان الافتراضي الخفيّ (الناس ١–٦) يجعل «أضِف» فعّالًا
    /// وصفّه خارج الشاشة، فتُضاف آيات لم يخترها أحد. الاختيار يبدأ مرئيًّا أو لا يبدأ.
    @State private var surahId: Int? = nil
    @State private var from = 1
    @State private var to = 6
    @State private var query = ""

    /// لون القسم البحري — يوحّد هوية الحفظ بين الجلسة وهذه الورقة.
    private var sea: Color { Theme.accent(for: "hifz") }

    private var surah: Surah? { surahId.flatMap { Quran.surah($0) } }
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
                AtharBackground(tint: sea)
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 16) {
                            SettingsGroupTitle(text: loc("السورة"), tint: sea)
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
                                                // الحلقة غير المختارة بلون الفاصل كانت تكاد تختفي على البطاقة؛ رمادي
                                                // أوضح يجعل الصفوف تُقرأ مجموعةً واحدة يُختار منها.
                                                .foregroundStyle(surahId == s.id ? sea : Theme.inkFaint.opacity(0.55))
                                            // الرقم في عمود ثابت بأرقام متساوية العرض، فلا يقفز اسم السورة سبع
                                            // نقاط حين يكسب الرقم خانة (٩ ← ١٠). trailing في العربية جهة النقطة.
                                            HStack(spacing: 4) {
                                                Text("\(s.id.counterText).")
                                                    .monospacedDigit()
                                                    .frame(width: 32, alignment: .trailing)
                                                Text("سورة \(s.name)")
                                            }
                                            .font(Theme.display(15, weight: surahId == s.id ? .semibold : .regular))
                                            .foregroundStyle(Theme.ink)
                                            Spacer()
                                            Text(s.ayahCount.ayahCountText)
                                                .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 11)
                                        .frame(minHeight: 44)   // هدف لمس كافٍ للصفوف القصيرة
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .id(s.id)   // هدف ScrollViewReader
                                    .accessibilityAddTraits(surahId == s.id ? .isSelected : [])
                                    if i < filtered.prefix(query.isEmpty ? 114 : 12).count - 1 { SettingsDivider() }
                                }
                            }

                            if let s = surah {
                                SettingsGroupTitle(text: loc("المدى"), tint: sea)
                                SettingsCard {
                                    stepperRow(loc("من الآية"), value: $from, range: 1...s.ayahCount)
                                    SettingsDivider()
                                    stepperRow(loc("إلى الآية"), value: $to, range: 1...s.ayahCount)
                                }

                                Text(count > 0 ? addLine(count) : loc("المدى غير صحيح"))
                                    .font(Theme.display(12))
                                    .foregroundStyle(count > 0 ? Theme.inkFaint : Theme.danger)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 30)
                        .readableWidth(560)
                    }
                    .scrollIndicators(.hidden)
                    // العودة باختيار سابق أو مسح البحث يعيد بناء القائمة كاملة (١١٤ صفًّا)،
                    // فنُحضر الصفّ المختار إلى النظر بدل أن يبقى الاختيار خارج الشاشة.
                    .onAppear { scrollToSelection(proxy) }
                    .onChange(of: query) { _, q in if q.isEmpty { scrollToSelection(proxy) } }
                }
            }
            .searchable(text: $query, prompt: loc("ابحث عن سورة"))
            .navigationTitle(loc("ما تريد حفظه"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("أضِف")) {
                        guard count > 0, let surahId else { return }
                        let refs = (from...to).map { AyahRef(surah: surahId, ayah: $0) }
                        onAdd(refs)
                        dismiss()
                    }
                    .disabled(surahId == nil || count <= 0)
                }
            }
        }
    }

    /// المدى المختار قد يكون آية أو آيتين، و`Int.ayahCountText` مبنيّ على عدد آيات
    /// السورة (٣ فأكثر)، فنُفرد ونُثنّي هنا مع مطابقة الفعل ونترك الجمع له.
    private func addLine(_ n: Int) -> String {
        switch n {
        case 1:  return "آية ستُضاف إلى الحفظ"
        case 2:  return "آيتان ستُضافان إلى الحفظ"
        default: return "\(n.ayahCountText) ستُضاف إلى الحفظ"
        }
    }

    private func scrollToSelection(_ proxy: ScrollViewProxy) {
        guard let surahId else { return }
        // بعد أن تُبنى القائمة الجديدة، لا في لحظة تغيّر النصّ نفسها.
        DispatchQueue.main.async { proxy.scrollTo(surahId, anchor: .center) }
    }

    private func stepperRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title).font(Theme.display(15)).foregroundStyle(Theme.ink)
            Spacer()
            Stepper(value: value, in: range) {
                Text(value.wrappedValue.counterText)
                    .font(Theme.display(16, weight: .semibold))
                    .foregroundStyle(sea)
                    .monospacedDigit()
            }
            .labelsHidden()
            Text(value.wrappedValue.counterText)
                .font(Theme.display(16, weight: .semibold))
                .foregroundStyle(sea)
                .monospacedDigit()
                .frame(minWidth: 34)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}
