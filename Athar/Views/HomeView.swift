import SwiftUI

struct HomeView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var store: AtharStore
    var onOpenTab: (AppTab) -> Void
    /// حين تُفتح من شاشة «الأقسام» تكون داخل مكدّس قائم، فلا تصنع مكدّسًا آخر.
    var embedded = false

    @State private var now = Date()
    /// «الجمعة» شاشةٌ تُدفع من هنا، فرابطُ athar://open/friday يصل إليها عبر «اليوم».
    @State private var openFriday = false
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var suggested: DhikrCategory? {
        AdhkarLibrary.category(id: DhikrCategory.suggestedNow(date: now))
    }

    private var dailyDhikr: Dhikr? {
        let pool = AdhkarLibrary.shortItems
        guard !pool.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: now) ?? 0
        return pool[day % pool.count]
    }

    var body: some View {
        MaybeStack(embedded: embedded) {
            ZStack {
                AtharBackground(tint: dayTint, secondary: Theme.gold)
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header.appearStagger(0)
                        // «اليوم على كيفي»: البطاقات وترتيبها من اختيار المستخدم (المظهر ← بطاقات اليوم).
                        ForEach(Array(store.homeCards.enumerated()), id: \.element) { i, card in
                            homeCard(card).appearStagger(i + 1)
                        }
                        footerNote.appearStagger(store.homeCards.count + 1)
                    }
                    .padding(.horizontal, Theme.gutter)
                    .padding(.bottom, 32)
                    .readableWidth()
                }
            }
            // طلب الرابط قد يسبق ظهور الشاشة (إقلاع بارد) وقد يأتي وهي قائمة — يُستهلك في الحالين.
            .navigationDestination(isPresented: $openFriday) { FridayView() }
            .onAppear { consumeFridayRequest() }
            .onChange(of: store.pendingFriday) { _, _ in consumeFridayRequest() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(loc("أثر")).font(Theme.display(18, weight: .bold)).foregroundStyle(Theme.ink)
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { SettingsSheet() } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel(loc("settings"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // تُمرَّر onOpenTab كي تبدّل «الأقسام» التبويبَ الحيّ بدل دفع نسخة ثانية منه.
                    NavigationLink { SectionsView(onOpenTab: onOpenTab) } label: {
                        Image(systemName: "square.grid.2x2.fill")
                    }
                    .accessibilityLabel(loc("الأقسام"))
                }
            }
        }
        .onReceive(ticker) { now = $0 }
        // ولا إعادة تحميل للودجات هنا: الجذر (AtharApp) يعيدها عند الانتقال إلى الخلفية —
        // وهي اللحظة التي تُرى فيها الودجات — فكان نداؤها مع كل ظهورٍ لـ«اليوم» تكرارًا
        // يوقظ إضافة الودجة مع كل تبديل تبويب ورجوعٍ من قسم.
    }

    /// يُستهلك الطلب مرّة واحدة ثم يُخفض علَمُه، وإلا أُعيد فتح «الجمعة» مع كل
    /// رجوعٍ إلى «اليوم» ما بقي التطبيق حيًّا.
    private func consumeFridayRequest() {
        guard store.pendingFriday else { return }
        store.pendingFriday = false
        openFriday = true
    }

    // MARK: بطاقات اليوم

    @ViewBuilder
    private func homeCard(_ card: HomeCard) -> some View {
        switch card {
        case .prayer:      prayerStrip
        case .radio:       radioStrip
        case .continueReading: continueReadingCard
        case .stats:       statsRow
        case .suggestion:  if let suggested { suggestionCard(suggested) }
        case .dailyDhikr:  if let dailyDhikr { dailyCard(dailyDhikr) }
        case .dailyHadith: if let h = HadithLibrary.daily(for: now) { hadithCard(h) }
        case .occasion:    if let next = Occasions.upcoming(from: now, limit: 1).first { occasionCard(next) }
        case .friday:      if Calendar.current.component(.weekday, from: now) == 6 { fridayCard }
        case .ramadan:     if Occasions.hijriComponents(now).month == 9 { ramadanCard }
        case .quickGrid:   quickGrid
        case .sections:    moreSections
        case .sadaqah:     sadaqahCard
        }
    }

    // MARK: تابع القراءة

    /// موضع القارئ من المصحف: علامة «وقوفي» إن وضعها بيده — فهي أوثق من التصفّح —
    /// وإلا آخر موضع بلغه. ومن لم يفتح المصحف بعد فلا بطاقة له تُذكّره بلا شيء.
    @ViewBuilder
    private var continueReadingCard: some View {
        if let ref = store.stopMark ?? store.lastRead, let surah = Quran.surah(ref.surah) {
            let marked = store.stopMark != nil
            // ذهبيّة كبطاقة «وقوفي» في المصحف، وبلون الطابع حين تكون متابعةً تلقائية —
            // فيعرف القارئ من اللون أوضعها بيده أم بلغها التطبيق عنه.
            let card = marked ? Theme.accent(for: "gold") : Theme.accent
            let glyph = marked ? Theme.gold : Theme.accent
            NavigationLink { SurahReaderView(surahId: ref.surah, scrollTo: ref) } label: {
                AtharCard(padding: 16, elevation: .e2, tint: card) {
                    HStack(spacing: 14) {
                        IconChip(icon: marked ? "pin.fill" : "book.pages.fill", tint: glyph, size: .lg)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(marked ? loc("myStop") : loc("continueReading"))
                                .font(Theme.display(12, weight: .semibold))
                                .foregroundStyle(glyph)
                            Text(loc("سورة %1$@ · ص %2$@ · الجزء %3$@", surah.name,
                                     Quran.page(of: ref).counterText, Quran.juz(of: ref).counterText))
                                .font(Theme.display(16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
            .pressable()
        }
    }

    /// حديث اليوم — من الصحيحين فقط، بعزو النووي، ويفتح تمامه في قسم الحديث.
    private func hadithCard(_ h: Hadith) -> some View {
        let color = Theme.accent(for: "sea")
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("حديث اليوم"), tint: color)
            NavigationLink { HadithDetailView(hadith: h) } label: {
                AtharCard(padding: 18, elevation: .e2, tint: color) {
                    VStack(alignment: .leading, spacing: 12) {
                        Capsule().fill(color.opacity(0.7)).frame(width: 40, height: 3)
                        Text(h.text)
                            .font(Theme.dhikrFont(size: 17))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(7)
                            .lineLimit(6)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text(h.citation)
                                .font(Theme.display(11))
                                .foregroundStyle(Theme.inkFaint)
                                .lineLimit(1)
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(color)
                        }
                    }
                }
            }
            .pressable()
        }
    }

    /// المناسبة القادمة أو الجارية من مناسبات السنّة، وعدّها التنازلي.
    private func occasionCard(_ next: (occasion: HijriOccasion, start: Date, end: Date)) -> some View {
        let o = next.occasion
        let color = Theme.accent(for: o.accent)
        let days = Occasions.daysUntil(next.start, from: now)
        let when: String = days <= 0 ? loc("جارية الآن")
            : days == 1 ? loc("غدًا")
            : days == 2 ? loc("بعد يومين")
            : days <= 10 ? loc("بعد %1$@ أيام", days.counterText)
            : loc("بعد %1$@ يومًا", days.counterText)
        return NavigationLink { HijriCalendarView() } label: {
            AtharCard(padding: 14, tint: color) {
                HStack(spacing: 12) {
                    IconChip(icon: o.icon, tint: color, size: .lg)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(o.title).font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text("\(when) · \(o.day.counterText) \(o.isMonthly ? loc("من كل شهر") : Occasions.monthName(o.month))")
                            .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    // MARK: الجمعة ورمضان

    /// يوم الجمعة: بابٌ واحد إلى شاشتها، وفيه حصيلةُ سننها وحال الكهف من الدفتر —
    /// كانت هنا قائمةُ سننٍ صمّاء لا تُعلَّم ولا تُتبَع، فصارت السنن تُعمل هناك.
    private var fridayCard: some View {
        let color = Theme.accent(for: "gold")
        let read = store.ledger(for: now).kahf
        let p = store.fridayProgress
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("جمعة مباركة"), tint: color)
            NavigationLink { FridayView() } label: {
                AtharCard(padding: 16, elevation: .e2, tint: color) {
                    HStack(spacing: 14) {
                        ZStack {
                            ProgressRing(progress: p.fraction, color: color, lineWidth: 3, gradient: true)
                                .frame(width: 46, height: 46)
                            Image(systemName: p.isComplete ? "checkmark" : "sun.max.fill")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(color)
                        }
                        .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(loc("%1$@ من %2$@ من سنن اليوم", p.done.counterText, p.total.counterText))
                                .font(Theme.display(16, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            Text(read ? loc("قرأت الكهف اليوم") : loc("سورة الكهف تنتظرك"))
                                .font(Theme.display(12))
                                .foregroundStyle(Theme.inkSoft)
                        }
                        Spacer(minLength: 6)
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(color)
                    }
                }
            }
            .pressable()
        }
    }

    /// رمضان: الإمساك والإفطار بعدّ تنازلي، ودعاء الإفطار، وخطة الختمة.
    private var ramadanCard: some View {
        let color = Theme.accent(for: "dusk")
        let t = store.prayerTimes(for: now)
        let fajr = t?[.fajr], maghrib = t?[.maghrib]
        let target: (label: String, date: Date)? = {
            if let m = maghrib, m > now { return (loc("الإفطار"), m) }
            if let f = fajr, f > now { return (loc("الإمساك"), f) }
            return nil
        }()
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("رمضان كريم"), tint: color)
            AtharCard(padding: 16, elevation: .e2, tint: color) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 0) {
                        VStack(spacing: 3) {
                            Text(loc("الإمساك")).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                            Text(fajr.map(clockText) ?? "—").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Theme.ink).monospacedDigit()
                        }.frame(maxWidth: .infinity)
                        Rectangle().fill(Theme.hairline).frame(width: 1, height: 36)
                        VStack(spacing: 3) {
                            Text(loc("الإفطار")).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                            Text(maghrib.map(clockText) ?? "—").font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(color).monospacedDigit()
                        }.frame(maxWidth: .infinity)
                    }
                    if let target {
                        HStack(spacing: 6) {
                            Image(systemName: "timer").font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                            Text(loc("%1$@ بعد", target.label)).font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                            Text(timerInterval: now...target.date, countsDown: true)
                                .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(Theme.ink)
                                .environment(\.locale, Locale(identifier: "ar_SA@numbers=latn"))
                        }
                    }
                    SettingsDivider(inset: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc("دعاء الإفطار")).font(Theme.display(12, weight: .semibold)).foregroundStyle(color)
                        Text("ذَهَبَ الظَّمَأُ وَابْتَلَّتِ الْعُرُوقُ وَثَبَتَ الأَجْرُ إِنْ شَاءَ اللَّهُ")
                            .font(Theme.dhikrFont(size: 17)).foregroundStyle(Theme.ink).lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(loc("رواه أبو داود")).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                    }
                    NavigationLink { KhatmahView() } label: {
                        HStack(spacing: 10) {
                            IconChip(icon: "books.vertical.fill", tint: color, size: .sm)
                            Text(store.khatmahActive ? loc("ختمتك جارية — تابع") : loc("ابدأ ختمة رمضان: جزء كل يوم"))
                                .font(Theme.display(14, weight: .semibold)).foregroundStyle(Theme.ink)
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func clockText(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.timeZone = store.placeTimeZone
        f.dateFormat = "h:mm"
        return f.string(from: d)
    }

    // MARK: Header

    /// لون اليوم — يتبدّل مع الصلاة القادمة (فجر كهرماني ← عشاء نيليّ).
    private var dayTint: Color {
        Theme.accent(for: upcomingPrayer?.prayer.accentKey ?? "green")
    }

    private var timeSymbol: String {
        switch Calendar.current.component(.hour, from: now) {
        case 4..<12:  return "sun.max.fill"
        case 12..<17: return "sun.min.fill"
        case 17..<20: return "sunset.fill"
        default:      return "moon.stars.fill"
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(greeting)
                .font(Theme.display(28, weight: .bold))
                .foregroundStyle(LinearGradient(colors: [Theme.ink, Theme.inkSoft],
                                                startPoint: .top, endPoint: .bottom))
            HStack(spacing: 6) {
                Image(systemName: timeSymbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(dayTint)
                Text(hijriDate)
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(Theme.surfaceAlt))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 10)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 4..<12:  return loc("goodMorning")
        case 12..<17: return loc("goodDay")
        case 17..<21: return loc("goodEvening")
        default:      return loc("goodNight")
        }
    }

    private var hijriDate: String {
        // أرقام لاتينية كبقية أرقام التطبيق — الأرقام الهندية ٠ تُقرأ نقطةً عند العرض.
        // ويُركَّب السطر تركيبًا ولا يُترك لمنسّقٍ واحد: ضبط المطالع يزيح اليومَ الهجري
        // وحده، ولو أُزيح التاريخ كلّه لسُمّي اليومُ باسم يومٍ لم يأتِ بعد.
        let c = Occasions.hijriComponents(now)
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "ar_SA@numbers=latn")
        f.dateFormat = "EEEE"
        return "\(f.string(from: now))، \(c.day.counterText) \(Occasions.monthName(c.month)) \(String(c.year)) هـ"
    }

    // MARK: Next prayer

    /// الشروق ليس صلاة فيُتخطّى — وإلا صبغ لونُه اليومَ وملأ الحلقة صباحًا كل يوم.
    private var upcomingPrayer: (prayer: Prayer, date: Date)? {
        if let next = store.prayerTimes(for: now)?.nextPrayer(after: now) { return next }
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now),
              let t = store.prayerTimes(for: tomorrow), let fajr = t[.fajr]
        else { return nil }
        return (.fajr, fajr)
    }

    /// نسبة انقضاء الوقت بين الصلاة السابقة والقادمة — تملأ حلقة حيّة.
    private var prayerArc: Double {
        guard let up = upcomingPrayer else { return 0 }
        let next = up.date
        let prev: Date
        if let times = store.prayerTimes(for: now),
           let earlier = Prayer.allCases.filter({ $0.isPrayer })
               .compactMap({ times[$0] }).filter({ $0 <= now }).max() {
            prev = earlier
        } else {
            prev = next.addingTimeInterval(-6 * 3600)
        }
        let total = next.timeIntervalSince(prev)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(prev) / total))
    }

    @ViewBuilder
    private var prayerStrip: some View {
        if let upcoming = upcomingPrayer {
            // تبويب الصلاة قد يُخفى من الشريط؛ عندها يُدفع القسم في المكدّس نفسه
            // كبلاطات «أقسام أخرى»، لا كورقة بلا زرّ إغلاق.
            if store.visibleTabs.contains(.prayer) {
                Button { onOpenTab(.prayer) } label: { prayerCard(upcoming) }
                    .pressable()
            } else {
                NavigationLink { SectionDestination(tab: .prayer) } label: { prayerCard(upcoming) }
                    .pressable()
            }
        }
    }

    private func prayerCard(_ upcoming: (prayer: Prayer, date: Date)) -> some View {
        let pcolor = Theme.accent(for: upcoming.prayer.accentKey)
        return AtharCard(padding: 14, elevation: .e2, tint: pcolor) {
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: prayerArc, color: pcolor, lineWidth: 3, gradient: true)
                        .frame(width: 46, height: 46)
                    Image(systemName: upcoming.prayer.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(pcolor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(upcoming.prayer.title)
                        .font(Theme.display(17, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text(store.placeName)
                        .font(Theme.display(11))
                        .foregroundStyle(Theme.inkFaint)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(PrayerView.time(upcoming.date, in: store.placeTimeZone))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [pcolor, pcolor.opacity(0.7)],
                                                        startPoint: .top, endPoint: .bottom))
                    Text(countdown(to: upcoming.date))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.inkFaint)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: الإذاعة

    /// بطاقة الإذاعة: طرفها القائد يفتح القسم (تبويبًا إن كان في الشريط، وإلا دُفع في المكدّس
    /// كبطاقة الصلاة)، وزرّها الطرفي يشغّل ويوقف من غير مغادرة «اليوم». مراقبة المشغّل محصورة
    /// في البطاقة نفسها كي لا تُعاد «اليوم» كلها مع كل تغيّر في حالة البثّ.
    private var radioStrip: some View {
        HomeRadioCard(tint: Theme.accent(for: "sea"), live: Theme.danger,
                      inBar: store.visibleTabs.contains(.radio)) { onOpenTab(.radio) }
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(now)))
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? loc("بعد %1$@ س %2$@ د", h.counterText, m.counterText) : loc("بعد %1$@ د", m.counterText)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: store.displayStreak.counterText,
                     label: loc("statStreak"),
                     icon: "flame.fill",
                     color: Theme.accent2)
            statTile(value: store.totalDhikrCount.counterText,
                     label: loc("statTotal"),
                     icon: "infinity",
                     color: Theme.accent)
        }
    }

    private func statTile(value: String, label: String, icon: String, color: Color) -> some View {
        // صبغة بلون الطابع لتتّسق مع بقية البطاقات (لا تبقى دافئة/صفراء).
        AtharCard(padding: 14, tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .background(
                            Circle().fill(color.opacity(0.2)).frame(width: 26, height: 26).blur(radius: 7)
                        )
                    Text(label).font(Theme.display(12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(color)

                Text(value)
                    .font(Theme.display(30, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [color, color.opacity(0.7)],
                                                    startPoint: .top, endPoint: .bottom))
                    .contentTransition(.numericText())
            }
        }
    }

    // MARK: Suggestion

    private func suggestionCard(_ category: DhikrCategory) -> some View {
        let color = Theme.accent(for: category.accent)
        let done = store.completedToday.contains(category.id)
        return NavigationLink {
            DhikrSessionView(category: category)
        } label: {
            AtharCard(padding: 18, elevation: .e2, tint: color) {
                VStack(alignment: .leading, spacing: 12) {
                    // الشارة وحدها في الصفّ العلوي — سهم «arrow.forward» الذي كان يطفو
                    // في زاويتها استُبدل بسهم صغير في طرف صفّ العنوان كبقيّة بطاقات التنقّل.
                    HStack {
                        if done {
                            Label(loc("أتممتها اليوم"), systemImage: "checkmark.seal.fill")
                                .font(Theme.display(12, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .padding(.horizontal, 11).padding(.vertical, 5)
                                .background(Capsule().fill(Theme.gradient(for: "gold")))
                        } else {
                            Text(loc("وقتها الآن"))
                                .font(Theme.display(12, weight: .bold))
                                .foregroundStyle(color)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .background(Capsule().fill(color.opacity(0.14)))
                        }
                    }

                    HStack(alignment: .center, spacing: 14) {
                        // الرقاقة في الطرف البادئ كسائر بطاقات التطبيق (بطاقة الصلاة، البلاطات،
                        // صدقة اليوم)، فلا تقفز الأيقونة من حافة إلى أخرى أثناء التمرير.
                        IconChip(icon: category.icon, tint: color, size: .lg)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title)
                                .font(Theme.display(23, weight: .bold))
                                .foregroundStyle(Theme.ink)
                            Text(category.subtitle)
                                .font(Theme.display(13))
                                .foregroundStyle(Theme.inkSoft)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.forward")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
        }
        .pressable()
    }

    // MARK: Daily dhikr

    private func dailyCard(_ dhikr: Dhikr) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: loc("dhikrOfDay"), tint: Theme.accent(for: "gold"))
            AtharCard {
                VStack(alignment: .leading, spacing: 12) {
                    // خيط ذهبي علوي — كحاشية المصحف المذهّبة
                    Capsule().fill(Theme.goldGradient)
                        .frame(width: 46, height: 3)
                        .opacity(0.7)

                    Text(dhikr.text)
                        .font(Theme.dhikrFont(size: 20, scale: store.fontScale))
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(10)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if dhikr.hasReference {
                        Text(dhikr.reference)
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkFaint)
                    }

                    ShareLink(item: dhikr.text + (dhikr.hasReference ? "\n\n\(dhikr.reference)" : "") + "\n\nمن تطبيق أثر") {
                        Label(loc("انشر الأجر"), systemImage: "square.and.arrow.up")
                            .font(Theme.display(13, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(Theme.accent.opacity(0.13)))
                    }
                    .pressable()
                }
            }
        }
    }

    // MARK: Quick grid

    /// الأقسام التي لا يسعها الشريط السفلي (خمسة فقط) — تبقى في متناول اليد هنا.
    @ViewBuilder
    private var moreSections: some View {
        // أربع بلاطات فقط — الأقسام صارت سبعة عشر، وتمامها في شاشة «الأقسام» من الرأس.
        let off = Array(AppTab.sections.filter { !store.visibleTabs.contains($0) }.prefix(4))
        if !off.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                NavigationLink { SectionsView(onOpenTab: onOpenTab) } label: {
                    SectionHeader(title: loc("أقسام أخرى"), tint: Theme.accent(for: "dusk"))
                }
                .buttonStyle(.plain)
                // محاذاة علوية: البلاطات متساوية الارتفاع بحجز سطرَي الوصف، وإن اختلفت
                // بقيت رؤوسها على خطّ واحد بدل توسيط الأقصر منها.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top),
                                    GridItem(.flexible(), spacing: 12, alignment: .top)], spacing: 12) {
                    ForEach(off) { tab in
                        NavigationLink { SectionDestination(tab: tab) } label: {
                            SectionTile(tab: tab, tint: Theme.accent(for: tab.accentKey))
                        }
                        .pressable()
                    }
                }
                .id(themeKey)    // الشبكة الكسولة تخبّئ بلاطاتها؛ المفتاح يعيد بناءها مع الثيم
            }
        }
    }

    /// يتبدّل مع الطابع وتوحيد الأيقونات — لإعادة بناء الشبكات الكسولة التي لا
    /// تُعاد صبغتها وإن مُرِّر لها اللون قيمةً (ظهر ذلك في لقطة إبراهيم).
    private var themeKey: String { "\(store.appTheme.rawValue)-\(store.unifyIcons)" }

    private var quickGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            // «الكل» يبدّل إلى تبويب الأذكار إن كان في الشريط، وإلا دُفع القسم هنا كرأس «أقسام أخرى».
            if store.visibleTabs.contains(.adhkar) {
                SectionHeader(title: loc("startNow")) { onOpenTab(.adhkar) }
            } else {
                NavigationLink { SectionDestination(tab: .adhkar) } label: {
                    SectionHeader(title: loc("startNow"))
                }
                .buttonStyle(.plain)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: sizeClass == .regular ? 3 : 2), spacing: 12) {
                ForEach(AdhkarLibrary.categories.prefix(6)) { category in
                    NavigationLink {
                        DhikrSessionView(category: category)
                    } label: {
                        CategoryTile(category: category,
                                     completed: store.completedToday.contains(category.id),
                                     tint: Theme.accent(for: category.accent))
                    }
                    .pressable()
                }
            }
            .id(themeKey)
        }
    }

    /// بطاقة الصدقة نفسها تُعرض هنا وفي «الجمعة» — نسخةٌ واحدة، فلا يتبدّل نصّها
    /// ولا شعارها في موضعٍ دون موضع.
    private var sadaqahCard: some View { SadaqahCard() }

    private var footerNote: some View {
        Text("﴿ فَاذْكُرُونِي أَذْكُرْكُمْ ﴾")
            .font(Theme.dhikrFont(size: 16))
            .foregroundStyle(Theme.inkFaint)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}

