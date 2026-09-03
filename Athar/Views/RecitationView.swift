import SwiftUI

// MARK: - أدوات مشتركة

extension Double {
    /// توقيت التلاوة «د:ثث» — أرقام غربية كبقية عدّادات التطبيق.
    var clockText: String {
        guard isFinite, self >= 0 else { return "0:00" }
        let t = Int(self)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}

/// تمييز العدد لـ«سورة»: واحدة، ومثنّى، وجمعٌ مجرور من ٣ إلى ١٠، ومفردٌ لما فوقها.
/// المثنّى يتبع موضعه: «سورتان» خبرًا أو فاعلًا، و«سورتين» مضافًا إليه بعد «تنزيل».
private func surahCountText(_ n: Int, genitive: Bool = false) -> String {
    switch n {
    case 1: return loc("سورة واحدة")
    case 2: return genitive ? loc("سورتين") : loc("سورتان")
    case 3...10: return loc("%1$@ سور", n.counterText)
    default: return loc("%1$@ سورة", n.counterText)
    }
}

/// «سورتان محمَّلتان» و«٣ سور محمَّلة»: الصفة تطابق المعدود لا العدد.
private func downloadedSurahsText(_ n: Int) -> String {
    switch n {
    case 1: return loc("سورة واحدة محمَّلة")
    case 2: return loc("سورتان محمَّلتان")
    default: return loc("%1$@ محمَّلة", surahCountText(n))
    }
}

// MARK: - لوحة التلاوة

/// لوحة الاستماع: ما يُتلى الآن، والقارئ، والمحمَّل، ثم السور.
struct RecitationView: View {
    var isRootTab = false

    @EnvironmentObject private var store: AtharStore
    @StateObject private var audio = Recitation.shared
    @State private var query = ""
    @State private var showReciters = false
    @State private var showPlayer = false
    @State private var showSleep = false
    @State private var onlyDownloaded = false
    @State private var selecting = false
    @State private var picked: Set<Int> = []
    @State private var confirmAll = false

    private var summary: (count: Int, bytes: Int64) {
        audio.downloadedSummary(reciter: audio.reciterId)
    }

