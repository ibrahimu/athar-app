import SwiftUI
import WidgetKit

struct PrayerView: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var location: LocationProvider
    @State private var now = Date()
    @State private var showCityPicker = false
    @Environment(\.layoutDirection) private var layoutDirection

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(store: AtharStore) {
        _location = StateObject(wrappedValue: LocationProvider(store: store))
    }

    private var times: PrayerTimes? { store.prayerTimes(for: now) }

    /// Next prayer today, rolling over to tomorrow's Fajr after Isha.
    private var upcoming: (prayer: Prayer, date: Date)? {
        if let next = times?.next(after: now) { return next }
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let t = store.prayerTimes(for: tomorrow), let fajr = t[.fajr]
        else { return nil }
        return (.fajr, fajr)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        countdownCard.appearStagger(0)
                        dayArc.appearStagger(1)
                        timesList.appearStagger(2)
                        qiyamCard.appearStagger(3)
                        highLatitudeNote.appearStagger(4)
                        qiblaLink.appearStagger(5)
                        afterPrayerLink.appearStagger(6)
                        methodNote.appearStagger(7)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                    .readableWidth()
                }
            }
            .navigationTitle(loc("الصلاة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCityPicker = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.accent)
                            Text(store.placeName)
                                .font(Theme.display(13, weight: .medium))
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.accentSoft))
                    }
                    .pressable()
                }
            }
            .sheet(isPresented: $showCityPicker) {
                LocationPickerView(location: location)
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    // MARK: Countdown

    /// البطاقة البطلة: تعبئة متدرّجة بلون الوقت، توهّج شعاعيّ خلف الأيقونة،
    /// وظلّ ملوّن يرفعها عن الورق. النص يبقى حِبرًا.
    @ViewBuilder
    private var countdownCard: some View {
        if let upcoming {
            let key = upcoming.prayer.accentKey
            let tint = Theme.accent(for: key)
            VStack(spacing: 14) {
                Text(loc("الصلاة القادمة"))
                    .font(Theme.display(13, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)

                HStack(spacing: 12) {
                    ZStack {
                        // توهّج شعاعيّ باهت خلف الأيقونة
                        RadialGradient(colors: [tint.opacity(0.30), .clear],
                                       center: .center, startRadius: 0, endRadius: 30)
                            .frame(width: 62, height: 62)
                        Image(systemName: upcoming.prayer.icon)
                            .font(.system(size: 26))
                            .foregroundStyle(tint)
                    }
                    Text(upcoming.prayer.title)
                        .font(Theme.display(34, weight: .bold))
                        .foregroundStyle(Theme.ink)
                }

                Text(Self.time(upcoming.date, in: store.placeTimeZone))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)

                countdownPill(next: upcoming.date, tint: tint, key: key)
            }
            .padding(26)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(LinearGradient(colors: [tint.opacity(0.16), Theme.surface],
                                         startPoint: .topTrailing, endPoint: .bottomLeading))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                        .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
            )
            .atharElevation(.e2)
            .shadow(color: tint.opacity(0.18), radius: 20, y: 8)
        } else {
            AtharCard(padding: 22) {
                Text(loc("تعذّر حساب أوقات الصلاة لهذا الموقع"))
                    .font(Theme.display(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// حبّة العدّ التنازلي: كبسولة تمتلئ بتدرّج لون الوقت بنسبة ما انقضى
    /// من الصلاة السابقة إلى القادمة، وتتحرّك مع نبضة الثانية.
    private func countdownPill(next: Date, tint: Color, key: String) -> some View {
        let frac = elapsed(to: next)
        return HStack(spacing: 6) {
            Image(systemName: "hourglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
            Text(remaining(to: next))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkSoft)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.12))
                    Capsule()
                        .fill(Theme.gradient(for: key))
                        .frame(width: geo.size.width * frac)
                        .opacity(0.28)
                }
                .animation(Motion.smooth, value: frac)
            }
        )
        .overlay(Capsule().strokeBorder(tint.opacity(0.20), lineWidth: 0.5))
        .clipShape(Capsule())
    }

    /// نسبة ما انقضى من الوقت السابق إلى الصلاة القادمة (٠…١).
    private func elapsed(to next: Date) -> Double {
        guard let times else { return 0 }
        let prev = times.ordered.map(\.date).filter { $0 <= now }.max()
            ?? next.addingTimeInterval(-6 * 3600)
        let total = next.timeIntervalSince(prev)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(prev) / total))
    }

    private func remaining(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0
            ? String(format: loc("بعد %d:%02d:%02d"), h, m, s)
            : String(format: loc("بعد %d:%02d"), m, s)
    }

    // MARK: Day arc — شريط اليوم

    /// خيط رفيع يمثّل اليوم من الفجر إلى العشاء: تدرّج ينساب عبر ألوان الأوقات،
    /// ممتلئ حتى اللحظة الحاضرة بنقطة متوهّجة، وستّ علامات لكل وقت.
    @ViewBuilder
    private var dayArc: some View {
        if let times, let fajr = times[.fajr], let isha = times[.isha], isha > fajr {
            let span = isha.timeIntervalSince(fajr)
            let nowFrac = min(1, max(0, now.timeIntervalSince(fajr) / span))
            let dayColors: [Color] = [
                Theme.accent(for: "dusk"),
                Theme.accent(for: "dawn"),
                Theme.accent(for: "noon"),
                Theme.accent(for: "maghrib"),
                Theme.accent(for: "night")
            ]
            let dotColor = Theme.accent(for: (upcoming?.prayer ?? .isha).accentKey)
            AtharCard(padding: 16) {
                VStack(spacing: 10) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let midY = geo.size.height / 2
                        ZStack {
                            // المسار الخافت
                            Capsule().fill(Theme.hairline.opacity(0.6))
                                .frame(height: 6)

                            // التدرّج المنساب، مكشوفٌ حتى اللحظة الحاضرة
                            Capsule()
                                .fill(LinearGradient(
                                    colors: dayColors,
                                    startPoint: UnitPoint(x: layoutDirection == .rightToLeft ? 1 : 0, y: 0.5),
                                    endPoint: UnitPoint(x: layoutDirection == .rightToLeft ? 0 : 1, y: 0.5)))
                                .frame(height: 6)
                                .mask(alignment: .leading) {
                                    Capsule().frame(width: max(6, w * nowFrac))
                                }

                            // ستّ علامات لكل وقت
                            ForEach(times.ordered, id: \.prayer) { entry in
                                let f = min(1, max(0, entry.date.timeIntervalSince(fajr) / span))
                                Circle()
                                    .fill(Theme.surface)
                                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                                    .frame(width: 5, height: 5)
                                    .position(x: arcX(f, w), y: midY)
                            }

                            // النقطة المتوهّجة عند الآن
                            ZStack {
                                Circle().fill(dotColor)
                                    .frame(width: 13, height: 13)
                                    .blur(radius: 5).opacity(0.7)
                                Circle().fill(dotColor)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().strokeBorder(Theme.surface, lineWidth: 1.5))
                            }
                            .position(x: arcX(nowFrac, w), y: midY)
                        }
                        .animation(Motion.smooth, value: nowFrac)
                    }
                    .frame(height: 16)

                    HStack {
                        Text(Prayer.fajr.title)
                            .font(Theme.display(10, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                        Spacer()
                        Text(Prayer.isha.title)
                            .font(Theme.display(10, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
        }
    }

    /// موضع الكسر على الخيط — يُعكس في الاتجاه العربي فيبدأ الفجر من اليمين.
    private func arcX(_ f: Double, _ w: CGFloat) -> CGFloat {
        layoutDirection == .rightToLeft ? w * (1 - f) : w * f
    }

    // MARK: List

    private var timesList: some View {
        VStack(spacing: 0) {
            if let times {
                let ordered = times.ordered
                let nextIdx = ordered.firstIndex { upcoming?.prayer == $0.prayer && $0.date > now }
                ForEach(Array(ordered.enumerated()), id: \.element.prayer) { index, entry in
                    let isNext = nextIdx == index
                    // لون الوقت لكل صلاة؛ الشروق ليس صلاة فيبقى حبرًا خافتًا.
                    let rowTint = entry.prayer.isPrayer
                        ? Theme.accent(for: entry.prayer.accentKey)
                        : Theme.inkFaint
                    HStack(spacing: 12) {
                        Image(systemName: entry.prayer.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(rowTint)
                            .frame(width: 34, height: 34)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(rowTint.opacity(0.14)))

                        Text(entry.prayer.title)
                            .font(Theme.display(17, weight: isNext ? .bold : .regular))
                            .foregroundStyle(entry.prayer.isPrayer ? Theme.ink : Theme.inkSoft)

                        Spacer()

                        Text(Self.time(entry.date, in: store.placeTimeZone))
                            .font(.system(size: 17, weight: isNext ? .bold : .regular, design: .rounded))
                            .foregroundStyle(isNext ? rowTint : Theme.inkSoft)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background {
                        if isNext { nextHighlight(rowTint) }
                    }
                    .animation(Motion.smooth, value: isNext)

                    // نُخفي الفاصلين الملاصقين لرقاقة الصلاة القادمة لتبدو طليقة.
                    if index < ordered.count - 1, index != nextIdx, index + 1 != nextIdx {
                        Divider().overlay(Theme.hairline).padding(.horizontal, 18)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.surfaceGradient))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
            .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
    }

    /// رقاقة الصلاة القادمة: مستطيل مُدمج بتدرّج لون الوقت، حدّ شعريّ، وشريط
    /// لونيّ على الحافة البادئة — بديل الشريط الممتدّ عرض البطاقة.
    @ViewBuilder
    private func nextHighlight(_ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.18), tint.opacity(0.06)],
                                 startPoint: .topTrailing, endPoint: .bottomLeading))
            .overlay(alignment: .leading) {
                Capsule().fill(tint).frame(width: 3).padding(.vertical, 9)
            }
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
    }

    // MARK: Extras

    private var qiblaLink: some View {
        NavigationLink { QiblaView() } label: {
            AtharCard(padding: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "location.north.line.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(Theme.gold.opacity(0.13)))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(loc("اتجاه القبلة"))
                                .font(Theme.display(17, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        Text(qiblaSubtitle)
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                    }

                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    private var qiblaSubtitle: String {
        guard let b = Qibla.bearing(from: store.coordinate) else { return loc("أنت عند الكعبة") }
        return String(format: "%.0f° — %@ من %@", b, Qibla.compassName(for: b), store.placeName)
    }

    @ViewBuilder
    private var afterPrayerLink: some View {
        if let category = AdhkarLibrary.category(id: "prayer") {
            NavigationLink { DhikrSessionView(category: category) } label: {
                CategoryRow(category: category, completed: store.completedToday.contains(category.id))
            }
            .pressable()
        }
    }

    /// قيام الليل — ثلث الليل الآخر، وهو وقت النزول الإلهي.
    @ViewBuilder
    private var qiyamCard: some View {
        if let q = qiyamWindow {
            let inWindow = now >= q.lastThird && now < q.end
            AtharCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.accent(for: "night"))
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Theme.accent(for: "night").opacity(0.14)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("قيام الليل"))
                                .font(Theme.display(16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(inWindow ? loc("أنت في ثلث الليل الآخر") : loc("ثلث الليل الآخر"))
                                .font(Theme.display(11))
                                .foregroundStyle(inWindow ? Theme.accent : Theme.inkFaint)
                        }
                        Spacer()
                        if inWindow {
                            Circle().fill(Theme.accent).frame(width: 8, height: 8)
                        }
                    }

                    HStack(spacing: 0) {
                        qiyamSlot(loc("منتصف الليل"), q.midnight)
                        Rectangle().fill(Theme.hairline).frame(width: 1, height: 30)
                        qiyamSlot(loc("الثلث الأخير"), q.lastThird)
                        Rectangle().fill(Theme.hairline).frame(width: 1, height: 30)
                        qiyamSlot(loc("ينتهي بالفجر"), q.end)
                    }

                    Text("«ينزل ربنا إلى السماء الدنيا حين يبقى ثلث الليل الآخر» — متفق عليه")
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func qiyamSlot(_ label: String, _ date: Date) -> some View {
        VStack(spacing: 3) {
            Text(label).font(Theme.display(10)).foregroundStyle(Theme.inkFaint)
            Text(Self.clock.string(from: date))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private var qiyamWindow: (lastThird: Date, midnight: Date, end: Date)? {
        guard let t = times,
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let tm = store.prayerTimes(for: tomorrow), let fajr = tm[.fajr]
        else { return nil }
        return t.qiyam(tomorrowFajr: fajr)
    }

    @ViewBuilder
    private var highLatitudeNote: some View {
        if times?.usedHighLatitudeRule == true {
            noteCard(icon: "info.circle.fill", tint: Theme.gold) {
                Text(loc("في هذا الوقت من السنة لا تنزل الشمس إلى الزاوية المطلوبة في %1$@، فقُدِّر الفجر والعشاء بقاعدة سُبع الليل.", store.placeName))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var methodNote: some View {
        noteCard(icon: "function", tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 3) {
                Text(loc("طريقة الحساب: %1$@", store.calculationMethod.title))
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                Text(loc("الأوقات محسوبة على جهازك فلكيًا — قد تختلف دقائق عن مسجد حيّك."))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    /// بطاقة ملاحظة ثانوية: خلفية سطح ثانوي، وشارة أيقونة مصبوغة على الحافة
    /// البادئة، والنصّ محاذًى للبداية.
    private func noteCard<Content: View>(icon: String, tint: Color,
                                         @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.14)))
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .fill(Theme.surfaceAlt))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
    }

    static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "h:mm a"
        return f
    }()

    /// Renders an instant in the chosen place's own zone, so a city picked from
    /// another country reads the way a local there would read it.
    static func time(_ date: Date, in zone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "h:mm a"
        f.timeZone = zone
        return f.string(from: date)
    }
}

// MARK: - Location picker

struct LocationPickerView: View {
    @EnvironmentObject private var store: AtharStore
    @ObservedObject var location: LocationProvider
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var cities: [City] {
        let needle = query.trimmingCharacters(in: .whitespaces).normalizedArabic
        guard !needle.isEmpty else { return City.all }
        return City.all.filter {
            $0.name.normalizedArabic.contains(needle) || $0.country.normalizedArabic.contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        location.request()
                    } label: {
                        HStack {
                            Label(loc("استخدام موقعي الحالي"), systemImage: "location.fill")
                            Spacer()
                            if location.isResolving { ProgressView() }
                            else if store.usesDeviceLocation {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    if location.failed {
                        Text(loc("تعذّر تحديد الموقع. تأكد من السماح للتطبيق بالوصول للموقع، أو اختر مدينتك يدويًا."))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                } footer: {
                    Text(loc("موقعك يُستخدم على جهازك فقط لحساب أوقات الصلاة، ولا يُرسل إلى أي جهة."))
                }

                Section(loc("المدن")) {
                    ForEach(cities) { city in
                        Button {
                            store.setCity(city)
                            WidgetCenter.shared.reloadAllTimelines()
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(city.name).foregroundStyle(Theme.ink)
                                    Text(city.country)
                                        .font(Theme.display(11))
                                        .foregroundStyle(Theme.inkFaint)
                                }
                                Spacer()
                                if !store.usesDeviceLocation, store.cityId == city.id {
                                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: loc("ابحث عن مدينة"))
            .navigationTitle(loc("الموقع"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("تم")) { dismiss() }
                }
            }
            .onChange(of: store.usesDeviceLocation) { _, uses in
                if uses {
                    WidgetCenter.shared.reloadAllTimelines()
                    dismiss()
                }
            }
        }
    }
}
