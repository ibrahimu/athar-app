import SwiftUI

/// تحدي الختمة: يختار المستخدم مدة الختمة أو مقدار اليوم، والتطبيق يحسب
/// الباقي ويوزّع ورد كل يوم، ويريه أهو متقدّم أم متأخّر عن خطته.
struct KhatmahView: View {
    @EnvironmentObject private var store: AtharStore

    var body: some View {
        ZStack {
            AtharBackground()
            ScrollView {
                Group {
                    if store.khatmahActive { active } else { setup }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("الختمة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: الإعداد

    @State private var days = 30
    @State private var mode: KhatmahMode = .open

    private let dayOptions = [7, 10, 15, 30, 60]

    private var setup: some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.gold.opacity(0.8))
                Text(loc("ابدأ ختمتك"))
                    .font(Theme.display(24, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(loc("حدّد مدة الختمة، ونحسب لك ورد كل يوم\nونتابع معك أين وصلت."))
                    .font(Theme.display(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 10)

            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("أختمها في"))
                HStack(spacing: 8) {
                    ForEach(dayOptions, id: \.self) { d in
                        let on = days == d
                        Button {
                            days = d
                            Haptics.tap(enabled: store.hapticsEnabled)
                        } label: {
                            VStack(spacing: 2) {
                                Text(d.counterText)
                                    .font(.system(size: 19, weight: .bold, design: .rounded))
                                Text(loc("يوم")).font(Theme.display(10))
                            }
                            .foregroundStyle(on ? .white : Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(on ? Theme.accent : Theme.surface))
                        }
                        .pressable()
                    }
                }
                Text(planSummary)
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkFaint)
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 8) {
                SettingsGroupTitle(text: loc("توزيع الورد"))
                SettingsCard {
                    ForEach(Array(KhatmahMode.allCases.enumerated()), id: \.element.id) { i, m in
                        Button {
                            mode = m
                            Haptics.tap(enabled: store.hapticsEnabled)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mode == m ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(mode == m ? Theme.accent : Theme.hairline)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.title).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                                    Text(m.detail).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if i < KhatmahMode.allCases.count - 1 { SettingsDivider() }
                    }
                }
            }

            Button {
                store.startKhatmah(days: days, mode: mode)
                Haptics.done(enabled: store.hapticsEnabled)
            } label: {
                Text(loc("ابدأ التحدي"))
                    .font(Theme.display(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Theme.accent))
            }
            .pressable()
        }
    }

    private var planSummary: String {
        let per = Int((Double(Quran.pageCount) / Double(days)).rounded(.up))
        let juz = Double(30) / Double(days)
        let juzText = juz >= 1 ? "\(Int(juz.rounded()).counterText) جزء" : loc("نحو نصف جزء")
        return "\(per.counterText) صفحة تقريبًا كل يوم — \(juzText) يوميًّا"
    }

    // MARK: التحدي النشط

    private var active: some View {
        VStack(spacing: 22) {
            ring
            statusLine
            todayCard
            if !store.khatmahMode.slotNames.isEmpty { slots }
            actions
            cancelButton
        }
    }

    private var progress: Double { Double(store.khatmahPagesDone) / Double(Quran.pageCount) }

    private var ring: some View {
        ZStack {
            ProgressRing(progress: progress, color: Theme.accent, lineWidth: 13)
            VStack(spacing: 3) {
                Text("\(Int((progress * 100).rounded()).counterText)٪")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                Text("\(store.khatmahPagesDone.counterText) من \(Quran.pageCount.counterText) صفحة")
                    .font(Theme.display(12)).foregroundStyle(Theme.inkFaint)
                Text(loc("اليوم \(store.khatmahDayIndex.counterText) من \(store.khatmahTotalDays.counterText)"))
                    .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(width: 200, height: 200)
        .padding(.top, 6)
    }

    @ViewBuilder
    private var statusLine: some View {
        let d = store.khatmahDelta
        if d >= 0 {
            Label(d == 0 ? loc("على الخطة تمامًا") : loc("متقدّم بـ\(d.counterText) صفحة — ما شاء الله"),
                  systemImage: "checkmark.seal.fill")
                .font(Theme.display(13, weight: .semibold))
                .foregroundStyle(Theme.accent)
        } else {
            Label(loc("متأخّر بـ\((-d).counterText) صفحة — عوّضها على مهل"),
                  systemImage: "arrow.counterclockwise")
                .font(Theme.display(13, weight: .semibold))
                .foregroundStyle(Theme.gold)
        }
    }

    private var todayCard: some View {
        let range = store.khatmahTodayRange
        let startRef = Quran.firstAyah(ofPage: range.lowerBound)
        return AtharCard(padding: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(loc("ورد اليوم"))
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(Theme.accent)

                Text(loc("من صفحة \(range.lowerBound.counterText) إلى \(range.upperBound.counterText)"))
                    .font(Theme.display(18, weight: .bold))
                    .foregroundStyle(Theme.ink)

                Text("يبدأ من سورة \(Quran.surah(startRef.surah)?.name ?? "") · الجزء \(Quran.juz(of: startRef).counterText)")
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)

                NavigationLink {
                    SurahReaderView(surahId: startRef.surah, scrollTo: startRef)
                } label: {
                    Label(loc("ابدأ القراءة من موضعك"), systemImage: "book.pages.fill")
                        .font(Theme.display(14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent))
                }
                .pressable()
            }
        }
    }

    private var slots: some View {
        let range = store.khatmahTodayRange
        let names = store.khatmahMode.slotNames
        let total = range.count
        let per = Int((Double(total) / Double(names.count)).rounded(.up))
        return VStack(spacing: 8) {
            SettingsGroupTitle(text: loc("توزيع اليوم"))
            SettingsCard {
                ForEach(Array(names.enumerated()), id: \.offset) { i, name in
                    let from = range.lowerBound + i * per
                    let to = min(range.upperBound, from + per - 1)
                    if from <= range.upperBound {
                        HStack {
                            Text(name).font(Theme.display(14, weight: .medium)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(loc("ص \(from.counterText)–\(to.counterText)"))
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Theme.inkSoft).monospacedDigit()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        if i < names.count - 1 { SettingsDivider() }
                    }
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                store.khatmahPagesDone += 1
                Haptics.step(enabled: store.hapticsEnabled)
                if store.khatmahPagesDone == Quran.pageCount {
                    Haptics.done(enabled: store.hapticsEnabled)
                }
            } label: {
                Label(loc("قرأت صفحة"), systemImage: "plus")
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.accent))
            }
            .pressable()

            Button {
                store.khatmahPagesDone = store.khatmahTodayRange.upperBound
                Haptics.done(enabled: store.hapticsEnabled)
            } label: {
                Text(loc("أتممت الورد"))
                    .font(Theme.display(15, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.accentSoft))
            }
            .pressable()
        }
    }

    private var cancelButton: some View {
        Button(loc("إنهاء التحدي")) {
            store.cancelKhatmah()
            Haptics.tap(enabled: store.hapticsEnabled)
        }
        .font(Theme.display(13))
        .foregroundStyle(Theme.inkFaint)
        .padding(.top, 4)
    }
}
