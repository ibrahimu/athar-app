import SwiftUI
import WidgetKit

struct PrayerView: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var location: LocationProvider
    @State private var now = Date()
    @State private var showCityPicker = false

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
                        countdownCard
                        timesList
                        qiyamCard
                        highLatitudeNote
                        qiblaLink
                        afterPrayerLink
                        methodNote
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
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill").font(.system(size: 11))
                            Text(store.placeName).font(Theme.display(13, weight: .medium))
                        }
                    }
                }
            }
            .sheet(isPresented: $showCityPicker) {
                LocationPickerView(location: location)
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    // MARK: Countdown

    private var countdownCard: some View {
        AtharCard(padding: 22) {
            VStack(spacing: 14) {
                if let upcoming {
                    Text(loc("الصلاة القادمة"))
                        .font(Theme.display(13, weight: .medium))
                        .foregroundStyle(Theme.inkSoft)

                    HStack(spacing: 10) {
                        Image(systemName: upcoming.prayer.icon)
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.accent)
                        Text(upcoming.prayer.title)
                            .font(Theme.display(34, weight: .bold))
                            .foregroundStyle(Theme.ink)
                    }

                    Text(Self.time(upcoming.date, in: store.placeTimeZone))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)

                    Text(remaining(to: upcoming.date))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accentSoft))
                } else {
                    Text(loc("تعذّر حساب أوقات الصلاة لهذا الموقع"))
                        .font(Theme.display(15))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func remaining(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0
            ? String(format: loc("بعد %d:%02d:%02d"), h, m, s)
            : String(format: loc("بعد %d:%02d"), m, s)
    }

    // MARK: List

    private var timesList: some View {
        VStack(spacing: 0) {
            if let times {
                ForEach(Array(times.ordered.enumerated()), id: \.element.prayer) { index, entry in
                    let isNext = upcoming?.prayer == entry.prayer && entry.date > now
                    HStack(spacing: 12) {
                        Image(systemName: entry.prayer.icon)
                            .font(.system(size: 17))
                            .foregroundStyle(isNext ? Theme.accent : Theme.inkFaint)
                            .frame(width: 26)

                        Text(entry.prayer.title)
                            .font(Theme.display(17, weight: isNext ? .bold : .regular))
                            .foregroundStyle(entry.prayer.isPrayer ? Theme.ink : Theme.inkSoft)

                        Spacer()

                        Text(Self.time(entry.date, in: store.placeTimeZone))
                            .font(.system(size: 17, weight: isNext ? .bold : .regular, design: .rounded))
                            .foregroundStyle(isNext ? Theme.accent : Theme.inkSoft)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(isNext ? Theme.accentSoft : .clear)
                    .animation(Motion.smooth, value: isNext)

                    if index < times.ordered.count - 1 {
                        Divider().overlay(Theme.hairline).padding(.horizontal, 18)
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous).stroke(Theme.hairline))
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
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
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 2)
                Text(loc("في هذا الوقت من السنة لا تنزل الشمس إلى الزاوية المطلوبة في \(store.placeName)، فقُدِّر الفجر والعشاء بقاعدة سُبع الليل."))
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceAlt))
        }
    }

    private var methodNote: some View {
        VStack(spacing: 4) {
            Text(loc("طريقة الحساب: \(store.calculationMethod.title)"))
            Text(loc("الأوقات محسوبة على جهازك فلكيًا — قد تختلف دقائق عن مسجد حيّك."))
        }
        .font(Theme.display(11))
        .foregroundStyle(Theme.inkFaint)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
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
