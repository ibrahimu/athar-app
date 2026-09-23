import SwiftUI
import WidgetKit
import CoreLocation

struct PrayerView: View {
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false
    @EnvironmentObject private var store: AtharStore
    @StateObject private var location: LocationProvider
    @State private var now = Date()
    /// الصلاةُ التي نقر عليها صاحبُها بعد أذانها ليرى كم مضى — لا الوقتَ وحده.
    /// من فتح الشاشة بعد العشاء يريد أن يعرف أهو في أوّل الوقت أم في آخره،
    /// و«7:57» لا تقول له ذلك، و«مضى على الأذان 13 دقيقة» تقوله.
    @State private var elapsedFor: Prayer?
    @State private var showCityPicker = false
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// النبضة تُبطل الشاشة كلها — البطل والقوس وقائمة المواقيت ونافذة القيام — فكانت تُعاد
    /// رسمًا ستّين مرة في الدقيقة من أجل سطرٍ واحد. العدّ التنازلي صار نصًّا يسوقه النظام
    /// بنفسه (Text(timerInterval:))، وما بقي تكفيه دقّة الدقيقة، فصارت النبضة دقيقة.
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

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

    /// الشاشةُ العريضة — اللوحُ، والهاتفُ المطويّ حين يُفتح. صنفُ الحجم لا
    /// اتجاهُ الشاشة: المطويُّ المفتوح قريبٌ من المربّع فلا «طوليّ» له ولا «عرضيّ».
    private var wide: Bool { sizeClass == .regular }