    private var surahs: [Surah] {
        let q = query.trimmingCharacters(in: .whitespaces)
        var out = Quran.surahs
        if onlyDownloaded {
            out = out.filter { RecitationLibrary.isDownloaded(reciter: audio.reciterId, surah: $0.id) }
        }
        guard !q.isEmpty else { return out }
        let n = q.strippedForSearch
        return out.filter { $0.name.strippedForSearch.contains(n) || String($0.id) == q }
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent)
            ScrollView {
                LazyVStack(spacing: 14) {
                    hero.appearStagger(0)
                    reciterCard.appearStagger(1)
                    toolsRow.appearStagger(2)
                    queueBar
                    listHeader
                    SettingsCard {
                        ForEach(Array(surahs.enumerated()), id: \.element.id) { i, su in
                            surahRow(su)
                            if i < surahs.count - 1 { SettingsDivider() }
                        }
                    }
                    if surahs.isEmpty { emptyList }
                    credit
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                .padding(.bottom, selecting ? 96 : (audio.surah == nil ? 30 : 112))
                .readableWidth(620)
            }
            .scrollIndicators(.hidden)
        }
        .overlay(alignment: .bottom) {
            if selecting { selectionBar } else { MiniPlayer() }
        }
        .searchable(text: $query, prompt: loc("ابحث عن سورة"))
        .confirmationDialog(loc("تنزيل المصحف كاملًا؟"), isPresented: $confirmAll, titleVisibility: .visible) {
            Button(loc("نزّل ١١٤ سورة")) { audio.downloadMany(Array(1...114)) }
            Button(loc("cancel"), role: .cancel) {}
        } message: {
            Text(loc("يقارب حجمه ٨٠٠ م.ب لهذا القارئ. يُفضَّل أن تكون على شبكة واي‑فاي."))
        }
        .navigationTitle(loc("التلاوة"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
        .sheet(isPresented: $showReciters) {
            ReciterPicker()
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
        .sheet(isPresented: $showSleep) {
            SleepTimerSheet()
                .presentationDetents([.height(430)])
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
    }

    // MARK: البطل — ما يُتلى الآن أو متابعة ما انقطع

    @ViewBuilder
    private var hero: some View {
        if let s = audio.surah, let su = Quran.surah(s) {
            heroCard(su: su, caption: audio.isPlaying ? loc("يُتلى الآن") : loc("متوقّف"), resume: false)
        } else if let s = audio.lastPlayed, let su = Quran.surah(s) {
            heroCard(su: su, caption: loc("متابعة الاستماع"), resume: true)
        } else {
            AtharCard(padding: 20, elevation: .e2, tint: Theme.accent) {
                VStack(spacing: 10) {
                    ZStack {
                        EightPointStar(innerRatio: 0.62)
                            .fill(Theme.accent.opacity(0.10))
                            .frame(width: 74, height: 74)
                        Image(systemName: "waveform")
                            .font(.system(size: 26))
                            .foregroundStyle(Theme.accent)
                    }
                    Text(loc("اختر سورة لتبدأ"))
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(loc("تُشغَّل من الشبكة، أو من تنزيلك فتعمل بلا إنترنت."))
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func heroCard(su: Surah, caption: String, resume: Bool) -> some View {
        Button {
            if resume { audio.play(surah: su.id) } else { showPlayer = true }
        } label: {
            AtharCard(padding: 16, elevation: .e2, tint: Theme.accent) {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        SurahDisc(number: su.id, size: 58, playing: audio.isPlaying)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(caption)
                                .font(Theme.display(11, weight: .medium))
                                .foregroundStyle(Theme.accent)
                            Text(loc("سورة %1$@", su.name))
                                .font(Theme.display(19, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(1)
                            Text(audio.reciter.name)
                                .font(Theme.display(12))
                                .foregroundStyle(Theme.inkFaint)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        PlayGlyph(playing: audio.isPlaying && !resume,
                                  buffering: audio.isBuffering && !resume, size: 46) {
                            resume ? audio.play(surah: su.id) : audio.toggle(surah: su.id)
                        }
                    }
                    if !resume {
                        ProgressStrip(progress: audio.progress,
                                      elapsed: audio.elapsed, duration: audio.duration) {
                            audio.seek(to: $0)
                        }
                    }
                }
            }
        }
        .pressable()
    }

    // MARK: القارئ

    private var reciterCard: some View {
        Button { showReciters = true } label: {
            AtharCard(padding: 13) {
                HStack(spacing: 13) {
                    Image(systemName: "person.wave.2.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("القارئ"))
                            .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                        Text(audio.reciter.name)
                            .font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.ink)
                    }
                    Spacer()
                    Text(loc("تغيير"))
                        .font(Theme.display(12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .pressable()
    }

    // MARK: شريط الأدوات — المحمَّل، التكرار، مؤقّت النوم

    private var toolsRow: some View {
        HStack(spacing: 10) {
            toolChip(icon: "arrow.down.circle.fill",
                     title: summary.count > 0 ? summary.count.counterText : loc("لا شيء"),
                     sub: summary.count > 0 ? summary.bytes.fileSizeText : loc("محمَّل"),
                     on: onlyDownloaded) {
                withAnimation(Motion.snappy) { onlyDownloaded.toggle() }
            }
            toolChip(icon: audio.repeatMode.icon,
                     title: audio.repeatMode.title, sub: loc("التكرار"),
                     on: audio.repeatMode != .next) {
                withAnimation(Motion.snappy) { audio.repeatMode = audio.repeatMode.next_ }
            }
            toolChip(icon: "moon.zzz.fill",
                     title: audio.sleep.isOn ? loc("مفعَّل") : loc("مطفأ"),
                     sub: loc("مؤقّت النوم"), on: audio.sleep.isOn) {
                // الورقة مباشرةً: صفحة المشغّل فارغة حين لا تلاوة، والمؤقّت لا يحتاج سورة.
                showSleep = true
            }
        }
    }

    private func toolChip(icon: String, title: String, sub: String,
                          on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
                Text(title)
                    .font(Theme.display(12, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(sub)
                    .font(Theme.display(9.5))
                    .foregroundStyle(Theme.inkFaint)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(on ? Theme.accent.opacity(0.10) : Theme.surfaceAlt))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(on ? Theme.accent.opacity(0.25) : Theme.hairline.opacity(0.5), lineWidth: 0.6))
        }
        .pressable()
    }

    // MARK: القائمة

    private var listHeader: some View {
        HStack(spacing: 10) {
            SettingsGroupTitle(text: selecting
                               ? loc("اختر ما تنزّله")
                               : (onlyDownloaded ? loc("المحمَّلة") : loc("السور")))
            Spacer()
            if selecting {
                Button(loc("إلغاء")) {
                    withAnimation(Motion.snappy) { selecting = false; picked.removeAll() }
                }
                .font(Theme.display(12.5, weight: .medium))
                .foregroundStyle(Theme.inkFaint)
            } else if onlyDownloaded {
                Button(loc("عرض الكل")) { withAnimation(Motion.snappy) { onlyDownloaded = false } }
                    .font(Theme.display(12.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
            } else {
                downloadMenu
            }
        }
        .padding(.top, 2)
        .padding(.horizontal, 2)
    }

    /// قائمة التنزيل: الكل، أو تحديد ما يريد، أو جزء عمّ.
    private var downloadMenu: some View {
        Menu {
            Button(loc("تنزيل المصحف كاملًا"), systemImage: "square.and.arrow.down.on.square") {
                confirmAll = true
            }
            Button(loc("تحديد ما أنزّله"), systemImage: "checklist") {
                withAnimation(Motion.snappy) { selecting = true; picked.removeAll() }
            }
            Button(loc("تنزيل جزء عمّ"), systemImage: "text.book.closed") {
                audio.downloadMany(Array(78...114))
            }
            if audio.pendingCount > 0 {
                Divider()
                Button(loc("إيقاف التنزيل"), systemImage: "stop.circle", role: .destructive) {
                    audio.cancelQueue()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle").font(.system(size: 12, weight: .semibold))
                Text(loc("تنزيل")).font(Theme.display(12.5, weight: .medium))
            }
            .foregroundStyle(Theme.accent)
        }
    }

    /// شريط تقدّم التنزيل الجماعي — يظهر ما دام في الطابور شيء.
    @ViewBuilder
    private var queueBar: some View {
        if audio.pendingCount > 0 {
            HStack(spacing: 9) {
                ProgressView().controlSize(.small)
                Text(loc("يجري تنزيل %1$@…", surahCountText(audio.pendingCount, genitive: true)))
                    .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
                Spacer(minLength: 4)
                Button(loc("إيقاف")) { audio.cancelQueue() }
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 13).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Theme.accent.opacity(0.08)))
        }
    }

    /// شريط الإجراء أسفل وضع التحديد.
    @ViewBuilder
    private var selectionBar: some View {
        if selecting {
            HStack(spacing: 10) {
                Button(picked.count == surahs.count ? loc("إلغاء الكل") : loc("تحديد الكل")) {
                    withAnimation(Motion.snappy) {
                        picked = picked.count == surahs.count ? [] : Set(surahs.map(\.id))
                    }
                }
                .font(Theme.display(13, weight: .medium))
                .foregroundStyle(Theme.accent)

                Spacer()

                Button {
                    audio.downloadMany(Array(picked))
                    withAnimation(Motion.snappy) { selecting = false; picked.removeAll() }
                } label: {
                    Text(picked.isEmpty
                         ? loc("اختر سورًا")
                         : loc("نزّل %1$@", picked.count.counterText))
                        .font(Theme.display(14, weight: .semibold))
                        .foregroundStyle(picked.isEmpty ? Theme.inkFaint : Theme.onAccent)
                        .padding(.horizontal, 20).padding(.vertical, 11)
                        .background(Capsule().fill(picked.isEmpty
                                                   ? AnyShapeStyle(Theme.surfaceAlt)
                                                   : AnyShapeStyle(Theme.accentGradient)))
                }
                .buttonStyle(.plain)
                .disabled(picked.isEmpty)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
            )
            .atharElevation(.e2)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var emptyList: some View {
        ContentUnavailableView(
            onlyDownloaded ? loc("لم تنزّل شيئًا بعد") : loc("لا توجد نتائج"),
            systemImage: onlyDownloaded ? "arrow.down.circle" : "magnifyingglass",
            description: Text(onlyDownloaded
                              ? loc("نزّل سورةً لتسمعها بلا إنترنت.")
                              : loc("جرّب اسم سورة أخرى.")))
            .padding(.top, 30)
    }

    @ViewBuilder
    private func surahRow(_ su: Surah) -> some View {
        let isCurrent = audio.surah == su.id
        let has = RecitationLibrary.isDownloaded(reciter: audio.reciterId, surah: su.id)
        let on = picked.contains(su.id)

        HStack(spacing: 12) {
            if selecting {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(has ? Theme.hairline : (on ? Theme.accent : Theme.inkFaint))
                    .frame(width: 34, height: 34)
            } else {
                PlayGlyph(playing: isCurrent && audio.isPlaying,
                          buffering: isCurrent && audio.isBuffering, size: 34, filled: isCurrent) {
                    audio.toggle(surah: su.id)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(loc("سورة %1$@", su.name))
                    .font(Theme.display(15, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                Text(selecting && has
                     ? loc("محمَّلة")
                     : "\(su.revelation) · \(su.ayahCount.ayahCountText)")
                    .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
            }
            Spacer(minLength: 6)
            if !selecting { DownloadGlyph(surah: su.id) }
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(isCurrent && !selecting ? Theme.accent.opacity(0.05) : .clear)
        .opacity(selecting && has ? 0.5 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard selecting else { return }
            guard !has else { return }          // المحمَّلة لا تُنزَّل مرّتين
            if on { picked.remove(su.id) } else { picked.insert(su.id) }
        }
    }

    private var credit: some View {
        VStack(spacing: 6) {
            Rectangle().fill(Theme.hairline.opacity(0.6))
                .frame(height: 0.7).padding(.horizontal, 50).padding(.top, 10)
            Text(loc("التلاوات من MP3Quran.net — متاحة للعموم، برواية حفص عن عاصم."))
                .font(Theme.display(10.5))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 4)
    }
}

// MARK: - صفحة المشغّل

/// صفحة التلاوة الكاملة: عنوان السورة، وشريط الموضع، وكل أزرار التحكّم.
struct PlayerView: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var audio = Recitation.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showReciters = false
    @State private var showSleep = false
    @State private var showSpeed = false
    @State private var confirmDelete = false
    @State private var tick = Date()

    /// في @State لا في let: المقدِّم يعيد إنشاء هذه البنية مع كل نبضة تقدّم، ولو كان
    /// الناشر خاصّيةً عاديةً لاستُبدل قبل أن يكمل ثانيته فلا يتحرّك عدّاد النوم.
    @State private var ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var surah: Surah? { audio.surah.flatMap(Quran.surah) }

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: Theme.accent)
                if let su = surah {
                    ScrollView {
                        VStack(spacing: 18) {
                            discBlock(su)
                            titleBlock(su)
                            controlCard
                            optionsCard
                            if audio.sleep.isOn { sleepBanner }
                            if audio.failed { failureNote }
                            upNextCard(su)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 2)
                        .padding(.bottom, 28)
                        .readableWidth(480)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    ContentUnavailableView(loc("لا تلاوة الآن"), systemImage: "waveform",
                                           description: Text(loc("اختر سورة من قائمة التلاوة.")))
                }
            }
            .navigationTitle(loc("التلاوة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("تم")) { dismiss() }
                }
            }
            .sheet(isPresented: $showReciters) {
                ReciterPicker()
                    .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
            }
            .sheet(isPresented: $showSleep) {
                SleepTimerSheet()
                    .presentationDetents([.height(430)])
                    .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
            }
            .sheet(isPresented: $showSpeed) {
                SpeedSheet()
                    .presentationDetents([.height(300)])
                    .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
            }
            // خليّة «محمَّلة» تجاور خلايا حالةٍ لا تُضغط فتُقرأ حالةً، ولمسةٌ عابرة تُسقط نحو ١٠ م.ب.
            .confirmationDialog(loc("حذف التنزيل؟"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(loc("حذف التنزيل"), role: .destructive) {
                    if let s = audio.surah { audio.delete(surah: s) }
                }
                Button(loc("cancel"), role: .cancel) {}
            } message: {
                Text(loc("تبقى السورة تُتلى بثًّا من الشبكة."))
            }
        }
        .onReceive(ticker) { tick = $0 }
    }

    /// القرص وحوله حلقة تقدّم رفيعة — تُري موضع التلاوة بلمحة.
    private func discBlock(_ su: Surah) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.accent.opacity(0.10), lineWidth: 3)
            Circle()
                .trim(from: 0, to: audio.progress)   // بلا حدٍّ أدنى، فلا تظهر شرطة عند البداية
                .stroke(Theme.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.4), value: audio.progress)
            SurahDisc(number: su.id, size: 128, playing: audio.isPlaying)
        }
        .frame(width: 176, height: 176)
        .padding(.top, 4)
        // الحلقة تدور مع الزمن، فلا تُعكس مع اتجاه الواجهة.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func titleBlock(_ su: Surah) -> some View {
        VStack(spacing: 7) {
            Text(loc("سورة %1$@", su.name))
                .font(Theme.naskhFont(size: 30, bold: true))
                .foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text("\(su.revelation) · \(su.ayahCount.ayahCountText)")
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
            Button { showReciters = true } label: {
                HStack(spacing: 5) {
                    Image(systemName: "person.wave.2.fill").font(.system(size: 10, weight: .semibold))
                    Text(audio.reciter.name).font(Theme.display(13, weight: .medium))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(Theme.accent.opacity(0.10)))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    // MARK: مركز التحكّم

    /// بطاقة واحدة تجمع شريط الموضع وأزرار النقل — أوضح من أزرارٍ عائمة.
    private var controlCard: some View {
        AtharCard(padding: 16, elevation: .e2) {
            VStack(spacing: 16) {
                ProgressStrip(progress: audio.progress,
                              elapsed: audio.elapsed, duration: audio.duration,
                              tall: true) { audio.seek(to: $0) }
                transport
            }
        }
    }

    /// السابق · ترجيع ١٠ · تشغيل · تقديم ١٠ · التالي.
    /// الصفّ مثبّت من اليسار كشريط الموضع تمامًا: بداية التلاوة يسارًا ونهايتها
    /// يمينًا، فالرجوع يسار والتقديم يمين — ولو عكسناه لخالف اتجاه الشريط فوقه.
    private var transport: some View {
        HStack(spacing: 12) {
            roundButton("backward.end.fill", diameter: 44, icon: 15,
                        enabled: (audio.surah ?? 1) > 1 || audio.elapsed > 3) { audio.previous() }
            roundButton("gobackward.10", diameter: 50, icon: 20, tinted: true) { audio.seek(by: -10) }

            PlayGlyph(playing: audio.isPlaying, buffering: audio.isBuffering,
                      size: 68, filled: true, iconSize: 25) {
                audio.isPlaying ? audio.pause() : audio.resume()
            }

            roundButton("goforward.10", diameter: 50, icon: 20, tinted: true) { audio.seek(by: 10) }
            roundButton("forward.end.fill", diameter: 44, icon: 15,
                        enabled: (audio.surah ?? 114) < 114) { audio.next() }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func roundButton(_ icon: String, diameter: CGFloat, icon size: CGFloat,
                             tinted: Bool = false, enabled: Bool = true,
                             _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(enabled ? (tinted ? Theme.accent : Theme.inkSoft) : Theme.hairline)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(tinted ? Theme.accent.opacity(0.10) : Theme.surfaceAlt))
                .overlay(Circle().strokeBorder(Theme.hairline.opacity(tinted ? 0 : 0.5), lineWidth: 0.6))
        }
        .pressable()
        .disabled(!enabled)
    }

    // MARK: الخيارات — تكرار، سرعة، مؤقّت، تنزيل

    private var optionsCard: some View {
        AtharCard(padding: 6) {
            HStack(spacing: 0) {
                optionCell(icon: audio.repeatMode.icon, label: audio.repeatMode.title,
                           on: audio.repeatMode != .next) {
                    withAnimation(Motion.snappy) { audio.repeatMode = audio.repeatMode.next_ }
                }
                cellDivider
                optionCell(icon: "speedometer",
                           label: audio.rate == 1 ? loc("عادي") : "×\(String(format: "%g", audio.rate))",
                           on: audio.rate != 1) { showSpeed = true }
                cellDivider
                optionCell(icon: "moon.zzz.fill",
                           label: audio.sleep.isOn ? sleepShort : loc("مؤقّت النوم"),
                           on: audio.sleep.isOn) { showSleep = true }
                cellDivider
                downloadCell
            }
        }
    }

    private var cellDivider: some View {
        Rectangle().fill(Theme.hairline.opacity(0.5))
            .frame(width: 0.7, height: 34)
    }

    @ViewBuilder
    private var downloadCell: some View {
        if let s = audio.surah {
            switch audio.state(reciter: audio.reciterId, surah: s) {
            case .done:
                optionCell(icon: "checkmark.circle.fill", label: loc("محمَّلة"), on: true) {
                    confirmDelete = true
                }
            case .downloading(let f):
                optionCell(icon: "arrow.down.circle", label: "\(Int(f * 100).counterText)٪", on: true) {}
            case .waiting:
                optionCell(icon: "arrow.down.circle", label: loc("ينتظر"), on: true) {}
            case .idle, .failed:
                optionCell(icon: "arrow.down.circle", label: loc("تنزيل"), on: false) {
                    audio.download(surah: s)
                }
            }
        }
    }

    private func optionCell(icon: String, label: String, on: Bool,
                            _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
                    .frame(height: 18)
                Text(label)
                    .font(Theme.display(10, weight: .medium))
                    .foregroundStyle(on ? Theme.accent : Theme.inkFaint)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// يملأ ذيل الصفحة بما ينفع: التالية في الترتيب، وفتح السورة للقراءة.
    @ViewBuilder
    private func upNextCard(_ su: Surah) -> some View {
        AtharCard(padding: 6) {
            VStack(spacing: 0) {
                if su.id < 114, let nx = Quran.surah(su.id + 1) {
                    Button { audio.play(surah: nx.id) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Theme.accent.opacity(0.10)))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(loc("التالية"))
                                    .font(Theme.display(10.5)).foregroundStyle(Theme.inkFaint)
                                Text(loc("سورة %1$@", nx.name))
                                    .font(Theme.display(14, weight: .medium)).foregroundStyle(Theme.ink)
                            }
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    SettingsDivider()
                }
                // القارئ هنا مدفوعٌ داخل صفحة المشغّل نفسها: نعلّم شريطه المصغّر كي يرجع
                // إليها بدل أن يفتح صفحةً ثانيةً فوقها فتتداخل الأوراق بلا نهاية.
                NavigationLink {
                    SurahReaderView(surahId: su.id).environment(\.insidePlayerSheet, true)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Theme.accent.opacity(0.10)))
                        Text(loc("اقرأ السورة وأنت تسمعها"))
                            .font(Theme.display(14, weight: .medium)).foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sleepShort: String {
        if case .endOfSurah = audio.sleep { return loc("للنهاية") }
        guard let end = audio.sleepEndsAt else { return loc("مفعَّل") }
        let left = max(0, end.timeIntervalSince(tick))
        return loc("%1$@ د", Int(ceil(left / 60)).counterText)
    }

    private var sleepBanner: some View {
        HStack(spacing: 9) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 12)).foregroundStyle(Theme.accent)
            Text(audio.sleep == .endOfSurah
                 ? loc("ستتوقّف التلاوة عند نهاية السورة.")
                 : loc("ستتوقّف التلاوة بعد %1$@.", sleepRemainingText))
                .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 4)
            Button(loc("إلغاء")) { audio.cancelSleep() }
                .font(Theme.display(12, weight: .medium))
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Theme.accent.opacity(0.07)))
    }

    private var sleepRemainingText: String {
        guard let end = audio.sleepEndsAt else { return "" }
        return max(0, end.timeIntervalSince(tick)).clockText
    }

    private var failureNote: some View {
        HStack(spacing: 9) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 13)).foregroundStyle(Color.red.opacity(0.8))
            Text(loc("تعذّر التشغيل. تحقّق من الاتصال، أو نزّل السورة لتعمل بلا إنترنت."))
                .font(Theme.display(12)).foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.red.opacity(0.06)))
    }

    private func speedText(_ r: Float) -> String {
        r == rintf(r) ? String(Int(r)) : String(format: "%.2g", r)
    }
}

// MARK: - ورقة مؤقّت النوم

struct SleepTimerSheet: View {
    @StateObject private var audio = Recitation.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: Theme.accent, motif: false)
                ScrollView {
                    VStack(spacing: 12) {
                        Text(loc("تتوقّف التلاوة وحدها، فتنام على ذِكر."))
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                        SettingsCard {
                            ForEach(Array(SleepTimer.choices.enumerated()), id: \.element.id) { i, t in
                                Button {
                                    audio.setSleep(t)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: audio.sleep == t ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 17))
                                            .foregroundStyle(audio.sleep == t ? Theme.accent : Theme.hairline)
                                        Text(t.title)
                                            .font(Theme.display(15, weight: audio.sleep == t ? .semibold : .regular))
                                            .foregroundStyle(Theme.ink)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 14).padding(.vertical, 12)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if i < SleepTimer.choices.count - 1 { SettingsDivider() }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 20)
                    .readableWidth(520)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(loc("مؤقّت النوم"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(loc("تم")) { dismiss() } } }
        }
    }
}

// MARK: - ورقة السرعة

struct SpeedSheet: View {
    @StateObject private var audio = Recitation.shared
    @Environment(\.dismiss) private var dismiss

    private let rates: [Float] = [0.75, 0.9, 1.0, 1.1, 1.25, 1.5]

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: Theme.accent, motif: false)
                VStack(spacing: 14) {
                    Text(loc("الإبطاء يعين على الحفظ والترديد."))
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                        .padding(.top, 6)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                              spacing: 10) {
                        ForEach(rates, id: \.self) { r in
                            let on = abs(audio.rate - r) < 0.001
                            Button {
                                audio.rate = r
                                dismiss()
                            } label: {
                                Text(r == 1 ? loc("عادي") : "×\(String(format: "%g", r))")
                                    .font(Theme.display(15, weight: on ? .bold : .medium))
                                    .foregroundStyle(on ? Theme.onAccent : Theme.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(on ? AnyShapeStyle(Theme.accentGradient)
                                                 : AnyShapeStyle(Theme.surfaceAlt)))
                            }
                            .pressable()
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 18)
                .readableWidth(520)
            }
            .navigationTitle(loc("سرعة التلاوة"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(loc("تم")) { dismiss() } } }
        }
    }
}

// MARK: - اختيار القارئ

struct ReciterPicker: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var audio = Recitation.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AtharBackground(tint: Theme.accent)
                ScrollView {
                    VStack(spacing: 12) {
                        SettingsCard {
                            ForEach(Array(RecitationLibrary.reciters.enumerated()), id: \.element.id) { i, r in
                                reciterRow(r)
                                if i < RecitationLibrary.reciters.count - 1 { SettingsDivider() }
                            }
                        }
                        Text(loc("التلاوات من موقع MP3Quran.net، متاحة للعموم بلا مقابل، برواية حفص عن عاصم."))
                            .font(Theme.display(11.5))
                            .foregroundStyle(Theme.inkFaint)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 10)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                    .readableWidth(560)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(loc("اختر القارئ"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(loc("تم")) { dismiss() } } }
        }
    }

    private func reciterRow(_ r: Reciter) -> some View {
        let sum = audio.downloadedSummary(reciter: r.id)
        let on = audio.reciterId == r.id
        return Button {
            audio.select(r)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17))
                    .foregroundStyle(on ? Theme.accent : Theme.hairline)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name)
                        .font(Theme.display(15, weight: on ? .semibold : .regular))
                        .foregroundStyle(Theme.ink)
                    if sum.count > 0 {
                        Text("\(downloadedSurahsText(sum.count)) · \(sum.bytes.fileSizeText)")
                            .font(Theme.display(10.5))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
                Spacer()
                if sum.count > 0 {
                    Menu {
                        Button(loc("حذف تنزيلات هذا القارئ"), systemImage: "trash", role: .destructive) {
                            audio.deleteAll(reciter: r.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.inkFaint)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - قطع مشتركة

/// قرص السورة — نجمة ثمانية بالرقم، تنبض برفق أثناء التلاوة.
struct SurahDisc: View {
    let number: Int
    var size: CGFloat = 60
    var playing: Bool = false

    @State private var pulse = false

    var body: some View {
        ZStack {
            EightPointStar(innerRatio: 0.66)
                .fill(Theme.accent.opacity(0.10))
            EightPointStar(innerRatio: 0.66)
                .stroke(Theme.accentGradient, lineWidth: size > 100 ? 2 : 1.2)
            EightPointStar(innerRatio: 0.74)
                .stroke(Theme.accent.opacity(0.30), lineWidth: 0.7)
                .padding(size * 0.11)
            Text(number.counterText)
                .font(.system(size: size * 0.26, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
        .frame(width: size, height: size)
        .scaleEffect(playing && pulse ? 1.025 : 1)
        .animation(playing ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true) : .default,
                   value: pulse)
        .onAppear { pulse = true }
    }
}

/// زرّ تشغيل/إيقاف موحّد — يعرض دوّامة أثناء التحميل من الشبكة.
struct PlayGlyph: View {
    var playing: Bool
    var buffering: Bool = false
    var size: CGFloat = 40
    var filled: Bool = false
    var iconSize: CGFloat? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(filled ? AnyShapeStyle(Theme.accentGradient)
                                 : AnyShapeStyle(Theme.accent.opacity(0.12)))
                if buffering {
                    ProgressView()
                        .controlSize(.small)
                        .tint(filled ? Theme.onAccent : Theme.accent)
                } else {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: iconSize ?? size * 0.38, weight: .bold))
                        .foregroundStyle(filled ? Theme.onAccent : Theme.accent)
                }
            }
            .frame(width: size, height: size)
        }
        .pressable()
    }
}

/// شريط موضع التلاوة مع الزمن المنقضي والمتبقّي، قابل للسحب.
struct ProgressStrip: View {
    let progress: Double
    let elapsed: Double
    let duration: Double
    var tall: Bool = false
    /// الشريط المصغّر لا يُسحب: مساحة لمسه الموسّعة كانت تبتلع ضغطة زرّ التشغيل
    /// فوقه، والسحب متاحٌ في صفحة المشغّل.
    var seekable: Bool = true
    var onSeek: (Double) -> Void

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        VStack(spacing: tall ? 11 : 5) {
            GeometryReader { g in
                let h: CGFloat = tall ? 7 : 4
                let knob: CGFloat = 14
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.accent.opacity(0.14))
                        .frame(height: h)
                    Capsule().fill(Theme.accentGradient)
                        .frame(width: max(h, g.size.width * clamped), height: h)
                    if tall && duration > 0 {
                        // المقبض يسير داخل الشريط لا خارجه، فلا يبرز عند الطرفين.
                        Circle()
                            .fill(Theme.surface)
                            .overlay(Circle().strokeBorder(Theme.accent, lineWidth: 3.2))
                            .frame(width: knob, height: knob)
                            .offset(x: (g.size.width - knob) * clamped)
                            .shadow(color: Theme.accent.opacity(0.25), radius: 3, y: 1)
                    }
                }
                .frame(height: max(h, tall ? 14 : h), alignment: .center)
                .contentShape(seekable ? Rectangle().inset(by: -14) : Rectangle().inset(by: 0))
                .gesture(seekable
                         ? DragGesture(minimumDistance: 0)
                            .onEnded { v in onSeek(v.location.x / max(1, g.size.width)) }
                         : nil)
            }
            .frame(height: tall ? 14 : 4)

            if tall || duration > 0 {
                HStack {
                    Text(elapsed.clockText)
                    Spacer()
                    Text(duration > 0 ? "−" + max(0, duration - elapsed).clockText : "—")
                }
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.inkFaint)
                .monospacedDigit()
            }
        }
        // الزمن يجري من اليسار دائمًا، فلا يُعكس الشريط مع اتجاه الواجهة.
        .environment(\.layoutDirection, .leftToRight)
    }
}

