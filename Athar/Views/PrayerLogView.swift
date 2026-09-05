import SwiftUI

/// سجل الصلاة: يسجّل المستخدم كل فريضة (في وقتها / متأخّرة / فائتة) ليوم من آخر سبعة،
/// ويرى حصيلة أسبوعه، ويتابع الفوائت التي عليه قضاؤها.
/// عونٌ شخصي على المحاسبة لا أكثر — لا يحكم ولا يذكّر.
struct PrayerLogView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    /// المواقيت تُحلّ فلكيًّا مرة عند تغيّر اليوم لا في كل رسمة (كانت تُحلّ ~١٥ مرة لكل رسمة).
    @State private var times: PrayerTimes?
    /// الأيام المسجَّلة تُقرأ من التفضيلات مرة، وتُجدَّد بعد كل تسجيل — لا مسحًا لكل المفاتيح في كل رسمة.
    @State private var loggedKeys: Set<String> = []
    /// «الآن» يتقدّم كل دقيقة حتى تنفتح رقاقة الصلاة حين يدخل وقتها والشاشة مفتوحة.
    @State private var now = Date()
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var tint: Color { Theme.accent(for: "night") }
    private var prayers: [Prayer] { Prayer.allCases.filter(\.isPrayer) }
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDay) }

    private func reload() {
        times = store.prayerTimes(for: selectedDay)
        loggedKeys = Set(store.loggedDayKeys)
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 18) {
                    dayStrip.appearStagger(0)
                    dayCard.appearStagger(1)
                    statsCard.appearStagger(2)
                    qadaCard.appearStagger(3)
                    note.appearStagger(4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear(perform: reload)
        .onChange(of: selectedDay) { _, _ in reload() }
        .onReceive(ticker) { now = $0 }
        .navigationTitle(loc("سجل الصلاة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }

    // MARK: شريط الأيام

    /// آخر سبعة أيام، اليوم أولها (يمينًا في الاتجاه العربي).
    private var dayStrip: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { back in
                if let day = Calendar.current.date(byAdding: .day, value: -back, to: Calendar.current.startOfDay(for: Date())) {
                    dayPill(day)
                }
            }
        }
    }

    private func dayPill(_ day: Date) -> some View {
        let on = Calendar.current.isDate(day, inSameDayAs: selectedDay)
        let today = Calendar.current.isDateInToday(day)
        let logged = loggedKeys.contains(AtharStore.dayKey(day))
        return Button {
            withAnimation(Motion.snappy) { selectedDay = day }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 4) {
                Text(today ? loc("اليوم") : weekdayName(day))
                    .font(Theme.display(10, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(gregorianDay(day).counterText)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Circle()
                    .fill(logged ? (on ? Theme.onAccent : tint) : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .foregroundStyle(on ? Theme.onAccent : Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(on ? AnyShapeStyle(Theme.gradient(for: "night")) : AnyShapeStyle(Theme.surface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .strokeBorder(on ? Color.clear : Theme.hairline.opacity(0.5), lineWidth: 0.5)
            )
        }
        .pressable()
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: بطاقة اليوم

    private var dayCard: some View {
        AtharCard(padding: 0, elevation: .e2, tint: isToday ? tint : nil) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    IconChip(icon: "checkmark.circle.fill", tint: tint, size: .sm)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isToday ? loc("صلوات اليوم") : loc("صلوات %1$@", weekdayName(selectedDay)))
                            .font(Theme.display(16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(fullDate(selectedDay))
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    Spacer(minLength: 6)
                    if prayers.contains(where: { isDue($0) && store.prayerStatus($0, on: selectedDay) != .onTime }) {
                        Button {
                            markAllOnTime()
                        } label: {
                            Text(loc("الكل في وقتها"))
                                .font(Theme.display(12, weight: .semibold))
                                .foregroundStyle(Theme.accent(for: "green"))
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(Theme.accent(for: "green").opacity(0.12)))
                        }
                        .pressable()
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

                SettingsDivider(inset: 16)

                ForEach(Array(prayers.enumerated()), id: \.element.id) { i, p in
                    prayerRow(p)
                    if i < prayers.count - 1 { SettingsDivider(inset: 60) }
                }
            }
        }
    }

    private func prayerRow(_ p: Prayer) -> some View {
        let status = store.prayerStatus(p, on: selectedDay)
        let due = isDue(p)
        let color = Theme.accent(for: p.accentKey)
        return HStack(spacing: 13) {
            IconChip(icon: p.icon, tint: color, size: .sm)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.title)
                    .font(Theme.display(16))
                    .foregroundStyle(Theme.ink)
                Text(times?[p].map(timeText) ?? "—")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.inkFaint)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            statusChip(status, enabled: due) { cycle(p) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .opacity(due ? 1 : 0.55)
    }

    /// رقاقة الحالة: نقرة تدوّرها (لم تُسجَّل ← في وقتها ← متأخّرة ← فائتة).
    private func statusChip(_ s: AtharStore.PrayerStatus, enabled: Bool, action: @escaping () -> Void) -> some View {
        let color = s.logColor
        return Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: s.logIcon)
                    .font(.system(size: 11, weight: .semibold))
                Text(enabled ? s.title : loc("لم يحن وقتها"))
                    .font(Theme.display(12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(color)
            .padding(.horizontal, 11).padding(.vertical, 7)
            .background(Capsule().fill(color.opacity(s == .none ? 0.04 : 0.13)))
            .overlay(Capsule().strokeBorder(color.opacity(s == .none ? 0.35 : 0.22), lineWidth: 0.7))
            .contentTransition(.opacity)
            .animation(Motion.snappy, value: s)
        }
        .pressable()
        .disabled(!enabled)
        .accessibilityLabel(enabled ? s.title : loc("لم يحن وقتها"))
        .accessibilityHint(enabled ? loc("انقر لتغيير الحالة") : "")
    }

    /// اليوم لا تُسجَّل صلاة لم يدخل وقتها بعد؛ والأيام الماضية كلها مفتوحة.
    private func isDue(_ p: Prayer) -> Bool {
        guard isToday, let t = times?[p] else { return true }
        return t <= now
    }

    private func cycle(_ p: Prayer) {
        let old = store.prayerStatus(p, on: selectedDay)
        apply(old.nextStatus, to: p, from: old)
        if old.nextStatus == .onTime {
            Haptics.done(enabled: store.hapticsEnabled)
        } else {
            Haptics.tap(enabled: store.hapticsEnabled)
        }
    }

    private func markAllOnTime() {
        for p in prayers where isDue(p) {
            let old = store.prayerStatus(p, on: selectedDay)
            if old != .onTime { apply(.onTime, to: p, from: old) }
        }
        Haptics.done(enabled: store.hapticsEnabled)
    }

    /// تسجيل «فائتة» يضيفها إلى الفوائت تلقائيًا، والعدول عنها يُنقصها — حتى لا يُعدّ الشيء مرّتين.
    private func apply(_ new: AtharStore.PrayerStatus, to p: Prayer, from old: AtharStore.PrayerStatus) {
        withAnimation(Motion.snappy) {
            store.setPrayerStatus(new, for: p, on: selectedDay)
            loggedKeys = Set(store.loggedDayKeys)
            if new == .missed, old != .missed {
                store.setQadaCount(store.qadaCount(p) + 1, for: p)
            } else if old == .missed, new != .missed {
                store.setQadaCount(store.qadaCount(p) - 1, for: p)
            }
        }
    }

    // MARK: الإحصاء

    private struct WeekStats {
        var onTime = 0, late = 0, missed = 0
        var logged: Int { onTime + late + missed }
    }

    /// آخر سبعة أيام بما فيها اليوم.
    private var weekStats: WeekStats {
        var s = WeekStats()
        let start = Calendar.current.startOfDay(for: Date())
        for back in 0..<7 {
            guard let day = Calendar.current.date(byAdding: .day, value: -back, to: start) else { continue }
            for p in prayers {
                switch store.prayerStatus(p, on: day) {
                case .onTime: s.onTime += 1
                case .late:   s.late += 1
                case .missed: s.missed += 1
                case .none:   break
                }
            }
        }
        return s
    }

    private var statsCard: some View {
        let s = weekStats
        let ratio = s.logged > 0 ? Double(s.onTime) / Double(s.logged) : 0
        return AtharCard(padding: 16) {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: ratio, color: Theme.accent(for: "green"), lineWidth: 7)
                    Text(s.logged > 0 ? "\(Int((ratio * 100).rounded()).counterText)٪" : "—")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("هذا الأسبوع"))
                        .font(Theme.display(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(s.logged > 0
                         ? loc("%1$@ من %2$@ في وقتها", s.onTime.counterText, s.logged.counterText)
                         : loc("لم تسجّل شيئًا بعد — ابدأ بصلاة اليوم."))
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        statTag(s.onTime, color: Theme.accent(for: "green"), title: loc("في وقتها"))
                        statTag(s.late, color: Theme.gold, title: loc("متأخّرة"))
                        statTag(s.missed, color: Theme.danger, title: loc("فائتة"))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func statTag(_ n: Int, color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            Text(n.counterText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(title)
                .font(Theme.display(10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    // MARK: الفوائت

    private var qadaTotal: Int { prayers.reduce(0) { $0 + store.qadaCount($1) } }

    private var qadaCard: some View {
        VStack(spacing: 10) {
            SectionHeader(title: loc("الفوائت"), tint: Theme.danger)
            SettingsCard {
                ForEach(Array(prayers.enumerated()), id: \.element.id) { i, p in
                    qadaRow(p)
                    if i < prayers.count - 1 { SettingsDivider(inset: 60) }
                }
                SettingsDivider(inset: 0)
                qadaFooter
            }
        }
    }

    private func qadaRow(_ p: Prayer) -> some View {
        let n = store.qadaCount(p)
        return HStack(spacing: 13) {
            IconChip(icon: p.icon, tint: Theme.accent(for: p.accentKey), size: .sm)
            Text(p.title)
                .font(Theme.display(16))
                .foregroundStyle(Theme.ink)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                stepButton("minus", enabled: n > 0) { setQada(p, n - 1) }
                    .accessibilityLabel(loc("إنقاص فوائت %1$@", p.title))
                Text(n.counterText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(n > 0 ? Theme.ink : Theme.inkFaint)
                    .monospacedDigit()
                    .frame(minWidth: 34)
                    .contentTransition(.numericText())
                    .animation(Motion.snappy, value: n)
                stepButton("plus", enabled: true) { setQada(p, n + 1) }
                    .accessibilityLabel(loc("زيادة فوائت %1$@", p.title))
            }
            .accessibilityElement(children: .contain)
            .accessibilityValue(loc("%1$@ فائتة", n.counterText))
            .background(Capsule().fill(Theme.surfaceAlt))
            .overlay(Capsule().strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    private func stepButton(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? tint : Theme.inkFaint.opacity(0.5))
                .frame(width: 34, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// «قضيت واحدة»: قائمة بالصلوات التي عليها فوائت — اختيار واحدة يُنقصها.
    @ViewBuilder
    private var qadaFooter: some View {
        if qadaTotal > 0 {
            Menu {
                ForEach(prayers.filter { store.qadaCount($0) > 0 }) { p in
                    Button {
                        setQada(p, store.qadaCount(p) - 1, done: true)
                    } label: {
                        Label(loc("%1$@ (%2$@)", p.title, store.qadaCount(p).counterText), systemImage: p.icon)
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(loc("قضيت واحدة"))
                        .font(Theme.display(15, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(loc("الباقي %1$@", qadaTotal.counterText))
                        .font(Theme.display(12, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                }
                .foregroundStyle(Theme.accent(for: "green"))
                .padding(.horizontal, 16).padding(.vertical, 13)
                .contentShape(Rectangle())
            }
        } else {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(loc("لا فوائت عليك — الحمد لله"))
                    .font(Theme.display(13, weight: .medium))
            }
            .foregroundStyle(Theme.accent(for: "green"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    private func setQada(_ p: Prayer, _ n: Int, done: Bool = false) {
        withAnimation(Motion.snappy) { store.setQadaCount(n, for: p) }
        if done {
            Haptics.done(enabled: store.hapticsEnabled)
        } else {
            Haptics.tap(enabled: store.hapticsEnabled)
        }
    }

    // MARK: ملاحظة

    private var note: some View {
        VStack(alignment: .leading, spacing: 6) {
            noteLine(loc("السجل عونٌ شخصي على المحاسبة، لا حكم ولا رقيب — وما يُكتب يبقى على جهازك."))
            noteLine(loc("تُعدّ الفجر والعشاء كسائر الصلوات، وتسجيل «فائتة» يضيفها إلى الفوائت تلقائيًا."))
        }
        .padding(.horizontal, 6)
    }

    private func noteLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle().fill(Theme.inkFaint.opacity(0.6)).frame(width: 4, height: 4).padding(.top, 7)
            Text(text)
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: تنسيق

    /// وقت الصلاة بمنطقة المكان المختار لا بمنطقة الجهاز — كما في شاشة الصلاة.
    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = store.placeTimeZone
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    private func weekdayName(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private func fullDate(_ date: Date) -> String {
        let h = Occasions.hijriComponents(date)
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "d MMMM"
        return "\(h.day.counterText) \(Occasions.monthName(h.month)) · \(f.string(from: date))"
    }

    /// رقم اليوم بالتقويم الميلادي الثابت — نفسه الذي يُبنى عليه مفتاح السجل.
    private func gregorianDay(_ date: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        return cal.component(.day, from: date)
    }
}

// MARK: - مظهر الحالة

private extension AtharStore.PrayerStatus {
    var logIcon: String {
        switch self {
        case .none:   return "circle"
        case .onTime: return "checkmark.circle.fill"
        case .late:   return "clock.fill"
        case .missed: return "xmark.circle.fill"
        }
    }

    /// في وقتها أخضر، متأخّرة ذهبيّ، فائتة بلون الخطر الوحيد في التطبيق.
    var logColor: Color {
        switch self {
        case .none:   return Theme.inkFaint
        case .onTime: return Theme.accent(for: "green")
        case .late:   return Theme.gold
        case .missed: return Theme.danger
        }
    }

    var nextStatus: AtharStore.PrayerStatus {
        switch self {
        case .none:   return .onTime
        case .onTime: return .late
        case .late:   return .missed
        case .missed: return .none
        }
    }
}