// MARK: - بطاقة الصدقة

/// «الصدقة تطفئ الخطيئة كما يطفئ الماء النار» — مدخل سريع لمنصة إحسان.
/// النصّ في الجهة القائدة (يمين العربية) وشعار إحسان في الجهة المقابلة.
/// بطاقةٌ قائمة بذاتها لأن «اليوم» و«الجمعة» كلتيهما تعرضانها، ولفظُ الصدقة
/// وشعارُها لا يُنسخان في موضعين فيفترقا.
struct SadaqahCard: View {
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        let gold = Theme.accent(for: "gold")
        return Link(destination: URL(string: "https://ehsan.sa")!) {
            AtharCard(padding: 16, tint: gold) {
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc("بادر بالإحسان"))
                            .font(Theme.display(17, weight: .bold))
                            .foregroundStyle(Theme.ink)
                        // حديث، فيبقى بخطّ النسخ ولون الحبر مهما تبدّل خطّ الواجهة.
                        // التخريج كما في بطاقة القيام بشاشة الصلاة، فلا يبقى حديث بلا مصدر.
                        Text("«الصدقة تطفئ الخطيئة كما يطفئ الماء النار» — رواه الترمذي")
                            .font(Theme.naskhFont(size: 13))
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 5) {
                            Text(loc("تبرّع الآن"))
                            Image(systemName: "arrow.up.forward")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .font(Theme.display(12, weight: .semibold))
                        .foregroundStyle(gold)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(gold.opacity(0.14)))
                        .overlay(Capsule().strokeBorder(gold.opacity(0.2), lineWidth: 0.5))
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // شعار إحسان بألوانه، وفي وضع الأيقونات الموحّد قالبًا بلون واحد.
                    Image("EhsanLogo")
                        .renderingMode(store.unifyIcons ? .template : .original)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Theme.accent)
                        .frame(height: 64)
                        .accessibilityHidden(true)
                }
            }
        }
        .pressable()
    }
}