    var body: some View {
        MaybeStack(embedded: embedded) {
            ZStack {
                // الخلفية تُغسل بلون الصلاة القادمة كما في الرئيسية، فلا يهبط المستخدم من
                // شريط كهرمانيّ هناك إلى صفحة خضراء تحمل بطلًا كهرمانيًّا هنا.
                AtharBackground(tint: Theme.accent(for: upcoming?.prayer.accentKey ?? "green"), secondary: Theme.gold)
                    .animation(Motion.gentle, value: upcoming?.prayer)
                ScrollView {
                    VStack(spacing: 20) {
                        if store.timeZoneChangePending { travelBanner }
                        // الصدرُ يبقى عريضًا على كل شاشة: العدّادُ والقوسُ هما ما
                        // يُنظر إليه من بعيد، وقسمتُهما عمودين تصغّرهما بلا فائدة.
                        countdownCard.appearStagger(0)
                        dayArc.appearStagger(1)
                        if wide {
                            // اللوحُ المفتوح (والمطويُّ حين يُفتح): جدولُ اليوم في
                            // عمود، وما يتفرّع عنه في الآخر — فيُرى الجدولُ كاملًا
                            // بلا تمرير، وتُرى بقيّةُ الشاشة معه في نظرةٍ واحدة.
                            HStack(alignment: .top, spacing: 18) {
                                VStack(spacing: 20) {
                                    timesList.appearStagger(2)
                                    if store.travelMode { travelCard.appearStagger(2) }
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                                VStack(spacing: 20) {
                                    qiyamCard.appearStagger(3)
                                    secondCityCard.appearStagger(4)
                                    highLatitudeNote.appearStagger(4)
                                    qiblaLink.appearStagger(5)
                                    afterPrayerLink.appearStagger(6)
                                }
                                .frame(maxWidth: .infinity, alignment: .top)
                            }
                        } else {
                            timesList.appearStagger(2)
                            if store.travelMode { travelCard.appearStagger(2) }
                            qiyamCard.appearStagger(3)
                            secondCityCard.appearStagger(4)
                            highLatitudeNote.appearStagger(4)
                            qiblaLink.appearStagger(5)
                            afterPrayerLink.appearStagger(6)
                        }
                        methodNote.appearStagger(7)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 30)
                    .readableWidth(wide ? 1000 : 680)
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
                    .atharSheetChrome()
            }
        }
        .onReceive(ticker) { now = $0 }
        // الدقيقة لا تكفي لحظة الأذان: ننام إلى وقت الصلاة القادمة بعينه ثم نوقظ الشاشة،
        // فتنتقل إلى الصلاة التالية في حينها لا بعد دقيقةٍ من فواتها.
        .task(id: upcoming?.date) {
            guard let due = upcoming?.date else { return }
            let wait = due.timeIntervalSinceNow + 0.5
            guard wait > 0 else { return }
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            now = Date()
        }
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
            HStack(spacing: 4) {
                Text(loc("بعد"))
                // العدّ يسوقه النظام في موضعه بلا إبطال شجرة العرض — نسق النشاط الحيّ نفسه
                // في AtharWidget. وأخذ min احتياطًا: «الآن» تتأخّر عن وقت الصلاة بين
                // نبضتَي الدقيقة، ومدًى مقلوب الطرفين يُسقط التطبيق.
                Text(timerInterval: min(now, next)...next, countsDown: true)
                    .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
                    .monospacedDigit()
            }
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Capsule().fill(tint.opacity(0.12)))
        .overlay(Capsule().strokeBorder(tint.opacity(0.20), lineWidth: 0.5))
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
                    prayerRow(entry, isNext: isNext, tint: rowTint)

                    // نُخفي الفاصلين الملاصقين لرقاقة الصلاة القادمة لتبدو طليقة.
                    if index < ordered.count - 1, index != nextIdx, index + 1 != nextIdx {
                        SettingsDivider()
                    }
                }
            }
        }
    }

    /// صفُّ صلاةٍ واحد. مفصولٌ عن القائمة لأنّ المُترجِم يعجز عن تقدير نوع
    /// القائمة كلِّها في جسمٍ واحد بعد أن صار للصفّ حالتان.
    private func prayerRow(_ entry: (prayer: Prayer, date: Date), isNext: Bool, tint: Color) -> some View {
        let entered = entry.prayer.isPrayer && entry.date <= now
        let open = entered && elapsedFor == entry.prayer
        return HStack(spacing: 12) {
            IconChip(icon: entry.prayer.icon, tint: tint, size: .sm)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.prayer.title)
                    .font(Theme.display(17, weight: isNext ? .bold : .regular))
                    .foregroundStyle(entry.prayer.isPrayer ? Theme.ink : Theme.inkSoft)
                // في السفر وحده يُكتب العدد: في الحضر يعرفه كلُّ أحد، وذكرُه
                // يزحم الصفَّ بما لا يفيد. والجمعُ يُقال هنا لا في سطرٍ آخر.
                if store.travelMode, entry.prayer.isPrayer,
                   let rakaat = store.rakaatText(entry.prayer) {
                    Text(travelJoinNote(entry.prayer) ?? rakaat)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                        .lineLimit(1)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            // الوقتُ في موضعه هو الذي يتبدّل — «خلّ الشكل كذا»: لا صفٌّ يُفتح ولا
            // كبسولةٌ تُضاف، بل الرقمُ نفسُه يصير «مضى 13 دقيقة» ثمّ يعود.
            if open {
                // في موضع الوقت حبّةٌ بلغة حبّة العدّ التنازلي في البطاقة العليا:
                // كبسولةٌ بلون **الهويّة** (طابعُ التطبيق) لا بلون الصلاة — فتتّحد مع
                // بقيّة الواجهة ولا تصير كلُّ صلاةٍ حبّةً بلونٍ آخر — ورمزُ ساعةٍ تدور
                // بدل الرمل، ونصٌّ يتجدّد على رأس كل دقيقةٍ بالضبط. الصفُّ لا يتحرّك.
                let brand = Theme.accent
                TimelineView(.everyMinute) { ctx in
                    HStack(spacing: 5) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(brand)
                        Text(Self.elapsedText(since: entry.date, now: ctx.date))
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(brand.opacity(0.12)))
                    .overlay(Capsule().strokeBorder(brand.opacity(0.20), lineWidth: 0.5))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            } else {
                Text(Self.time(entry.date, in: store.placeTimeZone))
                    .font(.system(size: 17, weight: isNext ? .bold : .regular, design: .rounded))
                    .foregroundStyle(isNext ? tint : Theme.inkSoft)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background {
            if isNext { nextHighlight(tint) }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard entered else { return }
            withAnimation(Motion.snappy) {
                elapsedFor = elapsedFor == entry.prayer ? nil : entry.prayer
            }
            Haptics.tap(enabled: store.hapticsEnabled)
        }
        .accessibilityAddTraits(entered ? .isButton : [])
        .accessibilityHint(entered ? loc("انقر لمعرفة كم مضى على الأذان") : "")
        .animation(Motion.smooth, value: isNext)
    }

    /// «مضى 13 دقيقة» / «مضى ساعة و5 دقائق» — في موضع الوقت نفسِه، واسمُ الصلاة
    /// بجانبه يُغني عن «على الأذان». والعربيةُ تُفرد وتُثنّي وتجمع: «دقيقة»
    /// و«دقيقتان» و«7 دقائق» و«13 دقيقة» — فمن كتب «2 دقيقة» كتب لحنًا.
    /// والأرقامُ غربية كسائر أرقام الواجهة.
    static func elapsedText(since start: Date, now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)) / 60)
        let h = total / 60, m = total % 60
        func count(_ n: Int, one: String, two: String, few: String, many: String) -> String {
            switch n {
            case 1: return one
            case 2: return two
            case 3...10: return "\(n) " + few
            default: return "\(n) " + many
            }
        }
        let hours = count(h, one: loc("ساعة"), two: loc("ساعتان"), few: loc("ساعات"), many: loc("ساعة"))
        let mins = count(m, one: loc("دقيقة"), two: loc("دقيقتان"), few: loc("دقائق"), many: loc("دقيقة"))
        switch (h, m) {
        case (0, 0): return loc("الآن")
        case (0, _): return loc("مضى %1$@", mins)
        case (_, 0): return loc("مضى %1$@", hours)
        default:     return loc("مضى %1$@ و%2$@", hours, mins)
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

    // MARK: المسافر

    /// ما يُكتب تحت اسم الصلاة في السفر: «تُصلَّى مع الظهر» للمضمومة، و«الظهر
    /// والعصر جمعًا» للجامعة، وعددُ الركعات لما سواهما.
    private func travelJoinNote(_ prayer: Prayer) -> String? {
        let join = store.travelJoin
        if join.merged(into: prayer) {
            let with: Prayer = (prayer == .asr) ? .dhuhr : (prayer == .dhuhr ? .asr
                              : (prayer == .isha ? .maghrib : .isha))
            return loc("تُصلَّى مع %1$@", with.title)
        }
        if let pair = join.pair(at: prayer) {
            return loc("%1$@ و%2$@ — %3$@", pair.first.title, pair.second.title, join.title)
        }
        return nil
    }

    /// بطاقةُ السفر: تظهر ما دام الوضع مشتغلًا، تقول منذ متى ومن أين، وتُبدّل
    /// الجمع، وتُطفئ. ودليلُ القصر آيتُه تُحلّ من المصحف لا تُكتب هنا.
    private var travelCard: some View {
        AtharCard(padding: 16, elevation: .e2, tint: Theme.accent(for: "sea")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    IconChip(icon: "airplane", tint: Theme.accent(for: "sea"), size: .sm)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("وضع السفر"))
                            .font(Theme.display(15, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(travelSinceText)
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                    Button {
                        withAnimation(Motion.gentle) { store.travelMode = false }
                        Haptics.tap(enabled: store.hapticsEnabled)
                        Task { await Reminders.rescheduleAll(store: store) }
                    } label: {
                        Text(loc("انتهى سفري"))
                            .font(Theme.display(12, weight: .semibold))
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(Theme.surfaceAlt))
                    }
                    .buttonStyle(.plain)
                }

                // الجمع اختيارٌ ثلاثيّ صريح: بلا جمع (قصرٌ فقط)، أو تقديم، أو تأخير.
                Picker("", selection: Binding(
                    get: { store.travelJoin },
                    set: { value in
                        store.travelJoin = value
                        Haptics.tap(enabled: store.hapticsEnabled)
                        // النداء يتبع الاختيار في لحظته — لا عند الفتح التالي.
                        Task { await Reminders.rescheduleAll(store: store) }
                    })) {
                    ForEach(TravelJoin.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel(loc("الجمع في السفر"))

                Text(store.travelJoin.detail)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // الآية بمرجعها — نصّها من المصحف وعزوها من اسم سورته ورقمها.
                if let ayah = Quran.text(Travel.proof), let surah = Quran.surah(Travel.proof.surah) {
                    VStack(alignment: .leading, spacing: 4) {
                        // بلا قوسين مزخرفين: خطّ Noto Naskh المضمَّن لا يحوي ﴿ ﴾ فتظهر
                        // نقاطًا مشوّهة (وهي القاعدة نفسها في ورقة التفسير). اللونُ
                        // وخطُّ النسخ وسطرُ العزو تحتها تكفي لتمييزها آيةً.
                        Text(ayah)
                            .font(Theme.dhikrFont(size: 15, scale: store.fontScale))
                            .foregroundStyle(Theme.accent(for: "sea"))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(loc("سورة %1$@: %2$@", surah.name, Travel.proof.ayah.counterText))
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(Travel.disclaimer)
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// «منذ اليوم من الرياض» / «منذ 3 أيام من الرياض» — ومن نسيه شهرًا يراه مكتوبًا.
    private var travelSinceText: String {
        let days = store.travelDays
        let since = days == 0 ? loc("منذ اليوم") : (days == 1 ? loc("منذ أمس")
                     : loc("منذ %1$@ أيام", days.counterText))
        guard let place = store.travelPlace, !place.isEmpty else { return since }
        return loc("%1$@ · من %2$@", since, place)
    }

    /// تغيّرت منطقة الجهاز الزمنية: نسأل قبل أن نبدّل المواقيت بصمت.
    private var travelBanner: some View {
        AtharCard(padding: 14, tint: Theme.accent(for: "gold")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    IconChip(icon: "airplane", tint: Theme.accent(for: "gold"), size: .sm)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("يبدو أنك في بلدٍ آخر")).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text(loc("تغيّرت المنطقة الزمنية. أنحدّث موقعك لتُضبط المواقيت؟")).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(spacing: 8) {
                    Button {
                        // اللافتة لا تُسقَط قبل أن يُعرف الجواب: كانت تختفي فورًا فيظنّ
                        // المسافر أنّ موقعه حُدِّث، والإذنُ قد يكون مرفوضًا فلا يُطلب
                        // ولا يُقال — ويضيع الطريق الوحيد الذي عُرض عليه.
                        location.request()
                        Haptics.tap(enabled: store.hapticsEnabled)
                    } label: {
                        Text(loc("حدّث موقعي")).font(Theme.display(13, weight: .semibold)).frame(maxWidth: .infinity)
                            .softButton(Theme.accent(for: "gold"))
                    }
                    .pressable()
                    .disabled(location.isResolving)
                    // وبابٌ ثانٍ: من بدّل منطقته فهو مسافرٌ في الغالب، وحاجتُه إلى
                    // القصر والجمع قبل حاجته إلى ضبط دقيقتين. ولا يُشغَّل من نفسه:
                    // الضغطةُ ضغطتُه، فالتطبيق لا يحكم على أحد بأنّه مسافر.
                    Button {
                        withAnimation(Motion.gentle) {
                            store.travelMode = true
                            store.timeZoneChangePending = false
                        }
                        Haptics.tap(enabled: store.hapticsEnabled)
                        Task { await Reminders.rescheduleAll(store: store) }
                    } label: {
                        Text(loc("أنا مسافر")).font(Theme.display(13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .background(Capsule().fill(Theme.surfaceAlt))
                    }
                    .buttonStyle(.plain)
                    Button {
                        store.timeZoneChangePending = false
                    } label: {
                        Text(loc("لاحقًا")).font(Theme.display(13, weight: .semibold)).foregroundStyle(Theme.inkFaint)
                            .padding(.horizontal, 10).padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }

                // تعذّر تحديد الموقع: يُقال ويُفتح له بابان — إعدادات الجهاز لمن رُفض
                // إذنُه، ومنتقي المدن لمن لا يريد الإذن أصلًا. وبلا هذا كان الرفض
                // يُبتلع صامتًا واللافتة تختفي كأن الموقع حُدِّث.
                if location.failed {
                    Divider().background(Theme.hairline)
                    Text(loc("تعذّر تحديد موقعك."))
                        .font(Theme.display(12)).foregroundStyle(Theme.danger)
                    HStack(spacing: 8) {
                        if location.status == .denied || location.status == .restricted {
                            Button(loc("فتح الإعدادات")) {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(Theme.display(13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                        }
                        Button(loc("اختر مدينتك")) { showCityPicker = true }
                            .font(Theme.display(13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
        }
        // بلغ الموقعُ مبلغَه: اللافتة تنقضي بنجاحها لا بضغطة زرّها.
        .onChange(of: store.placeName) { _, _ in store.timeZoneChangePending = false }
    }

    // MARK: مدينة ثانية

    @State private var showSecondPicker = false

    /// مواقيت مدينة أخرى للمسافر أو لأهلٍ في بلد آخر — بتوقيت تلك المدينة.
    private var secondCityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let city = store.secondaryCity, let t = store.secondaryPrayerTimes(for: now) {
                SectionHeader(title: loc("مدينة أخرى"), tint: Theme.accent(for: "sea"),
                              action: { showSecondPicker = true }, actionTitle: loc("تغيير"))
                AtharCard(padding: 14, tint: Theme.accent(for: "sea")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            IconChip(icon: "globe.asia.australia.fill", tint: Theme.accent(for: "sea"), size: .sm)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(city.name).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text("\(city.country) · \(secondClock(now, tz: city.tz))")
                                    .font(Theme.display(11)).foregroundStyle(Theme.inkFaint).monospacedDigit()
                            }
                            Spacer()
                            Button { withAnimation(Motion.snappy) { store.secondaryCity = nil } } label: {
                                Image(systemName: "xmark.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.inkFaint)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(loc("إزالة المدينة الثانية"))
                        }
                        HStack(spacing: 0) {
                            ForEach(Prayer.allCases.filter(\.isPrayer)) { p in
                                VStack(spacing: 3) {
                                    Text(p.title).font(Theme.display(11)).foregroundStyle(Theme.inkSoft)
                                    Text(t[p].map { secondClock($0, tz: city.tz) } ?? "—")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.ink).monospacedDigit()
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            } else {
                Button { showSecondPicker = true } label: {
                    AtharLinkRow(icon: "globe.asia.australia.fill", tint: Theme.accent(for: "sea"),
                                 title: loc("مدينة أخرى"),
                                 subtitle: loc("مواقيت بلدٍ ثانٍ لمسافر أو لأهلك — بتوقيته"))
                }
                .pressable()
            }
        }
        .sheet(isPresented: $showSecondPicker) {
            LocationPickerView(location: location, secondary: true, onPick: { store.secondaryCity = $0 })
                .atharSheetChrome()
        }
    }

    private func secondClock(_ d: Date, tz: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = TimeZone(identifier: tz) ?? .current
        // بعلامة الفترة كبقيّة الشاشة: بطاقةٌ وُضعت لمعرفة وقت بلدٍ آخر لا تُخفي
        // نصفَ الخبر — «9:30» لا يُدرى أصباحٌ هو أم مساء.
        f.dateFormat = "h:mm a"
        return f.string(from: d)
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
                    .id("\(store.effectiveTheme)-\(store.unifyIcons)")
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

                    // نصٌّ شرعي: يُعرض بخطّ النسخ لا بخطّ الواجهة المختار، كما في سائر
                    // التطبيق — وكان يتبع اختيار المستخدم فيُقرأ بـ«ثمانية» أو خطّ النظام،
                    // بحجمٍ صغير وحبرٍ خافت. ولم يُمسّ منه حرف: ليس في hadith.json ليُحلّ
                    // بمعرّفه، ولا يُكتب نصٌّ شرعي من غير بياناته.
                    Text("«ينزل ربنا إلى السماء الدنيا حين يبقى ثلث الليل الآخر» — متفق عليه")
                        .font(Theme.naskhFont(size: 13, scale: store.fontScale))
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
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
    /// حين يكون الاختيار للمدينة الثانية لا لمكان المستخدم: بلا بطاقة الموقع، والتحديد يعود عبر onPick.
    var secondary: Bool = false
    var onPick: ((City) -> Void)? = nil

    private var cities: [City] {
        // بمفتاح البحث الموحّد: من كتب «الاحساء» أو «الهفوف» أو «احسا» وجدها.
        let needle = query.searchKey
        guard !needle.isEmpty else { return City.all }
        return City.all.filter {
            $0.name.searchKey.contains(needle) || $0.country.searchKey.contains(needle)
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
                        if !secondary { deviceLocationCard }
                        // الوعد يطابق ما يفعله الكود: CLGeocoder نداءٌ شبكيّ يحمل الإحداثيات إلى Apple
                        // لاستخراج اسم المدينة وحده — والحساب نفسه على الجهاز.
                        Text(loc("المواقيت تُحسب على جهازك ولا تُرسل إلى خادم لنا. ولاستخراج اسم مدينتك وحده يُسلَّم الموقع إلى خدمة الخرائط في Apple."))
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
            // من كان على موقع الجهاز أصلًا لا يتبدّل العلَم عنده، فلا يُغلَق شيء ولا
            // يظهر أثرٌ لضغطته — فيضغط ثانيةً وثالثة وهي قد عملت. فالإغلاق يتبع
            // وصولَ اسم مكانٍ جديد أيضًا.
            .onChange(of: store.placeName) { _, _ in
                if store.usesDeviceLocation {
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
        let on = secondary ? store.secondaryCity?.id == city.id : (!store.usesDeviceLocation && store.cityId == city.id)
        return Button {
            if secondary {
                onPick?(city)
            } else {
                store.setCity(city)
                WidgetCenter.shared.reloadAllTimelines()
            }
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    // hairline يكاد يختفي على الورق الفاتح (تباين ١٫٣:١)، فتبدو
                    // صفوفُ المدن نصًّا لا خيارًا — كما عولج في سائر قوائم الاختيار.
                    .foregroundStyle(on ? Theme.accent : Theme.inkFaint)
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
