import SwiftUI
import WidgetKit

/// التقويم الهجري بحساب أم القرى: شبكة الشهر، واليوم، ومناسبات السنّة القادمة.
/// لا يُدرج من المناسبات إلا ما له أصل في الكتاب والسنّة (انظر Occasions).
struct HijriCalendarView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    /// الشهر المعروض — يبدأ بشهر اليوم ويتنقّل المستخدم منه.
    @State private var year = Occasions.hijriComponents(Date()).year
    @State private var month = Occasions.hijriComponents(Date()).month
    @State private var selected = Calendar.current.startOfDay(for: Date())
    @State private var expanded: String?
    /// تجدّد «اليوم» إن انقضى اليوم والشاشة مفتوحة (بعد منتصف الليل).
    @State private var todayDate = Calendar.current.startOfDay(for: Date())
    private let dayTicker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var tint: Color { Theme.accent(for: "noon") }
    private var today: (year: Int, month: Int, day: Int) { Occasions.hijriComponents(todayDate) }
    private var isCurrentMonth: Bool { today.year == year && today.month == month }

    /// تقويم أم القرى بمنطقة الجهاز — لأسماء أيام الأسبوع ومواقعها في الشبكة،
    /// وهي لا تتأثّر بضبط المطالع فيُؤخذ الأصل من مصدره الواحد.
    private var hijri: Calendar {
        var c = Hijri.calendar
        c.locale = Locale(identifier: "ar")
        return c
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.accent(for: "night"))
            ScrollView {
                VStack(spacing: 18) {
                    monthCard.appearStagger(0)
                    offsetCard.appearStagger(1)
                    selectedDayCard.appearStagger(2)
                    upcomingSection.appearStagger(3)
                    footer.appearStagger(4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .onReceive(dayTicker) { _ in
            let t = Calendar.current.startOfDay(for: Date())
            if t != todayDate { todayDate = t }
        }
        .navigationTitle(loc("التقويم"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }

    // MARK: الشهر

    private var monthCard: some View {
        AtharCard(padding: 16, elevation: .e2) {
            VStack(spacing: 14) {
                monthHeader
                weekdayHeader
                daysGrid
            }
        }
    }

    private var monthHeader: some View {
        HStack(spacing: 8) {
            navButton("chevron.backward") { shift(-1) }
            Spacer(minLength: 0)
            VStack(spacing: 3) {
                Text("\(Occasions.monthName(month)) \(String(year))")
                    .font(Theme.display(19, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text(gregorianSpan)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 0)
            if isCurrentMonth {
                navButton("chevron.forward") { shift(1) }
            } else {
                // بعيدًا عن شهر اليوم يظهر زرّ عودة بدل التخبّط بالأسهم.
                Button {
                    withAnimation(Motion.snappy) { goToday() }
                    Haptics.tap(enabled: store.hapticsEnabled)
                } label: {
                    Text(loc("اليوم"))
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Capsule().fill(tint.opacity(0.13)))
                }
                .pressable()
                navButton("chevron.forward") { shift(1) }
            }
        }
    }

    private func navButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(Motion.snappy) { action() }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(tint.opacity(0.12)))
        }
        // زرّ رمزٍ بلا عنوان: VoiceOver كان يقرأ اسم الرمز بالإنجليزية.
        .accessibilityLabel(icon == "chevron.backward" ? loc("الشهر السابق") : loc("الشهر التالي"))
        .pressable()
    }

    /// أسماء الأيام من الأحد: في الاتجاه العربي يقع الأحد يمينًا والسبت يسارًا كالتقاويم المطبوعة.
    private var weekdayHeader: some View {
        let names = hijri.shortWeekdaySymbols
        return HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                Text(i < names.count ? names[i] : "")
                    .font(Theme.display(11, weight: .semibold))
                    .foregroundStyle(i == 5 ? tint : Theme.inkFaint)   // الجمعة مميّزة
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        let count = Occasions.daysInMonth(year: year, month: month)
        let lead = leadingBlanks
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 6) {
            ForEach(0..<lead, id: \.self) { _ in
                Color.clear.frame(height: 44)
            }
            ForEach(1...count, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    /// فراغات قبل اليوم الأول بعدد أيام الأسبوع السابقة له (الأحد = ١).
    private var leadingBlanks: Int {
        guard let first = Occasions.date(year: year, month: month, day: 1) else { return 0 }
        return max(0, hijri.component(.weekday, from: first) - 1)
    }

    private func dayCell(_ day: Int) -> some View {
        let date = Occasions.date(year: year, month: month, day: day)
        let isToday = today.year == year && today.month == month && today.day == day
        let isSelected = date.map { Calendar.current.isDate($0, inSameDayAs: selected) } ?? false
        let marks = date.map(Occasions.occasions(on:)) ?? []
        return Button {
            guard let date else { return }
            withAnimation(Motion.snappy) { selected = date }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 3) {
                Text(day.counterText)
                    .font(.system(size: 15, weight: isToday || isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isToday ? Theme.onAccent : Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(isToday ? AnyShapeStyle(Theme.gradient(for: "noon")) : AnyShapeStyle(Color.clear))
                    )
                    .overlay(
                        Circle().strokeBorder(isSelected && !isToday ? tint : Color.clear, lineWidth: 1.5)
                    )
                // نقاط المناسبات بلون كلّ منها — ثلاث على الأكثر.
                HStack(spacing: 2) {
                    ForEach(marks.prefix(3)) { o in
                        Circle()
                            .fill(Theme.accent(for: o.accent))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(loc("%1$@ %2$@", day.counterText, Occasions.monthName(month)))
    }

    /// المدى الميلادي للشهر المعروض: «من ٢٠ مايو إلى ١٨ يونيو ٢٠٢٦».
    private var gregorianSpan: String {
        let count = Occasions.daysInMonth(year: year, month: month)
        guard let first = Occasions.date(year: year, month: month, day: 1),
              let last = Occasions.date(year: year, month: month, day: count) else { return "" }
        let f = gregorianFormatter("d MMMM")
        let g = gregorianFormatter("d MMMM yyyy")
        return loc("من %1$@ إلى %2$@ م", f.string(from: first), g.string(from: last))
    }

    private func gregorianFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    private func shift(_ delta: Int) {
        var m = month + delta, y = year
        if m > 12 { m = 1; y += 1 }
        if m < 1 { m = 12; y -= 1 }
        // حدود معقولة حتى لا يطير المستخدم إلى قرون لا تقويم فيها.
        guard (1300...1600).contains(y) else { return }
        month = m; year = y
        // اختيار اليوم يتبع الشهر: اليوم إن كان شهره، وإلا أوّله.
        if isCurrentMonth {
            selected = Calendar.current.startOfDay(for: Date())
        } else if let first = Occasions.date(year: y, month: m, day: 1) {
            selected = first
        }
    }

    private func goToday() {
        let t = today
        year = t.year; month = t.month
        selected = Calendar.current.startOfDay(for: Date())
    }

    // MARK: ضبط المطالع

    /// صفٌّ هادئ لا زرّ بارز: أكثر الناس لا يحتاجه، ومن اختلف تقويمُ بلده عن
    /// الحساب وجده حيث ينظر — تحت الشهر مباشرة — فعدّل يومًا أو يومين.
    private var offsetCard: some View {
        let offset = store.hijriOffset
        return VStack(spacing: 8) {
            SettingsCard {
                // «زائد وناقص» كصفّ ضبط المواقيت بالدقائق — تعديلٌ يدويّ على حسابٍ آليّ.
                SettingsRow(icon: "plusminus.circle.fill", tint: tint,
                            title: loc("ضبط التاريخ الهجري"),
                            subtitle: offsetLabel(offset)) {
                    HStack(spacing: 0) {
                        step("minus", enabled: offset > Hijri.bounds.lowerBound) { change(-1) }
                            .accessibilityLabel(loc("أنقص يومًا"))
                        Text(offsetText(offset))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(offset == 0 ? Theme.inkFaint : Theme.ink)
                            .monospacedDigit()
                            .frame(minWidth: 40)
                            .contentTransition(.numericText())
                            .animation(Motion.snappy, value: offset)
                        step("plus", enabled: offset < Hijri.bounds.upperBound) { change(1) }
                            .accessibilityLabel(loc("زد يومًا"))
                    }
                    .background(Capsule().fill(Theme.surfaceAlt))
                    .overlay(Capsule().strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
                    .accessibilityElement(children: .contain)
                    .accessibilityValue(offsetLabel(offset))
                }
            }
            // الشرح تحت البطاقة لا في الصفّ: الصفّ ضيّق بالمزلاج، ولو حُشر فيه
            // لالتفّ على أربعة أسطر وضاق العنوان.
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                Text(loc("اختلاف المطالع: عدّل يومًا أو يومين ليوافق تقويم بلدك"))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
        }
    }

    private func step(_ icon: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? tint : Theme.inkFaint)
                // أربعون وأربع: هدف اللمس لا ينزل عنها وإن كان الرمز صغيرًا.
                .frame(width: 40, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    /// الشهر المعروض يتبع اليوم: من كان على شهره وأزاح المطالع يومين قد ينتقل
    /// إلى شهرٍ آخر، فيُساق معه كي لا يبحث عن يومه في شبكةٍ لم يعد فيها.
    private func change(_ delta: Int) {
        let wasCurrent = isCurrentMonth
        withAnimation(Motion.snappy) {
            store.hijriOffset += delta
            if wasCurrent { goToday() }
        }
        Haptics.tap(enabled: store.hapticsEnabled)
        // الودجات تقرأ الإزاحة من الدفاتر نفسها، فتُنبَّه لتعيد رسم ما بنَتْه على الأمس.
        WidgetCenter.shared.reloadAllTimelines()
        // والتنبيهات المعلّقة بُنيت على التقويم القديم: الأيام البيض وصيام الاثنين والخميس
        // مجدولةٌ بتواريخ ما عادت تطابق ما يراه. فتُعاد جدولتها على التقويم الجديد.
        Task { await Reminders.rescheduleAll(store: store) }
    }

    private func offsetText(_ n: Int) -> String {
        n == 0 ? "0" : (n > 0 ? "+\(n.counterText)" : "−\(abs(n).counterText)")
    }

    /// ما ينطق به VoiceOver بدل «زائد ١»: تقديمٌ أو تأخيرٌ بلفظ العدد العربي.
    private func offsetLabel(_ n: Int) -> String {
        switch n {
        case 0:  return loc("بلا تعديل")
        case 1:  return loc("يوم واحد بعد الحساب")
        case 2:  return loc("يومان بعد الحساب")
        case -1: return loc("يوم واحد قبل الحساب")
        default: return loc("يومان قبل الحساب")
        }
    }

    // MARK: اليوم المختار

    private var selectedDayCard: some View {
        let c = Occasions.hijriComponents(selected)
        let marks = Occasions.occasions(on: selected)
        let isToday = Calendar.current.isDateInToday(selected)
        return AtharCard(padding: 16, tint: isToday ? tint : nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    IconChip(icon: isToday ? "sun.max.fill" : "calendar", tint: tint, size: .md)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(c.day.counterText) \(Occasions.monthName(c.month)) \(String(c.year)) هـ")
                            .font(Theme.display(17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(gregorianFormatter("EEEE، d MMMM yyyy").string(from: selected) + " م")
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 0)
                    if isToday {
                        Text(loc("اليوم"))
                            .font(Theme.display(11, weight: .semibold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(Capsule().fill(tint.opacity(0.13)))
                    }
                }
                if !marks.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(marks) { o in
                            HStack(spacing: 7) {
                                Image(systemName: o.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(o.title)
                                    .font(Theme.display(12, weight: .semibold))
                            }
                            .foregroundStyle(Theme.accent(for: o.accent))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Theme.accent(for: o.accent).opacity(0.12)))
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    // MARK: المناسبات القادمة

    private var upcomingSection: some View {
        let items = Occasions.upcoming(from: Date(), limit: 8)
        return VStack(spacing: 10) {
            SectionHeader(title: loc("مناسبات قادمة"), tint: tint)
            SettingsCard {
                // المعرّف بالترتيب لا بمسار مفتاح داخل الصفّ (tuple) — أضمن للمترجم.
                ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                    occasionRow(item)
                    if i < items.count - 1 { SettingsDivider(inset: 16) }
                }
            }
        }
    }

    private func occasionRow(_ item: (occasion: HijriOccasion, start: Date, end: Date)) -> some View {
        let o = item.occasion
        let color = Theme.accent(for: o.accent)
        let open = expanded == o.id
        let days = Occasions.daysUntil(item.start)
        let c = Occasions.hijriComponents(item.start)
        return Button {
            withAnimation(Motion.smooth) { expanded = open ? nil : o.id }
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    IconChip(icon: o.icon, tint: color, size: .md)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(o.title)
                            .font(Theme.display(16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text("\(whenText(days)) · \(c.day.counterText) \(Occasions.monthName(c.month))"
                             + (o.days > 1 ? " · \(dayCountText(o.days))" : ""))
                            .font(Theme.display(12))
                            .foregroundStyle(days <= 0 ? color : Theme.inkSoft)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .rotationEffect(.degrees(open ? 180 : 0))
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                if open {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(o.detail)
                            .font(Theme.display(14))
                            .foregroundStyle(Theme.inkSoft)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                        // الدليل بخط النسخ وحبر الصفحة — لا يُلوَّن.
                        VStack(alignment: .leading, spacing: 5) {
                            Text(o.evidence)
                                .font(Theme.dhikrFont(size: 16))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(7)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(o.evidenceSource)
                                .font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                .fill(color.opacity(0.07))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                                    .strokeBorder(color.opacity(0.18), lineWidth: 0.5))
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func whenText(_ days: Int) -> String {
        days <= 0 ? loc("جارية الآن")
            : days == 1 ? loc("غدًا")
            : days == 2 ? loc("بعد يومين")
            : days <= 10 ? loc("بعد %1$@ أيام", days.counterText)
            : loc("بعد %1$@ يومًا", days.counterText)
    }

    private func dayCountText(_ n: Int) -> String {
        n == 2 ? loc("يومان")
            : (3...10).contains(n) ? loc("%1$@ أيام", n.counterText)
            : loc("%1$@ يومًا", n.counterText)
    }

    // MARK: الذيل

    private var footer: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Theme.hairline.opacity(0.6))
                .frame(height: 0.7).padding(.horizontal, 50)
            Text(loc("لا يُدرج هنا إلا ما له أصل في الكتاب والسنّة"))
                .font(Theme.display(12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
            Text(loc("التقويم بحساب أم القرى، وقد يتقدّم يومًا أو يتأخّر عن ثبوت الرؤية."))
                .font(Theme.display(11))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}