// MARK: - بطاقة الإذاعة

/// تراقب RadioPlayer وحدها؛ الألوان تُمرَّر قيمةً من الأب لتُعاد صبغتها مع تبديل الطابع.
private struct HomeRadioCard: View {
    @EnvironmentObject private var store: AtharStore
    @ObservedObject private var radio = RadioPlayer.shared
    var tint: Color
    var live: Color
    /// التبويب في الشريط السفلي؟ عندها تُبدَّل التبويبات بدل دفع نسخة ثانية من القسم.
    var inBar: Bool
    var onOpenTab: () -> Void

    private let source: LiveSource = .radio
    private var isThisSource: Bool { radio.source?.id == source.id }
    private var playing: Bool { isThisSource && radio.isPlaying }

    /// سطر الحالة تحت العنوان — من المشغّل نفسه، وإلا وصفٌ قصير للبثّ.
    private var statusText: String {
        if isThisSource, radio.error != nil { return loc("تعذّر الاتصال") }
        if isThisSource, radio.isBuffering { return loc("جارٍ الاتصال…") }
        if playing { return loc("يُبثّ الآن") }
        if isThisSource { return loc("متوقّف") }   // محمَّلة لكن موقوفة — بلفظ RadioView نفسه
        return loc("بثّ رسمي متواصل")
    }

