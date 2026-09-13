import SwiftUI

// MARK: - المكان
//
// Apple TV بلا خدمات موقع — بل إن وضع «location-services» في القدرات المطلوبة
// يمنع التثبيت أصلًا. فالمدينةُ تُسأل صراحةً، ومدينةٌ خاطئة في المواقيت خطأٌ في
// الدين لا في الواجهة.
//
// ثلاثةُ مستويات: بلدٌ أو إقليم ← منطقة ← مدينة. وأعمقُ طريقٍ إلى أيّ مدينةٍ من
// إحدى وسبعين ثلاثُ ضغطاتٍ بعد الوصول إلى صفّها، وفوقها البحثُ لمن يعرف اسمَه.
struct CityPickerView: View {
    @ObservedObject private var prefs = TVPrefs.shared
    @FocusState private var focus: Row?
    @State private var section: TVPlaceSection?
    @State private var group: TVPlaceGroup?
    @State private var query = ""

    /// nil في أوّل تشغيل: لا رجوعَ من أوّل الطريق، ولا مدينةَ يُرجَع إليها.
    var onClose: (() -> Void)?

    private enum Row: Hashable {
        case back, search
        case section(String), group(String), city(String)
    }

    var body: some View {
        TVScreen(title: title, subtitle: subtitle,
                 onBack: canGoBack ? back : nil,
                 backFocused: focus == .back) {
            VStack(alignment: .leading, spacing: 8) {
                if section == nil { searchRow }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        rows
                    }
                    .padding(.vertical, 18)
                }
                .focusSection()
                .scrollClipDisabled()
            }
            .frame(maxWidth: 980, alignment: .leading)
        }
        .onAppear(perform: land)
        // `nil` في أوّل الطريق مقصودةٌ لا سهو: `onExitCommand` تبتلع الضغطة
        // بمجرّد وجودها ولو لم تفعل شيئًا، فتُحبَس الشاشةُ ولا يخرج التطبيق إلى
        // شاشة Apple TV الرئيسة من أوّل شاشةٍ فيه — وذلك شرطُ المراجعة لا ذوقًا.
        // فحين لا شيءَ يُرجَع إليه يُترك الزرُّ للنظام.
        // PROBE: no exit handler at all
    }

    /// الشاشةُ تُنادى في حالين: أوّلَ تشغيلٍ ولا مدينة، ومن المجلس ولصاحبها
    /// مدينة. وفي الثانية تُفتح على منطقتها وعلى مدينته هو، لا على رأس القائمة.
    private func land() {
        if let city = prefs.city, let place = TVCities.place(of: city) {
            section = place.section
            group = place.group
            focus = .city(city.id)
        } else {
            focus = firstFocus
        }
    }

    // MARK: العنوان — يقول أين أنت من الطريق

    private var title: String {
        if let group { return group.title }
        if let section { return section.title }
        return loc("أين هذه الشاشة؟")
    }

    private var subtitle: String? {
        if group != nil || section != nil { return nil }
        return loc("لكلِّ مدينةٍ حسابُها، فاختر أقربَها إليك.")
    }

    /// بحثٌ مكتوبٌ شيءٌ يُرجَع منه كالمنطقة: من كتب حرفين ولم يجد أراد أن يمسح
    /// ما كتب ويعود إلى القائمة، لا أن يخرج من التطبيق.
    private var canGoBack: Bool { section != nil || !query.isEmpty || onClose != nil }

    private func back() {
        withAnimation(Motion.gentle) {
            if group != nil { group = nil }
            else if section != nil { section = nil }
            else if !query.isEmpty { query = "" }
            else { onClose?() }
        }
        focus = firstFocus
    }

    private var firstFocus: Row? {
        if let group { return .city(group.cities.first ?? "") }
        if let section { return .group(section.groups.first?.id ?? "") }
        if !query.isEmpty { return .search }
        return .section(TVCities.sections.first?.id ?? "")
    }

    // MARK: الصفوف

    @ViewBuilder private var rows: some View {
        if !query.isEmpty {
            let results = TVCities.search(query)
            if results.isEmpty {
                Text(loc("لا مدينة بهذا الاسم."))
                    .font(Theme.display(TVType.body, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 34)
                    .frame(height: 92)
            } else {
                ForEach(results) { cityRow($0) }
            }
        } else if let group {
            ForEach(group.resolved) { cityRow($0) }
        } else if let section {
            ForEach(section.groups) { g in
                row(g.title, detail: countText(g.resolved.count), key: .group(g.id),
                    symbol: holds(g.resolved) ? "checkmark.circle.fill" : nil) {
                    // مجموعةٌ بمدينةٍ واحدة لا تستحقّ مستوًى ثالثًا يُفتح على صفٍّ واحد.
                    if g.resolved.count == 1, let only = g.resolved.first { pick(only) }
                    else { withAnimation(Motion.gentle) { group = g }; focus = .city(g.cities.first ?? "") }
                }
            }
        } else {
            ForEach(TVCities.sections) { s in
                row(s.title, detail: countText(cityCount(s)), key: .section(s.id),
                    symbol: holds(s.groups.flatMap(\.resolved)) ? "checkmark.circle.fill" : nil) {
                    withAnimation(Motion.gentle) { section = s }
                    focus = .group(s.groups.first?.id ?? "")
                }
            }
        }
    }

    private func cityRow(_ city: City) -> some View {
        row(city.name, detail: section == nil ? city.country : nil, key: .city(city.id),
            symbol: prefs.city?.id == city.id ? "checkmark.circle.fill" : "mappin") { pick(city) }
    }

    /// لا رمزَ لبابٍ جغرافيّ. جرّبتُ نجمةً للمملكة وقطرةً للخليج ومعبدًا للشرق
    /// الأوسط، فكان جِناسًا في الأولى وخطأً في الأخيرة — ورمزٌ لا يدلّ أسوأُ من
    /// لا رمز: العينُ تقف عنده تسأل عن معناه ثمّ تمضي بلا شيء.
    ///
    /// وما يحتاجه الواقفُ هنا ليس رمزًا بل جوابَين: **أين مدينتي؟** فتُعلَّم
    /// الطريقُ إليها بعلامةٍ في كل مستوًى يحملها، **وكم تحت هذا الباب؟** فيُعرف
    /// أيَستحقّ الدخول. وهذا ما حلّ محلّ الزخرفة.
    private func holds(_ cities: [City]) -> Bool {
        guard let chosen = prefs.city else { return false }
        return cities.contains { $0.id == chosen.id }
    }

    private func cityCount(_ s: TVPlaceSection) -> Int {
        s.groups.reduce(0) { $0 + $1.resolved.count }
    }

    private func pick(_ city: City) {
        prefs.city = city
        onClose?()
    }

    /// صفٌّ واحد لكل المستويات، فيتّفق شكلُ الطريق من أوّله إلى آخره.
    /// والنصُّ يبدأ من اليمين داخل صندوقٍ يملأ العرض — والحشوةُ الأفقية داخل
    /// الصندوق لا خارجه، وإلّا قُصّ أوّلُ الحرف عند حافّة التركيز كما كان يُقصّ.
    private func row(_ text: String, detail: String?, key: Row,
                     symbol: String? = nil,
                     action: @escaping () -> Void) -> some View {
        let on = focus == key
        return Button(action: action) {
            TVRow(title: text, detail: detail, symbol: symbol, focused: on)
        }
        .focused($focus, equals: key)
        .tvButton(on, radius: 22)
    }

    /// تمييزُ العربية: المثنّى له صيغته، والثلاثةُ إلى العشرة جمعُ قلّة، وما
    /// فوقها مفردٌ منصوب. و«2 مدينة» ليست عربية.
    private func countText(_ n: Int) -> String? {
        guard n > 1 else { return nil }
        if n == 2 { return loc("مدينتان") }
        return "\(n) " + ((3...10).contains(n) ? loc("مدن") : loc("مدينة"))
    }

    // MARK: البحث

    private var searchRow: some View {
        let on = focus == .search
        return TextField(loc("بحث بالاسم"), text: $query)
            .textFieldStyle(.plain)
            .font(Theme.display(TVType.body, weight: on ? .bold : .regular))
            .foregroundStyle(on ? Theme.ink : Theme.inkFaint)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 34)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 84)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.accent.opacity(on ? 0.16 : 0.05))
            )
            .focused($focus, equals: .search)
            .tvFocus(on, radius: 22)
    }
}
