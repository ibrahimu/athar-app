import SwiftUI
import WidgetKit
import CoreLocation

struct PrayerView: View {
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false
    @EnvironmentObject private var store: AtharStore
    @StateObject private var location: LocationProvider
    @State private var now = Date()
    @State private var showCityPicker = false
    @Environment(\.layoutDirection) private var layoutDirection

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(embedded: Bool = false, store: AtharStore) {
        self.embedded = embedded
        _location = StateObject(wrappedValue: LocationProvider(store: store))
    }

    private var times: PrayerTimes? { store.prayerTimes(for: now) }

    /// Next prayer today, rolling over to tomorrow's Fajr after Isha.
    /// الشروق ليس صلاة فلا يُعرض هنا.
    private var upcoming: (prayer: Prayer, date: Date)? {
        if let next = times?.nextPrayer(after: now) { return next }
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let t = store.prayerTimes(for: tomorrow), let fajr = t[.fajr]
        else { return nil }
        return (.fajr, fajr)
    }

    var body: some View {
        MaybeStack(embedded: embedded) {
            ZStack {
                // الخلفية تُغسل بلون الصلاة القادمة كما في الرئيسية، فلا يهبط المستخدم من
                // شريط كهرمانيّ هناك إلى صفحة خضراء تحمل بطلًا كهرمانيًّا هنا.
                AtharBackground(tint: Theme.accent(for: upcoming?.prayer.accentKey ?? "green"), secondary: Theme.gold)
                    .animation(Motion.gentle, value: upcoming?.prayer)
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
                    .padding(.horizontal, Theme.gutter)
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
                            Text(store.placeName)
                                .font(Theme.display(13, weight: .medium))
                        }
                        .foregroundStyle(Theme.accent)
                    }
                    .tint(Theme.accent)
                }
            }
            .sheet(isPresented: $showCityPicker) {
                LocationPickerView(location: location)
                    .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
            }
        }
        .onReceive(ticker) { now = $0 }
    }

    // MARK: Countdown

    /// البطاقة البطلة: سطح البطاقة الموحّد مصبوغًا بلون الوقت (فيرث البريق العلوي
    /// والحدّ الشعري وصبغة السطح المعيارية كسائر البطاقات)، توهّج شعاعيّ خلف
    /// الأيقونة، وظلّ ملوّن يرفعها عن الورق. النص يبقى حِبرًا.
    @ViewBuilder
    private var countdownCard: some View {
        if let upcoming {
            let key = upcoming.prayer.accentKey
            let tint = Theme.accent(for: key)
            AtharCard(padding: 26, elevation: .e2, tint: tint, radius: Theme.Radius.xl) {
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
                .frame(maxWidth: .infinity)
            }
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

    /// حبّة العدّ التنازلي: كبسولة نظيفة بلون الوقت بحجم محتواها (بلا GeometryReader
    /// حتى لا تتمدّد الخلفية وتصنع شكلًا منتفخًا خلفها).
    private func countdownPill(next: Date, tint: Color, key: String) -> some View {
        HStack(spacing: 6) {
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
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.20), lineWidth: 0.5))
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
            // من اليسار (العشاء) إلى اليمين (الفجر): نيليّ ← ورديّ ← ذهبيّ ← كهرمانيّ
            let dayColors: [Color] = [
                Theme.accent(for: "night"),
                Theme.accent(for: "maghrib"),
                Theme.accent(for: "noon"),
                Theme.accent(for: "dawn")
            ]
            let dotColor = Theme.accent(for: (upcoming?.prayer ?? .isha).accentKey)
            AtharCard(padding: 16) {
                VStack(spacing: 10) {
                    // نثبّت اتجاه القوس إلى LTR حتى لا يزدوج قلب الإحداثيات مع RTL،
                    // ونضع الفجر يمينًا والعشاء يسارًا يدويًا (x = w·(1−f)).
                    GeometryReader { geo in
                        let w = geo.size.width
                        let midY = geo.size.height / 2
                        ZStack {
                            // المسار الخافت
                            Capsule().fill(Theme.hairline.opacity(0.6))
                                .frame(height: 6)

                            // التدرّج: العشاء (يسار) نيليّ … الفجر (يمين) كهرمانيّ
                            Capsule()
                                .fill(LinearGradient(colors: dayColors,
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(height: 6)
                                // يُكشف المنقضي من الفجر (يمين) نحو اليسار بمقدار nowFrac
                                .mask(alignment: .trailing) {
                                    Capsule().frame(width: max(6, w * nowFrac))
                                }

                            // ستّ علامات لكل وقت
                            ForEach(times.ordered, id: \.prayer) { entry in
                                let f = min(1, max(0, entry.date.timeIntervalSince(fajr) / span))
                                Circle()
                                    .fill(Theme.surface)
                                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                                    .frame(width: 5, height: 5)
                                    .position(x: w * (1 - f), y: midY)
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
                            .position(x: w * (1 - nowFrac), y: midY)
                        }
                        .animation(Motion.smooth, value: nowFrac)
                        .environment(\.layoutDirection, .leftToRight)
                    }
                    .frame(height: 16)

                    // العشاء يسارًا، الفجر يمينًا (نفس ترتيب القوس)
                    HStack {
                        Text(Prayer.isha.title)
                            .font(Theme.display(11, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                        Spacer()
                        Text(Prayer.fajr.title)
                            .font(Theme.display(11, weight: .medium))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
    }

    // MARK: List

    private var timesList: some View {
        // بطاقة الإعدادات الموحّدة (سطح + حدّ + ارتفاع e1) بدل سطح يدويّ بلا ارتفاع
        // كان القائمة المسطّحة الوحيدة بين بطل e2 وبطاقات e1.
        SettingsCard {
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
                        IconChip(icon: entry.prayer.icon, tint: rowTint, size: .sm)

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
                        SettingsDivider()
                    }
                }
            }
        }
    }

    /// رقاقة الصلاة القادمة: مستطيل مُدمج بتدرّج لون الوقت، حدّ شعريّ، وشريط
    /// لونيّ على الحافة البادئة — بديل الشريط الممتدّ عرض البطاقة.
    @ViewBuilder
    private func nextHighlight(_ tint: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        shape
            .fill(LinearGradient(colors: [tint.opacity(0.18), tint.opacity(0.06)],
                                 startPoint: .topTrailing, endPoint: .bottomLeading))
            .overlay(alignment: .leading) {
                Capsule().fill(tint).frame(width: 3).padding(.vertical, 9)
            }
            .overlay(shape.strokeBorder(tint.opacity(0.35), lineWidth: 1))
            .clipShape(shape)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
    }

    // MARK: Extras

    private var qiblaLink: some View {
        VStack(spacing: 10) {
            NavigationLink { QiblaView() } label: {
                AtharLinkRow(icon: "location.north.line.fill", tint: Theme.gold,
                             title: loc("اتجاه القبلة"), subtitle: qiblaSubtitle)
            }
            .pressable()
            NavigationLink { SunanView() } label: {
                AtharLinkRow(icon: "rays", tint: Theme.accent(for: "dawn"),
                             title: loc("السنن الرواتب"),
                             subtitle: loc("ما قبل كل فريضة وما بعدها، والوتر والضحى — بدليلها"))
            }
            .pressable()
        }
    }

    /// «الرياض · 244° نحو الجنوب الغربي» — بصيغة رقاقة المسافة في شاشة القبلة نفسها،
    /// لا «من الرياض» التي تقرأ الجهة موضعًا لا اتجاهًا.
    private var qiblaSubtitle: String {
        guard let b = Qibla.bearing(from: store.coordinate) else { return loc("أنت عند الكعبة") }
        return String(format: "%@ · %.0f° نحو %@", store.placeName, b, Qibla.compassName(for: b))
    }

    @ViewBuilder
    private var afterPrayerLink: some View {
        if let category = AdhkarLibrary.category(id: "prayer") {
            NavigationLink { DhikrSessionView(category: category) } label: {
                CategoryRow(category: category, completed: store.completedToday.contains(category.id))
                    // الصفّ يقرأ ألوان الطابع ساكنةً في جسمه ومدخلاته لا تتغيّر، فيتخطّاه
                    // SwiftUI عند تبديل الطابع أو توحيد الأيقونات؛ نعيد بناءه بمفتاح الطابع.
                    .id("\(store.appTheme)-\(store.unifyIcons)")
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
                        IconChip(icon: "moon.stars.fill", tint: Theme.accent(for: "night"), size: .md)
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
                        qiyamSlot(loc("الثلث الآخر"), q.lastThird)
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
            Text(label).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
            Text(Self.time(date, in: store.placeTimeZone))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    /// نافذة القيام تخصّ الليلة الجارية لا الليلة القادمة: قبل فجر اليوم نحن ما زلنا
    /// في ليلةٍ بدأت من مغرب أمس، فلو أسندناها إلى مغرب اليوم لما دخلها المستخدم أبدًا.
    private var qiyamWindow: (lastThird: Date, midnight: Date, end: Date)? {
        guard let t = times else { return nil }
        if let fajr = t[.fajr], now < fajr,
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now),
           let ty = store.prayerTimes(for: yesterday) {
            return ty.qiyam(tomorrowFajr: fajr)
        }
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
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
            IconChip(icon: icon, tint: tint, size: .sm)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .fill(Theme.surfaceAlt))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
            .strokeBorder(Theme.hairline.opacity(0.5), lineWidth: 0.5))
    }

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

    /// مدن بلد واحد تحت عنوانه.
    private struct CityGroup: Identifiable {
        let country: String
        let cities: [City]
        var id: String { country }
    }

    /// المدن مجمَّعة ببلدها بترتيب ورودها: يظهر اسم البلد عنوان مجموعة مرّة واحدة
    /// بدل أن يتكرّر سطرًا فرعيًا تحت سبع مدن سعودية متتالية.
    private var groups: [CityGroup] {
        var order: [String] = [], map: [String: [City]] = [:]
        for city in cities {
            if map[city.country] == nil { order.append(city.country) }
            map[city.country, default: []].append(city)
        }
        return order.map { CityGroup(country: $0, cities: map[$0] ?? []) }
    }

    var body: some View {
        NavigationStack {
            // كانت الورقة الوحيدة في التطبيق على List النظام (خلفية رمادية، خلايا بيضاء،
            // عنوان قسم نظامي)؛ صارت على ورق «أثر» وبطاقات الإعدادات كورقة اختيار القارئ.
            ZStack {
                AtharBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        deviceLocationCard
                        Text(loc("موقعك يُستخدم على جهازك فقط لحساب أوقات الصلاة، ولا يُرسل إلى أي جهة."))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)

                        ForEach(groups) { group in
                            VStack(spacing: 8) {
                                SettingsGroupTitle(text: group.country)
                                SettingsCard {
                                    ForEach(Array(group.cities.enumerated()), id: \.element.id) { i, city in
                                        cityRow(city)
                                        // الفاصل يبدأ حيث يبدأ النص بعد دائرة التحديد (١٧ نقطة)، لا بعد رقاقة أيقونة.
                                        if i < group.cities.count - 1 { SettingsDivider(inset: 46) }
                                    }
                                }
                            }
                        }

                        if groups.isEmpty, !query.isEmpty {
                            ContentUnavailableView.search(text: query)
                                .padding(.top, 30)
                        }
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                    .readableWidth(560)
                }
                .scrollIndicators(.hidden)
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

    /// «استخدام موقعي الحالي» بصفّ الإعدادات الموحّد، وتحته سبب التعذّر ومخرجه إن وُجد.
    private var deviceLocationCard: some View {
        SettingsCard {
            Button {
                location.request()
            } label: {
                SettingsRow(icon: "location.fill", title: loc("استخدام موقعي الحالي")) {
                    if location.isResolving {
                        ProgressView()
                    } else if store.usesDeviceLocation {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .buttonStyle(.plain)

            if location.failed {
                SettingsDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("تعذّر تحديد الموقع. تأكد من السماح للتطبيق بالوصول للموقع، أو اختر مدينتك يدويًا."))
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    // الرفض الصريح لا يُرفع إلا من إعدادات النظام، فنفتحها كما في مسار
                    // الإشعارات. (المقيَّد restricted لا يملك المستخدم تغييره، فيكفيه اختيار مدينة.)
                    if location.status == .denied {
                        Button(loc("فتح الإعدادات")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(Theme.display(13, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    /// صفّ مدينة كصفّ القارئ: دائرة تحديد بادئة والاسم وحده — البلد عنوان مجموعته.
    private func cityRow(_ city: City) -> some View {
        let on = !store.usesDeviceLocation && store.cityId == city.id
        return Button {
            store.setCity(city)
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(on ? Theme.accent : Theme.hairline)
                Text(city.name)
                    .font(Theme.display(15, weight: on ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 6)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
