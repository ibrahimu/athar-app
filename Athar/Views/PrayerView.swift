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
                        afterPrayerLink
                        methodNote
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 30)
                    .readableWidth()
                }
            }
            .navigationTitle("الصلاة")
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
                    Text("الصلاة القادمة")
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

                    Text(Self.clock.string(from: upcoming.date))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.accent)

                    Text(remaining(to: upcoming.date))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkSoft)
                        .monospacedDigit()
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Capsule().fill(Theme.accentSoft))
                } else {
                    Text("تعذّر حساب أوقات الصلاة لهذا الموقع")
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
            ? String(format: "بعد %d:%02d:%02d", h, m, s)
            : String(format: "بعد %d:%02d", m, s)
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

                        Text(Self.clock.string(from: entry.date))
                            .font(.system(size: 17, weight: isNext ? .bold : .regular, design: .rounded))
                            .foregroundStyle(isNext ? Theme.accent : Theme.inkSoft)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(isNext ? Theme.accentSoft : .clear)

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

    @ViewBuilder
    private var afterPrayerLink: some View {
        if let category = AdhkarLibrary.category(id: "prayer") {
            NavigationLink { DhikrSessionView(category: category) } label: {
                CategoryRow(category: category, completed: store.completedToday.contains(category.id))
            }
            .buttonStyle(.plain)
        }
    }

    private var methodNote: some View {
        VStack(spacing: 4) {
            Text("طريقة الحساب: \(store.calculationMethod.title)")
            Text("الأوقات محسوبة على جهازك فلكيًا — قد تختلف دقائق عن مسجد حيّك.")
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
                            Label("استخدام موقعي الحالي", systemImage: "location.fill")
                            Spacer()
                            if location.isResolving { ProgressView() }
                            else if store.usesDeviceLocation {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    if location.failed {
                        Text("تعذّر تحديد الموقع. تأكد من السماح للتطبيق بالوصول للموقع، أو اختر مدينتك يدويًا.")
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                } footer: {
                    Text("موقعك يُستخدم على جهازك فقط لحساب أوقات الصلاة، ولا يُرسل إلى أي جهة.")
                }

                Section("المدن") {
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
            .searchable(text: $query, prompt: "ابحث عن مدينة")
            .navigationTitle("الموقع")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("تم") { dismiss() }
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