    var body: some View {
        AtharCard(padding: 14, elevation: playing ? .e2 : .e1, tint: tint) {
            HStack(spacing: 12) {
                if inBar {
                    Button(action: onOpenTab) { front }.pressable()
                } else {
                    NavigationLink { SectionDestination(tab: .radio) } label: { front }.pressable()
                }
                toggleButton
            }
        }
        .animation(Motion.snappy, value: playing)
    }

    private var front: some View {
        HStack(spacing: 12) {
            IconChip(icon: "radio.fill", tint: tint, size: .lg)
            VStack(alignment: .leading, spacing: 4) {
                Text(loc("إذاعة القرآن"))
                    .font(Theme.display(17, weight: .bold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    RadioLivePill(color: live)
                    Text(statusText)
                        .font(Theme.display(11))
                        .foregroundStyle(playing ? tint : Theme.inkFaint)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    /// تشغيل/إيقاف من البطاقة مباشرة — نظير الزرّ الكبير في شاشة الإذاعة، مصغّرًا.
    private var toggleButton: some View {
        Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            if playing { radio.pause() } else if isThisSource { radio.resume() } else { radio.play(source) }
        } label: {
            ZStack {
                if playing {
                    Circle()
                        .fill(LinearGradient(colors: [tint, tint.opacity(0.82)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: tint.opacity(0.3), radius: 8, y: 4)
                } else {
                    Circle()
                        .fill(tint.opacity(0.14))
                        .overlay(Circle().strokeBorder(tint.opacity(0.18), lineWidth: 0.5))
                }
                if isThisSource, radio.isBuffering {
                    ProgressView().controlSize(.small).tint(playing ? Theme.onAccent : tint)
                } else {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(playing ? Theme.onAccent : tint)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .frame(width: 46, height: 46)
        }
        .pressable()
        .accessibilityLabel(playing ? loc("إيقاف مؤقّت") : loc("تشغيل"))
    }
}

// MARK: - Tile

struct CategoryTile: View {
    let category: DhikrCategory
    var completed: Bool = false
    /// اللون يُمرَّر قيمةً من الأب لا يُقرأ ساكنًا، ليُعاد رسم البلاطة فور تبديل الطابع
    /// (وإلا حسبتها SwiftUI متساوية القيمة وأبقتها بلونها القديم).
    var tint: Color

    var body: some View {
        let color = tint
        return AtharCard(padding: 14, tint: color) {
            VStack(alignment: .leading, spacing: Theme.Space.sm) {
                HStack {
                    IconChip(icon: category.icon, tint: color, size: .md)
                    Spacer()
                    if completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(color)
                    }
                }
                Text(category.title)
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(itemsLabel(category.items.count))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// تمييز العدد في العربية: جمع مجرور من ٣ إلى ١٠، ومفرد منصوب منوّن فيما فوقها.
    private func itemsLabel(_ n: Int) -> String {
        switch n {
        case 1:      return "ذكر واحد"
        case 2:      return "ذكران"
        case 3...10: return "\(n.counterText) أذكار"
        default:     return "\(n.counterText) ذكرًا"
        }
    }
}