// MARK: - مشغّل مصغّر

/// المشغّل المصغّر داخل قارئٍ فتحته صفحة المشغّل نفسها: لمسة عنوانه ترجع إليها
/// بدل أن تفتح صفحةً ثانيةً فوقها.
private struct InsidePlayerSheetKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var insidePlayerSheet: Bool {
        get { self[InsidePlayerSheetKey.self] }
        set { self[InsidePlayerSheetKey.self] = newValue }
    }
}

/// شريط ثابت أسفل الشاشة ما دامت هناك تلاوة — لمسه يفتح صفحة المشغّل.
struct MiniPlayer: View {
    @EnvironmentObject private var store: AtharStore
    @StateObject private var audio = Recitation.shared
    @Environment(\.insidePlayerSheet) private var insidePlayer
    @Environment(\.dismiss) private var dismiss
    @State private var showPlayer = false

    var body: some View {
        // الورقة معلّقة على حاويةٍ باقية لا على الشريط الشرطي: لو صارت السورة nil
        // والصفحة مفتوحة بقي مقدِّمها، فتعرض «لا تلاوة الآن» بدل أن تُسحب من تحت المستخدم.
        ZStack {
            if let s = audio.surah, let su = Quran.surah(s) { bar(s, su) }
        }
        .sheet(isPresented: $showPlayer) {
            PlayerView()
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
    }

    private func bar(_ s: Int, _ su: Surah) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 11) {
                PlayGlyph(playing: audio.isPlaying, buffering: audio.isBuffering,
                          size: 38, filled: true) {
                    audio.isPlaying ? audio.pause() : audio.resume()
                }
                Button {
                    if insidePlayer { dismiss() } else { showPlayer = true }
                } label: {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc("سورة %1$@", su.name))
                            .font(Theme.display(14, weight: .semibold))
                            .foregroundStyle(Theme.ink).lineLimit(1)
                        Text(audio.failed ? loc("تعذّر التشغيل — تحقّق من الاتصال")
                                          : audio.reciter.name)
                            .font(Theme.display(11))
                            .foregroundStyle(audio.failed ? Color.red.opacity(0.8) : Theme.inkFaint)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { audio.next() } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(s >= 114)

                Button { audio.stop() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.inkFaint)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }

