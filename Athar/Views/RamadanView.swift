import SwiftUI

struct RamadanView: View {
    var isRootTab = false
    @EnvironmentObject private var store: AtharStore
    @Environment(\.colorScheme) private var scheme
    @State private var customizing = false
    private var preferences: RamadanPreferences { store.ramadanPreferences }
    private var tint: Color {
        guard preferences.followsAppTheme == false else { return Theme.accent }
        let p = preferences.color.palette.accent
        return Color(hex: scheme == .dark ? p.dark : p.light)
    }
    private var start: Date {
        preferences.start ?? RamadanCalendar.start(now: Date(), zone: store.placeTimeZone, offset: store.hijriOffset)
    }
    private var length: Int {
        preferences.length ?? RamadanCalendar.length(start: start, zone: store.placeTimeZone, offset: store.hijriOffset)
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                AtharCard(padding: 18, tint: tint) {
                    HStack(alignment: .top, spacing: 14) {
                        IconChip(icon: preferences.icon, tint: tint, size: .lg)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 7) {
                            Text("رمضان مع أثر")
                                .font(Theme.display(22, weight: .bold)).foregroundStyle(Theme.ink)
                            Text("للصيام والقيام ووردك اليومي")
                                .font(Theme.display(14)).foregroundStyle(Theme.inkSoft)
                            Label(store.placeName, systemImage: "location")
                                .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("يومك في رمضان")
                    .font(Theme.display(13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    .padding(.top, 8).padding(.horizontal, 4)
                ForEach(preferences.sections.filter { !preferences.hidden.contains($0) }) { section in
                    content(section)
                }
            }
            .padding(Theme.gutter).readableWidth(620)
        }
        .background {
            AtharBackground(tint: Theme.accent, motif: false)
                .overlay { PaperMotif(tint: Theme.accent, pattern: preferences.pattern).opacity(0.45).allowsHitTesting(false) }
        }
        .navigationTitle("رمضان")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .toolbar { ToolbarItem(placement: .primaryAction) {
            Button { customizing = true } label: { Image(systemName: "slider.horizontal.3") }
                .accessibilityLabel("تخصيص صفحة رمضان")
        } }
        .tint(tint)
        .environment(\.layoutDirection, .rightToLeft)
        .sheet(isPresented: $customizing) { RamadanCustomizationView().atharSheetChrome() }
    }

    @ViewBuilder private func content(_ section: RamadanSection) -> some View {
        switch section {
        case .timetable:
            NavigationLink { RamadanTimetableView(start: start, count: length) } label: {
                tile("إمساكية رمضان", detail: "\(store.placeName) · \(length) يومًا · الإمساك والفجر والإفطار", icon: "calendar")
            }.buttonStyle(.plain)
        case .qada:
            NavigationLink { FastingQadaView() } label: {
                tile("قضاء الصيام", detail: "الأيام المتبقية: \(store.fastingDaysOwed)", icon: "calendar.badge.clock")
            }.buttonStyle(.plain)
        case .readings:
            NavigationLink { ReadingPathsView() } label: {
                tile("قراءاتي", detail: "لكل ختمة ومراجعة موضعها المحفوظ", icon: "bookmark.fill")
            }.buttonStyle(.plain)
        case .qiyam:
            NavigationLink { QiyamReaderView() } label: {
                tile("مصحف القيام", detail: "المصحف كاملًا في 200 لوحة قراءة مكثّفة", icon: "book.pages.fill")
            }.buttonStyle(.plain)
        case .adhkar:
            NavigationLink { AdhkarIndexView(embedded: true) } label: {
                tile("أذكار اليوم", detail: "الصباح والمساء والأدعية من مصادرها", icon: "sparkles")
            }.buttonStyle(.plain)
        }
    }
    private func tile(_ title: String, detail: String, icon: String) -> some View {
        AtharCard(padding: 16) {
            HStack(spacing: 14) {
                IconChip(icon: icon, tint: tint, size: .lg)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(Theme.display(17, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(detail).font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

private struct RamadanCustomizationView: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    private func binding<T>(_ key: WritableKeyPath<RamadanPreferences, T>) -> Binding<T> {
        Binding(get: { store.ramadanPreferences[keyPath: key] }, set: { value in
            var p = store.ramadanPreferences; p[keyPath: key] = value; store.ramadanPreferences = p
        })
    }
    private var date: Binding<Date> {
        Binding(get: { store.ramadanPreferences.start ?? RamadanCalendar.start(now: Date(), zone: store.placeTimeZone, offset: store.hijriOffset) },
                set: { var p = store.ramadanPreferences; p.start = $0; store.ramadanPreferences = p })
    }
    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                dateSection
                cardsSection
            }
            .scrollContentBackground(.hidden)
            .background { AtharBackground(tint: Theme.accent) }
            .font(Theme.display(15))
            .foregroundStyle(Theme.ink)
            .tint(Theme.accent)
            .environment(\.defaultMinListRowHeight, 50)
            .environment(\.editMode, .constant(.active))
            .environment(\.timeZone, store.placeTimeZone)
            .environment(\.locale, Locale(identifier: "ar_SA"))
            .navigationTitle("رمضان على طريقتك")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("تم") { dismiss() } } }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    private var appearanceSection: some View {
                Section("الهوية الرمضانية") {
                    Toggle("استخدام لون التطبيق", isOn: Binding(
                        get: { store.ramadanPreferences.followsAppTheme != false },
                        set: { value in
                            var p = store.ramadanPreferences; p.followsAppTheme = value; store.ramadanPreferences = p
                        }
                    ))
                    if store.ramadanPreferences.followsAppTheme == false {
                        Picker("لون التفاصيل", selection: binding(\.color)) { ForEach(AppTheme.allCases) { Text($0.title).tag($0) } }
                    }
                    Picker("النقش", selection: binding(\.pattern)) { ForEach(BackgroundPattern.allCases) { Text($0.title).tag($0) } }
                    Picker("أيقونة القسم", selection: binding(\.icon)) {
                        ForEach(RamadanPreferences.icons, id: \.self) { Image(systemName: $0).tag($0) }
                    }
                }.listRowBackground(Theme.surface)
    }

    private var dateSection: some View {
                Section {
                    DatePicker("أول أيام رمضان", selection: date, displayedComponents: .date)
                    Picker("عدد الأيام", selection: binding(\.length)) {
                        Text("حسب التقويم").tag(Optional<Int>.none)
                        Text("29 يومًا").tag(Optional(29)); Text("30 يومًا").tag(Optional(30))
                    }
                    Button("العودة إلى التاريخ المحسوب") {
                        var p = store.ramadanPreferences; p.start = nil; p.length = nil; store.ramadanPreferences = p
                    }
                } header: { Text("بداية الشهر") } footer: {
                    Text("التاريخ المحسوب وفق أم القرى وضبط التاريخ الهجري. عدّله بما يوافق إعلان بلدك؛ أوقات الإمساكية تتبع المدينة وطريقة الحساب في إعدادات الصلاة.")
                }
                .listRowBackground(Theme.surface)
    }

    private var cardsSection: some View {
                Section("البطاقات — اسحب لترتيبها") {
                    ForEach(store.ramadanPreferences.sections) { section in
                        Toggle(section.title, isOn: Binding(get: { !store.ramadanPreferences.hidden.contains(section) }, set: { visible in
                            var p = store.ramadanPreferences
                            if visible { p.hidden.remove(section) } else { p.hidden.insert(section) }
                            store.ramadanPreferences = p
                        }))
                    }.onMove { from, to in
                        var p = store.ramadanPreferences; p.sections.move(fromOffsets: from, toOffset: to); store.ramadanPreferences = p
                    }.listRowBackground(Theme.surface)
                }
    }

}

struct FastingQadaView: View {
    @EnvironmentObject private var store: AtharStore
    @State private var lastValue: Int?
    var body: some View {
        Form {
            Section {
                Label("قضاء الصيام", systemImage: "calendar.badge.clock").font(Theme.display(22, weight: .bold))
                Text("الأيام المتبقية: \(store.fastingDaysOwed)").font(Theme.display(20))
                Stepper("عدد الأيام المتبقية", value: Binding(get: { store.fastingDaysOwed }, set: { store.fastingDaysOwed = $0; lastValue = nil }), in: 0...10000)
                Button("سجّل إتمام يوم قضاء") {
                    lastValue = store.fastingDaysOwed; store.fastingDaysOwed -= 1
                }.disabled(store.fastingDaysOwed == 0)
                if let lastValue {
                    Button("تراجع عن آخر تسجيل") { store.fastingDaysOwed = lastValue; self.lastValue = nil }
                }
            } footer: { Text("عدّاد شخصي؛ أدخل عدد الأيام المطلوب قضاؤها، ثم سجّل ما أتممته. لا يغيّر سجل الصلاة أو عدّادات رمضان الأخرى.") }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .background { AtharBackground(tint: Theme.accent) }
        .font(Theme.display(15)).foregroundStyle(Theme.ink).tint(Theme.accent)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("قضاء الصيام").environment(\.layoutDirection, .rightToLeft)
    }
}

struct RamadanTimetableView: View {
    let start: Date
    let count: Int
    @EnvironmentObject private var store: AtharStore
    private var days: [Date] { RamadanCalendar.dates(start: start, count: count, zone: store.placeTimeZone) }
    /// «8 فبراير 2027» — عربيًّا بأرقامٍ غربية كسائر تواريخ التطبيق. كان يخرج
    /// «8 Feb 2027» لأن `FormatStyle` بـ`ar_SA` وحدها تُبقي أسماء الأشهر بلسان
    /// النظام على المحاكي وتُخرج الأرقامَ هندية على جهازٍ عربيّ.
    private func gregorian(_ day: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = store.placeTimeZone
        f.dateFormat = "d MMMM yyyy"
        return f.string(from: day)
    }

    private func clock(_ date: Date?) -> String {
        guard let date else { return "غير متاح" }
        let f = DateFormatter(); f.locale = Locale(identifier: "ar_SA@numbers=latn"); f.timeZone = store.placeTimeZone; f.dateFormat = "h:mm a"
        return f.string(from: date)
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                Text(store.placeName).font(Theme.display(24, weight: .bold))
                Text("الإمساك هنا عند أذان الفجر. الإفطار عند المغرب. راجع ضبط المدينة والمواقيت، وطابق بداية الشهر مع الإعلان المحلي.")
                    .font(Theme.display(13)).foregroundStyle(Theme.inkSoft)
                NavigationLink("ضبط المدينة والمواقيت") { PrayerSettingsView() }
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    let times = store.prayerTimes(for: day)
                    AtharCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("\(index + 1) رمضان").font(Theme.display(17, weight: .bold))
                                Spacer()
                                Text(gregorian(day)).font(Theme.display(12))
                            }
                            ForEach([Prayer.fajr, .sunrise, .dhuhr, .asr, .maghrib, .isha], id: \.self) { prayer in
                                HStack {
                                    Text(prayer == .fajr ? "الفجر · الإمساك" : prayer == .maghrib ? "المغرب · الإفطار" : prayer.title)
                                    Spacer(); Text(clock(times?[prayer])).monospacedDigit()
                                }.font(Theme.display(14))
                            }
                        }
                    }
                }
            }.padding(Theme.gutter).readableWidth(620)
        }
        .background { AtharBackground(tint: Theme.accent) }
        .navigationTitle("إمساكية رمضان").navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, .rightToLeft).environment(\.timeZone, store.placeTimeZone)
    }
}