            ProgressStrip(progress: audio.progress, elapsed: audio.elapsed,
                          duration: 0, seekable: false) { _ in }
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surface)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
        )
        .atharElevation(.e2)
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(Motion.smooth, value: audio.surah)
    }
}

/// زرّ التنزيل بحالاته الأربع.
struct DownloadGlyph: View {
    let surah: Int
    @StateObject private var audio = Recitation.shared

    var body: some View {
        switch audio.state(reciter: audio.reciterId, surah: surah) {
        case .idle, .failed:
            let failed = audio.state(reciter: audio.reciterId, surah: surah) == .failed
            Button { audio.download(surah: surah) } label: {
                Image(systemName: failed ? "exclamationmark.arrow.circlepath" : "arrow.down.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(failed ? Color.red.opacity(0.7) : Theme.inkFaint)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        case .waiting:
            ProgressView().controlSize(.small).frame(width: 34, height: 34)
        case .downloading(let f):
            ZStack {
                Circle().stroke(Theme.accent.opacity(0.15), lineWidth: 2.5)
                Circle().trim(from: 0, to: max(0.02, f))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
            .frame(width: 34, height: 34)
            .animation(Motion.snappy, value: f)
        case .done:
            Menu {
                Button(loc("حذف التنزيل"), systemImage: "trash", role: .destructive) {
                    audio.delete(surah: surah)
                }
            } label: {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
            }
        }
    }
}
