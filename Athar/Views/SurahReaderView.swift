import SwiftUI

/// ألوان صفحة القراءة حسب السِّمة المختارة.
struct ReadingPalette {
    let paper: Color
    let ink: Color
    let faint: Color
    /// حبر ثانٍ للإرشاد الوظيفي (رقم الصفحة والجزء والنسبة): «الخافت» يبلغ ٢٫٨:١
    /// على الورق الفاتح فلا يقرأه ضعيف البصر، وهذا فوق ٥:١ وما زال أهدأ من الحبر.
    let secondary: Color
    let accent: Color
    let hairline: Color

    static func of(_ theme: ReadingTheme) -> ReadingPalette {
        switch theme {
        case .paper:
            // لون التمييز من سِمة التطبيق لا أخضرُ ثابت: كان منسوخًا من السِّمة الافتراضية
            // فيبقى أخضر حين يختار المستخدم سِمةً أخرى، فتظهر على الصفحة الواحدة
            // علاماتُ آيٍ خضراء وأزرارُ شريطٍ ومشغّلٌ بلونٍ آخر. البُنّي الداكن (سيبيا) مقصود.
            return .init(paper: Color(hex: 0xFBF9F3), ink: Color(hex: 0x14201B),
                         faint: Color(hex: 0x8A9992), secondary: Color(hex: 0x5A6560),
                         accent: Color(hex: Theme.current.accent.light), hairline: Color(hex: 0xE6E1D4))
        case .sepia:
            return .init(paper: Color(hex: 0xF4E9D6), ink: Color(hex: 0x3E3327),
                         faint: Color(hex: 0x9A8B72), secondary: Color(hex: 0x6E5E43),
                         accent: Color(hex: 0x8A6A2F), hairline: Color(hex: 0xE0D2B8))
        case .night:
            // بطلب المستخدم: عكس النهاري — حبر أبيض على ورق أزرق داكن.
            return .init(paper: Color(hex: 0x0E1726), ink: Color(hex: 0xF2F5F8),
                         faint: Color(hex: 0x7C8AA0), secondary: Color(hex: 0xA6B2C4),
                         accent: Color(hex: Theme.current.accent.dark), hairline: Color(hex: 0x1F2C42))
        }
    }
}

/// إبقاء الشاشة يقظة بعدّاد لا ببوليان: القارئ يفتح سورةً فوق سورة، و«الظهور»
/// للجديدة يسبق «الاختفاء» للقديمة — فلو كتب كلٌّ منهما القيمة مباشرةً لأطفأ
/// القارئُ المغادر الشاشةَ على قارئٍ ما زال مفتوحًا. العدّاد يمنع هذا التداخل.
private enum ReaderWake {
    private static var depth = 0

    static func enter() {
        depth += 1
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func exit() {
        depth = max(0, depth - 1)
        UIApplication.shared.isIdleTimerDisabled = depth > 0
    }
}

struct SurahReaderView: View {
    let surahId: Int
    var scrollTo: AyahRef? = nil

    @EnvironmentObject private var store: AtharStore
    @StateObject private var audio = Recitation.shared
    @StateObject private var ayahAudio = AyahAudio.shared
    @State private var showControls = false
    @State private var selected: AyahRef? = nil
    @State private var currentRef: AyahRef?
    @State private var lastCountedPage: Int?

    /// السورة الفاعلة الآن — تتبع موضع القراءة الحيّ لا السورة التي فُتح بها
    /// القارئ، وإلا ارتدّ التبديل بين «صفحة» و«آية آية» إلى أول سورةٍ فُتحت
    /// وضاع موضع القارئ بعد تقليب عشرات الصفحات.
    private var activeSurahId: Int { (currentRef ?? scrollTo)?.surah ?? surahId }

    private var surah: Surah? { Quran.surah(activeSurahId) }
    private var palette: ReadingPalette { .of(store.readingTheme) }

    /// حجزُ ارتفاع المشغّل المصغّر أسفل كل أوضاع القراءة: الشريط السفلي صار
    /// «مشغّل + شريط موضع»، وبطاقة المشغّل معتمة تغطّي آخر سطرٍ من الصفحة
    /// ورقمَها وزرَّ «سورة التالية». صفرٌ حين لا تلاوة، فلا تتغيّر الصفحة.
    private var bottomReserve: CGFloat { (audio.surah == nil && !ayahAudio.isActive) ? 0 : 86 }

    /// رقم السورة الظاهرة الآن — يتغيّر أثناء تقليب الصفحات عبر حدود السور.
    private var visibleSurahId: Int {
        (currentRef ?? AyahRef(surah: surahId, ayah: 1)).surah
    }

    /// اسم السورة الظاهرة الآن.
    private var visibleSurahName: String {
        Quran.surah(visibleSurahId)?.name ?? ""
    }

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// لوحة التفسير الجانبية على الشاشات العريضة (iPad): تتبع الآية المختارة أو موضع القراءة.
    @State private var sidePanel = false
    private var panelRef: AyahRef { selected ?? currentRef ?? scrollTo ?? AyahRef(surah: surahId, ayah: 1) }

    /// المصحف نفسه بأوضاعه الثلاثة.
    private var readerCore: some View {
        ZStack {
            palette.paper.ignoresSafeArea()
                .animation(Motion.smooth, value: store.readingTheme)

            if store.readingMode != .ayah {
                MushafPager(
                    startPage: Quran.page(of: currentRef ?? scrollTo ?? AyahRef(surah: surahId, ayah: 1)),
                    palette: palette,
                    scale: store.mushafFontScale,
                    bookmarks: Set(store.bookmarks),
                    highlights: store.highlights,
                    playing: ayahAudio.current,
                    isDark: store.readingTheme == .night,
                    framed: store.readingMode == .framed,
                    bottomInset: bottomReserve,
                    onTapAyah: { selected = $0 },
                    onPageVisible: { page in
                        let ref = Quran.firstAyah(ofPage: page)
                        store.lastRead = ref
                        store.noteReaderPage(page)          // الختمة تتقدّم بالقراءة
                        if lastCountedPage != page { lastCountedPage = page; store.notePageRead() }
                        if (293...304).contains(page), Calendar.current.component(.weekday, from: Date()) == 6 { store.noteKahfRead() }
                        currentRef = ref
                    })
            } else {
                ayahModeBody
            }
        }
    }

    /// لوحة التفسير الجانبية (iPad).
    private var tafsirPanel: some View {
        HStack(spacing: 0) {
            Divider()
            TafsirSheet(ref: panelRef, inline: true)
                .id(panelRef)
                .frame(width: 400)
        }
    }

    var body: some View {
        // مقسوم إلى أجزاء صغيرة: تعبير واحد كبير كان يُعجز المُحلِّل عن تحديد نوعه.
        HStack(spacing: 0) {
            readerCore
            if sizeClass == .regular && sidePanel { tafsirPanel }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 6) {
                if ayahAudio.isActive { AyahPlayerBar(audio: ayahAudio, palette: palette) }
                MiniPlayer()
                // سطحٌ واحد يطفو أثناء التلاوة: كانت الكبسولة تحت المشغّل بفجوة ٦ نقاط
                // يظهر فيها نصّ الآية مقطوعًا ويلتفّ حولها. الجزء والصفحة يبقيان في
                // وضع «صفحة» برقم الصفحة، وفي المشغّل الكامل.
                if audio.surah == nil && !ayahAudio.isActive { positionBar }
            }
            .background(alignment: .bottom) {
                // شريط التبويب مخفيّ هنا، فلا شيء يغطّي شريط مؤشّر الرئيسية: كانت
                // الآيات تمرّ تحت المشغّل ثم تعود ظاهرةً أسفله. تدرّجٌ بلون الورق
                // يذيبها تحت الشريط ويمتدّ إلى حافة الشاشة.
                LinearGradient(colors: [palette.paper.opacity(0), palette.paper],
                               startPoint: .top, endPoint: .bottom)
                    .padding(.top, -28)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
            }
        }
        // عالمٌ لونيّ واحد: التطبيق قد يكون داكنًا والورق فاتحًا، فألوان المشغّل
        // المصغّر «المتكيّفة» كانت تُحَلّ على سِمة التطبيق لا على الورق (بطاقة سوداء
        // فوق ورقٍ كريمي). المحتوى والشريط السفلي يتبعان سِمة القراءة؛ الأوراق
        // المنبثقة خارج هذا النطاق فتبقى على سِمة التطبيق.
        .environment(\.colorScheme, store.readingTheme == .night ? .dark : .light)
        .navigationTitle(loc("سورة %1$@", visibleSurahName))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showControls = true } label: {
                    Image(systemName: "textformat.size")
                }
                .accessibilityLabel(loc("ضوابط القراءة"))
            }
            if sizeClass == .regular {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation(Motion.snappy) { sidePanel.toggle() } } label: {
                        Image(systemName: sidePanel ? "sidebar.trailing" : "sidebar.trailing")
                            .symbolVariant(sidePanel ? .fill : .none)
                    }
                    .accessibilityLabel(sidePanel ? loc("إخفاء لوحة التفسير") : loc("لوحة التفسير جانبًا"))
                }
            }
            // تلاوة آية بآية مع تظليل الموضع — للتدبّر والحفظ (everyayah.com).
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let start = currentRef ?? AyahRef(surah: surahId, ayah: 1)
                        ayahAudio.play(from: start)
                    } label: { Label(loc("استماع آية بآية من هنا"), systemImage: "text.line.first.and.arrowtriangle.forward") }
                    Menu {
                        ForEach(AyahReciters.all) { r in
                            Button { ayahAudio.reciterId = r.id } label: {
                                if ayahAudio.reciterId == r.id { Label(r.name, systemImage: "checkmark") } else { Text(r.name) }
                            }
                        }
                    } label: { Label(loc("القارئ: %1$@", ayahAudio.reciter.name), systemImage: "person.wave.2") }
                    Menu {
                        ForEach([1, 3, 5, 10], id: \.self) { n in
                            Button { ayahAudio.repeatCount = n } label: {
                                let t = n == 1 ? loc("مرة واحدة") : loc("%1$@ مرات", n.counterText)
                                if ayahAudio.repeatCount == n { Label(t, systemImage: "checkmark") } else { Text(t) }
                            }
                        }
                    } label: { Label(loc("تكرار كل آية"), systemImage: "repeat") }
                } label: {
                    Image(systemName: "waveform.and.mic")
                }
                .accessibilityLabel(loc("تلاوة آية بآية"))
            }
            // استماعٌ للسورة المفتوحة — بثًّا أو من التنزيل إن كانت محمَّلة.
            ToolbarItem(placement: .topBarTrailing) {
                let playing = audio.surah == visibleSurahId && audio.isPlaying
                Button { audio.toggle(surah: visibleSurahId) } label: {
                    Image(systemName: playing ? "pause.circle" : "play.circle")
                }
                .accessibilityLabel(playing ? loc("إيقاف التلاوة مؤقتًا") : loc("تشغيل تلاوة السورة"))
            }
        }
        .sheet(isPresented: $showControls) {
            // ارتفاعٌ ثانٍ كبير: معاينة البسملة تكبر مع المكبِّر وحجم النظام،
            // فلولاه انقطعت سِمة الصفحة أسفل الورقة ولم يبلغها القارئ.
            ReaderControls().presentationDetents([.height(430), .large])
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
        .sheet(item: $selected) { ref in
            AyahActions(ref: ref).presentationDetents([.medium, .large])
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
        // خلفية الشريط بلون الورق وظاهرة: بلا خلفيةٍ ظاهرة لا يقود toolbarColorScheme
        // شريطَ الحالة، فتُرسم الساعة والبطارية بيضاء على ورقٍ كريمي حين يكون
        // التطبيق داكنًا. الشكل لا يتغيّر، وشريط الحالة يتبع سِمة القراءة.
        .toolbarBackground(palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(store.readingTheme == .night ? .dark : .light, for: .navigationBar)
        // القارئ يُمسك المصحف دقائق دون لمس — لا تنطفئ الشاشة عليه.
        .onAppear {
            ReaderWake.enter()
            store.readerScheme = store.readingTheme == .night ? .dark : .light
        }
        .onDisappear {
            ReaderWake.exit()
            store.readerScheme = .none
            // تلاوة الآية بالآية تخصّ المصحف المفتوح: بلا هذا استمرّ الصوت بعد الخروج بلا زرّ يوقفه.
            ayahAudio.stop()
            TafsirSpeaker.shared.stop()
        }
        .onChange(of: store.readingTheme) { _, t in store.readerScheme = t == .night ? .dark : .light }
    }

    // MARK: عرض آية آية (تمرير عمودي)

    private var ayahModeBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    header
                    if let surah, surah.hasBasmalah, surah.id != 1 {
                        Text(Quran.basmalah)
                            .font(Theme.dhikrFont(size: 22, scale: store.mushafFontScale))
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    }

                    AyahListPage(surahId: activeSurahId, palette: palette,
                                 scale: store.mushafFontScale,
                                 bookmarks: Set(store.bookmarks),
                                 highlights: store.highlights,
                                 playing: ayahAudio.current,
                                 isDark: store.readingTheme == .night,
                                 onTapAyah: { selected = $0 },
                                 onVisible: {
                                     store.lastRead = $0
                                     store.noteReaderPage(Quran.page(of: $0))   // الختمة تتقدّم بالقراءة
                                     currentRef = $0
                                 })

                    endOfSurah
                }
                // هامش الحافّة الموحّد، ليقع عمود الآيات على حافّة المشغّل المصغّر نفسها.
                .padding(.horizontal, Theme.gutter)
                .padding(.bottom, 60 + bottomReserve)
                .readableWidth(700)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                // الموضع الحيّ أولًا ليصل التبديل من «صفحة» إلى الآية نفسها.
                if let t = currentRef ?? scrollTo {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        // القائمة تسجّل أرقام الآيات (Int) لا AyahRef،
                        // فالقفز بالمرجع نفسه لا يطابق شيئًا ولا يحدث شيء.
                        withAnimation(Motion.smooth) { proxy.scrollTo(t.ayah, anchor: .center) }
                    }
                }
            }
        }
    }

    /// شريط الموضع: الصفحة والجزء ونسبة التقدّم في المصحف كله.
    private var positionBar: some View {
        let ref = currentRef ?? AyahRef(surah: surahId, ayah: 1)
        let page = Quran.page(of: ref)
        let juz = Quran.juz(of: ref)
        let pct = Int((Double(page) / Double(Quran.pageCount) * 100).rounded())
        return HStack(spacing: Theme.Space.sm) {
            Text(loc("الجزء %1$@", juz.counterText))
                .foregroundStyle(palette.accent)
            posDivider
            Text(loc("صفحة %1$@ من %2$@", page.counterText, Quran.pageCount.counterText))
            posDivider
            Text("\(pct.counterText)٪")
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        // الحبر الثاني لا الخافت: هذا موضع القارئ لا زخرفة، فلا بدّ أن يُقرأ.
        .foregroundStyle(palette.secondary)
        .monospacedDigit()
        .padding(.horizontal, Theme.Space.lg).padding(.vertical, 9)
        .background(
            Capsule().fill(
                LinearGradient(colors: [palette.paper.opacity(0.98), palette.paper.opacity(0.9)],
                               startPoint: .top, endPoint: .bottom))
        )
        .overlay(Capsule().strokeBorder(palette.hairline, lineWidth: 1))
        .atharElevation(.e1)
        .padding(.bottom, 8)
        .animation(Motion.snappy, value: page)
    }

    /// نقطة فاصلة ناعمة بين حقول شريط الموضع.
    private var posDivider: some View {
        Circle().fill(palette.faint.opacity(0.4)).frame(width: 3, height: 3)
    }

    private var header: some View {
        VStack(spacing: 8) {
            if let surah {
                Text(surah.name)
                    .font(Theme.display(26, weight: .bold))
                    .foregroundStyle(palette.ink)

                // خيط زخرفيّ بنجمة — بلون القراءة، لا ينافس الاسم
                HStack(spacing: 7) {
                    Rectangle()
                        .fill(LinearGradient(colors: [palette.accent.opacity(0.45), palette.accent.opacity(0)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 44, height: 1)
                    EightPointStar(innerRatio: 0.6)
                        .fill(palette.accent.opacity(0.55))
                        .frame(width: 7, height: 7)
                    Rectangle()
                        .fill(LinearGradient(colors: [palette.accent.opacity(0), palette.accent.opacity(0.45)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: 44, height: 1)
                }

                Text("\(surah.revelation) · \(surah.ayahCount.ayahCountText)")
                    .font(Theme.display(12, weight: .medium))
                    .foregroundStyle(palette.secondary)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(palette.accent.opacity(0.10)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var endOfSurah: some View {
        VStack(spacing: 12) {
            // فاصل ختام بنجمة زخرفيّة تتلاشى في الطرفين
            HStack(spacing: 8) {
                Rectangle()
                    .fill(LinearGradient(colors: [palette.hairline.opacity(0), palette.accent.opacity(0.4)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                EightPointStar(innerRatio: 0.6)
                    .fill(palette.accent.opacity(0.4))
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(LinearGradient(colors: [palette.accent.opacity(0.4), palette.hairline.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            .padding(.vertical, 20)

            if activeSurahId < 114, let next = Quran.surah(activeSurahId + 1) {
                NavigationLink { SurahReaderView(surahId: next.id) } label: {
                    HStack(spacing: 8) {
                        Text(loc("سورة %1$@", next.name))
                            .font(Theme.display(15, weight: .semibold))
                        Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, Theme.Space.xl).padding(.vertical, 12)
                    .background(
                        Capsule().fill(
                            LinearGradient(colors: [palette.accent.opacity(0.16), palette.accent.opacity(0.07)],
                                           startPoint: .top, endPoint: .bottom))
                    )
                    .overlay(Capsule().strokeBorder(palette.accent.opacity(0.18), lineWidth: 0.5))
                }
                .pressable()
            } else {
                Text(loc("صدق الله العظيم"))
                    .font(Theme.dhikrFont(size: 17))
                    .foregroundStyle(palette.secondary)
            }
        }
    }
}

// MARK: - قلّاب المصحف

/// مصحف يُقلَّب صفحة صفحة بالسحب — كالمصحف المطبوع تمامًا.
/// الصفحات الـ٦٠٤ بترقيم مصحف المدينة، والنص يجري متصلًا عبر حدود السور،
/// وتظهر فاتحة كل سورة جديدة بعنوانها وبسملتها في موضعها من الصفحة.
struct MushafPager: View {
    let startPage: Int
    let palette: ReadingPalette
    let scale: Double
    let bookmarks: Set<AyahRef>
    let highlights: [String: String]
    /// الآية الجارية في التلاوة آيةً آية — تُظلَّل بلون الطابع.
    var playing: AyahRef? = nil
    let isDark: Bool
    var framed: Bool = false
    /// مساحةٌ إضافية أسفل الصفحة يحجزها المشغّل المصغّر حين تجري التلاوة.
    var bottomInset: CGFloat = 0
    let onTapAyah: (AyahRef) -> Void
    let onPageVisible: (Int) -> Void

    @State private var current: Int?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(1...Quran.pageCount, id: \.self) { page in
                        MushafPageContent(page: page, palette: palette, scale: scale,
                                          bookmarks: bookmarks, highlights: highlights,
                                          playing: playing,
                                          isDark: isDark, framed: framed,
                                          bottomInset: bottomInset, onTapAyah: onTapAyah)
                            .containerRelativeFrame(.horizontal)
                            .id(page)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(startPage, anchor: .center)
                current = startPage
                onPageVisible(startPage)
            }
            .onChange(of: current) { _, page in
                if let page { onPageVisible(page) }
            }
        }
    }
}

/// محتوى صفحة واحدة من المصحف.
private struct MushafPageContent: View {
    let page: Int
    let palette: ReadingPalette
    let scale: Double
    let bookmarks: Set<AyahRef>
    let highlights: [String: String]
    var playing: AyahRef? = nil
    let isDark: Bool
    var framed: Bool = false
    var bottomInset: CGFloat = 0
    let onTapAyah: (AyahRef) -> Void

    /// آيات الصفحة مقسومة أشواطًا: كل شوط سورة واحدة، لتظهر فاتحة
    /// السورة الجديدة في موضعها إن بدأت وسط الصفحة.
    private var runs: [[AyahRef]] {
        var out: [[AyahRef]] = []
        for ref in Quran.ayahs(inPage: page) {
            if var last = out.last, last.first?.surah == ref.surah {
                last.append(ref); out[out.count - 1] = last
            } else {
                out.append([ref])
            }
        }
        return out
    }

    var body: some View {
        // الصفحة لا تقصر عن الشاشة: في الصفحتين القصيرتين (١ و٢) كان رقم الصفحة
        // يقف تحت آخر آية وسط الشاشة كرقاقةٍ ضائعة. حدٌّ أدنى للارتفاع يساوي المتاح
        // ناقص هوامش الفرع (١٢+٧٠ سادة، ١٠+٢٠+١٦+٧٤ مؤطَّرة) وحجزَ المشغّل، فيثبت
        // الرقم في ذيل الصفحة ولا يتغيّر شيء في الصفحات الممتلئة.
        GeometryReader { geo in
            ScrollView {
                if framed {
                    pageStack
                        .frame(minHeight: max(0, geo.size.height - 120 - bottomInset), alignment: .top)
                        .padding(.horizontal, 17)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        .background(MushafFrame(palette: palette))
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 74 + bottomInset)
                        .readableWidth(700)
                } else {
                    pageStack
                        .frame(minHeight: max(0, geo.size.height - 82 - bottomInset), alignment: .top)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 70 + bottomInset)
                        .readableWidth(700)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var pageStack: some View {
            VStack(spacing: 14 * scale) {
                ForEach(runs, id: \.first) { run in
                    if let first = run.first, first.ayah == 1 {
                        surahHeader(first.surah)
                    }
                    FlowLayout(lineSpacing: 14 * scale, wordSpacing: 5 * scale) {
                        ForEach(tokens(of: run)) { tokenView($0) }
                    }
                    // جوهري: FlowLayout يرصّ من اليمين يدويًا، وبيئة RTL
                    // تعكسه تلقائيًا — فيثبَّت LTR هنا وإلا انقلب النص.
                    .environment(\.layoutDirection, .leftToRight)
                    // قارئ الشاشة كان يمشي على كلّ كلمة عنصرًا مستقلًّا بترتيب هندسي
                    // معكوس (بسبب التثبيت LTR) وبلا سمة زرّ؛ فيُقدَّم له بدلها
                    // زرٌّ واحد لكلّ آية بترتيب الآي، مستقلًّا عن هندسة الرصّ.
                    .accessibilityRepresentation {
                        VStack {
                            ForEach(run, id: \.id) { ref in
                                Button(Quran.text(ref) ?? "") { onTapAyah(ref) }
                                    .accessibilityLabel(loc("%1$@ — الآية %2$@", Quran.text(ref) ?? "", ref.ayah.counterText))
                                    .accessibilityHint(loc("يفتح خيارات الآية"))
                            }
                        }
                    }
                }

                // يدفع رقم الصفحة إلى ذيلها حين تقصر (مع الحدّ الأدنى للارتفاع أعلاه).
                Spacer(minLength: 6)

                Text(page.counterText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(palette.secondary)
                    .monospacedDigit()
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(palette.ink.opacity(0.04)))
                    .overlay(Capsule().strokeBorder(palette.hairline.opacity(0.6), lineWidth: 0.5))
                    .accessibilityLabel(loc("صفحة %1$@", page.counterText))
            }
    }

    /// فاتحة سورة تبدأ في هذه الصفحة: إطار مزخرف بالاسم ثم البسملة.
    @ViewBuilder
    private func surahHeader(_ id: Int) -> some View {
        if let su = Quran.surah(id) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ornamentLine
                    EightPointStar(innerRatio: 0.6)
                        .fill(palette.accent.opacity(0.55))
                        .frame(width: 7, height: 7)
                    Text(loc("سُورَةُ %1$@", su.name))
                        .font(Theme.naskhFont(size: 18, bold: true))
                        .foregroundStyle(palette.accent)
                        .lineLimit(1)
                        .fixedSize()
                    EightPointStar(innerRatio: 0.6)
                        .fill(palette.accent.opacity(0.55))
                        .frame(width: 7, height: 7)
                    ornamentLine
                }
                if su.hasBasmalah, su.id != 1 {
                    Text(Quran.basmalah)
                        .font(Theme.dhikrFont(size: 20, scale: min(scale, 1.4)))
                        .foregroundStyle(palette.ink.opacity(0.85))
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var ornamentLine: some View {
        Rectangle()
            .fill(LinearGradient(colors: [palette.accent.opacity(0), palette.accent.opacity(0.6)],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(height: 1.2)
    }

    // — الوحدات: كما في العرض السابق —

    private struct Token: Identifiable {
        let id: String
        let text: String
        let ref: AyahRef
        let isMarker: Bool
        let isSajdah: Bool
        var number: Int = 0
        /// ترتيب الكلمة في آيتها وعددها — لوضع الحفظ.
        var wordIndex: Int = 0
        var wordCount: Int = 0
    }

    @EnvironmentObject private var store: AtharStore
    /// الآيات التي كشفها القارئ بالنقر في وضع الحفظ (تُنسى مع الصفحة).
    @State private var revealed: Set<String> = []

    /// هل تُخفى هذه الكلمة؟ ثابتٌ للآية نفسها كي لا يتغيّر بين الرسمات.
    private func isHidden(_ t: Token) -> Bool {
        guard !t.isMarker, !t.isSajdah, !revealed.contains(t.ref.id) else { return false }
        switch store.hifzHide {
        case .off:   return false
        case .words: return t.wordCount >= 3 && (t.wordIndex + t.ref.ayah) % 3 == 2
        case .ends:  return t.wordCount >= 3 && t.wordIndex >= Int(Double(t.wordCount) * 0.6)
        }
    }

    private func tokens(of run: [AyahRef]) -> [Token] {
        var out: [Token] = []
        for ref in run {
            let words = (Quran.text(ref) ?? "").ayahWords
            for (i, w) in words.enumerated() {
                out.append(Token(id: "\(ref.id)-w\(i)", text: w, ref: ref,
                                 isMarker: false, isSajdah: false, wordIndex: i, wordCount: words.count))
            }
            if Quran.isSajdah(ref) {
                out.append(Token(id: "\(ref.id)-sj", text: "۩", ref: ref,
                                 isMarker: false, isSajdah: true))
            }
            out.append(Token(id: "\(ref.id)-m", text: "", ref: ref,
                             isMarker: true, isSajdah: false, number: ref.ayah))
        }
        return out
    }

    @ViewBuilder
    private func tokenView(_ t: Token) -> some View {
        let hl = highlights[t.ref.id].flatMap(HighlightColor.init(rawValue:))
        let hidden = isHidden(t)
        Group {
            if t.isMarker {
                AyahMedallion(number: t.number, size: 26 * scale, tint: palette.accent)
            } else {
                Text(t.text)
                    .font(Theme.dhikrFont(size: 23, scale: scale))
                    .foregroundStyle(t.isSajdah ? palette.accent : palette.ink)
                    // الكلمة المخفيّة تبقى بحجمها (فلا يتغيّر رصّ السطر) وتُغطّى بلوحٍ ناعم.
                    .opacity(hidden ? 0 : 1)
                    .overlay {
                        if hidden {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(palette.accent.opacity(0.14))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(palette.accent.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                        }
                    }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(t.ref == playing ? palette.accent.opacity(0.18) : (hl?.color(dark: isDark) ?? .clear))
        )
        .overlay(alignment: .topLeading) {
            if t.isMarker, bookmarks.contains(t.ref) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(palette.accent)
                    .offset(x: -2, y: -3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            // في وضع الحفظ: النقرة الأولى تكشف الآية، والثانية تفتح خياراتها.
            if store.hifzHide != .off, !revealed.contains(t.ref.id) {
                withAnimation(Motion.snappy) { _ = revealed.insert(t.ref.id) }
            } else {
                onTapAyah(t.ref)
            }
        }
    }
}

// MARK: - ضوابط القراءة

struct ReaderControls: View {
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AtharBackground()
            // المحتوى يطول مع مكبِّر الخطّ ومع حجم نصّ النظام، فبلا تمرير
            // تُقتطع «سِمة الصفحة» أسفل الورقة ولا سبيل للوصول إليها.
            ScrollView {
                VStack(spacing: 22) {
                    Capsule().fill(Theme.hairline).frame(width: 36, height: 5).padding(.top, 10)

                    VStack(spacing: 12) {
                        HStack {
                            Text(loc("readerFont")).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                            Spacer()
                            Text(String(format: "%.0f٪", store.mushafFontScale * 100))
                                .font(Theme.display(14)).foregroundStyle(Theme.inkSoft).monospacedDigit()
                        }
                        HStack(spacing: 12) {
                            Button { bump(-0.1) } label: { stepper("textformat.size.smaller") }
                                .accessibilityLabel(loc("تصغير الخط"))
                            Slider(value: Binding(get: { store.mushafFontScale },
                                                  set: { store.mushafFontScale = $0 }),
                                   in: 0.7...2.2, step: 0.05)
                                .tint(Theme.accent)
                                .accessibilityLabel(loc("readerFont"))
                            Button { bump(0.1) } label: { stepper("textformat.size.larger") }
                                .accessibilityLabel(loc("تكبير الخط"))
                        }
                        Text(loc("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"))
                            .font(Theme.dhikrFont(size: 21, scale: store.mushafFontScale))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surfaceAlt))
                            .animation(Motion.snappy, value: store.mushafFontScale)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(loc("displayMode")).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                        HStack(spacing: 10) {
                            ForEach(ReadingMode.allCases) { mode in
                                let on = store.readingMode == mode
                                Button {
                                    store.readingMode = mode
                                    Haptics.tap(enabled: store.hapticsEnabled)
                                } label: {
                                    HStack(spacing: 7) {
                                        Image(systemName: mode.icon).font(.system(size: 14))
                                        Text(mode.title).font(Theme.display(14, weight: on ? .semibold : .regular))
                                    }
                                    .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(on ? Theme.accent : Theme.surfaceAlt))
                                }
                                .pressable()
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }

                    // وضع الحفظ: يخفي بعض الكلمات فيُسمّع القارئ نفسه، والنقر على الآية يكشفها.
                    VStack(alignment: .leading, spacing: 10) {
                        Text(loc("وضع الحفظ")).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                        HStack(spacing: 10) {
                            ForEach(HifzHide.allCases) { h in
                                let on = store.hifzHide == h
                                Button {
                                    store.hifzHide = h
                                    Haptics.tap(enabled: store.hapticsEnabled)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: h.icon).font(.system(size: 13))
                                        Text(h.title).font(Theme.display(13, weight: on ? .semibold : .regular))
                                    }
                                    .foregroundStyle(on ? Theme.onAccent : Theme.inkSoft)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(on ? Theme.accent : Theme.surfaceAlt))
                                }
                                .pressable()
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                        Text(loc("المخفيّ يظهر بالنقر على آيته — ومع التكرار الصوتي يصير الحفظ تدريبًا."))
                            .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(loc("pageTheme")).font(Theme.display(15, weight: .semibold)).foregroundStyle(Theme.ink)
                        HStack(spacing: 10) {
                            ForEach(ReadingTheme.allCases) { theme in
                                themeChip(theme)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
    }

    private func bump(_ d: Double) {
        store.mushafFontScale = max(0.7, min(2.2, store.mushafFontScale + d))
        Haptics.tap(enabled: store.hapticsEnabled)
    }

    private func stepper(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(Theme.inkSoft)
            .frame(width: 38, height: 34)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surfaceAlt))
            // هدف اللمس ٤٤ نقطة حول زرٍّ رسمُه ٣٨×٣٤.
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    private func themeChip(_ theme: ReadingTheme) -> some View {
        let p = ReadingPalette.of(theme)
        let on = store.readingTheme == theme
        return Button {
            store.readingTheme = theme
            Haptics.tap(enabled: store.hapticsEnabled)
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(p.paper)
                    Text("ٱ").font(.system(size: 21)).foregroundStyle(p.ink)
                }
                .frame(height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(on ? Theme.accent : Theme.hairline, lineWidth: on ? 2 : 1)
                )
                Text(theme.title)
                    .font(Theme.display(12, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Theme.accent : Theme.inkSoft)
            }
        }
        // كرقائق وضع العرض المجاورة: انضغاطة واحدة لكلّ رقاقة حرّة في الورقة.
        .pressable()
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - إجراءات الآية

struct AyahActions: View {
    @Environment(\.colorScheme) private var actionScheme

    @ViewBuilder
    fileprivate func infoChip(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(Theme.display(12, weight: .medium))
        }
        .foregroundStyle(Theme.gold)
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(
            Capsule().fill(Theme.gold.opacity(0.12))
                .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.22), lineWidth: 0.5))
        )
    }

    let ref: AyahRef
    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @State private var showTafsir = false
    @State private var shareImage: UIImage?

    private var text: String { Quran.text(ref) ?? "" }
    private var surahName: String { Quran.surah(ref.surah)?.name ?? "" }

    /// «وقفتُ هنا» — زرّ ذهبيّ بارز (متدرّج حين يُوضَع، ناعم حين يُرفَع).
    @ViewBuilder
    private var stopMarkButton: some View {
        let stopped = store.stopMark == ref
        VStack(spacing: 6) {
            Button {
                store.stopMark = stopped ? nil : ref
                Haptics.done(enabled: store.hapticsEnabled)
                dismiss()
            } label: {
                if stopped {
                    HStack(spacing: 8) {
                        Image(systemName: "pin.slash.fill")
                        Text(loc("إزالة علامة الوقوف"))
                    }
                    .font(Theme.display(16, weight: .semibold))
                    .softButton(Theme.gold)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "pin.fill")
                        Text(loc("وقفتُ هنا"))
                    }
                    .font(Theme.display(16, weight: .semibold))
                    .gradientButton(Theme.goldGradient, glow: Theme.gold)
                }
            }
            .pressable()

            if !stopped {
                Text(loc("علامة تعود إليها من شاشة المصحف"))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
    }

    var body: some View {
        ZStack {
            AtharBackground()
            // القائمة تطول مع حجم نصّ النظام وطول الآية، والورقة تُفتح على الارتفاع
            // المتوسط؛ فبلا تمرير تُدفن «العلامة» و«الحفظ» و«المشاركة» تحت الحافة.
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    Capsule().fill(Theme.hairline).frame(width: 36, height: 5).padding(.top, 10)

                    // بطاقة الآية — سطح وعمق، والنصّ الشرعي سيّدها
                    AtharCard(padding: Theme.Space.lg, elevation: .e2) {
                        VStack(spacing: Theme.Space.md) {
                            // خيط ذهبي علوي — كحاشية المصحف المذهّبة
                            Capsule().fill(Theme.goldGradient)
                                .frame(width: 46, height: 3)
                                .opacity(0.8)

                            Text("\(surahName) · الآية \(ref.ayah.counterText)")
                                .font(Theme.display(13, weight: .semibold))
                                .foregroundStyle(Theme.accent)

                            Text(text)
                                .font(Theme.dhikrFont(size: 19))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(10)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)

                            // معلومات الموضع — ذهبية أنيقة، مكية/مدنية والجزء والصفحة
                            if let su = Quran.surah(ref.surah) {
                                HStack(spacing: Theme.Space.sm) {
                                    infoChip(su.revelation, icon: su.isMakki ? "cube.fill" : "building.2.fill")
                                    infoChip(loc("الجزء %1$@", Quran.juz(of: ref).counterText), icon: "book.closed.fill")
                                    infoChip(loc("صفحة %1$@", Quran.page(of: ref).counterText), icon: "doc.plaintext.fill")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // التفسير — أوّل ما يُطلب بعد قراءة الآية، فيتقدّم التظليل والعلامات.
                    Button {
                        Haptics.tap(enabled: store.hapticsEnabled)
                        showTafsir = true
                    } label: {
                        AtharLinkRow(icon: "text.book.closed.fill", tint: Theme.accent(for: "sea"),
                                     title: loc("التفسير"),
                                     subtitle: loc("السعدي والجلالين — معنى الآية وبيانها"))
                    }
                    .pressable()

                    // استماع من هذه الآية آيةً آية — للحفظ بالتكرار.
                    Button {
                        AyahAudio.shared.play(from: ref)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            IconChip(icon: "waveform.and.mic", tint: Theme.accent(for: "dusk"), size: .md)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc("استمع من هذه الآية")).font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(loc("آيةً آية مع تظليل الموضع — والتكرار للحفظ")).font(Theme.display(12)).foregroundStyle(Theme.inkFaint)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "play.fill").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent(for: "dusk"))
                        }
                        .padding(14)
                        .background(CardSurface(radius: Theme.Radius.lg))
                        .contentShape(Rectangle())
                    }
                    .pressable()

                    // ألوان التظليل — كما يُظلّل القارئ في مصحفه الورقي
                    VStack(alignment: .leading, spacing: 8) {
                        Text(loc("تظليل الآية"))
                            .font(Theme.display(12, weight: .semibold))
                            .foregroundStyle(Theme.inkFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // الدوائر ٣٤ نقطة وهدف اللمس ٤٤؛ فتضيق المسافة كي لا يتباعد الصف.
                        HStack(spacing: 4) {
                            ForEach(HighlightColor.allCases) { c in
                                let on = store.highlight(ref) == c
                                Button {
                                    store.setHighlight(on ? nil : c, for: ref)
                                    Haptics.tap(enabled: store.hapticsEnabled)
                                } label: {
                                    Circle()
                                        .fill(c.color(dark: actionScheme == .dark))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle().stroke(on ? Theme.ink : Theme.hairline,
                                                            lineWidth: on ? 2.5 : 1)
                                        )
                                        .overlay {
                                            if on {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundStyle(Theme.ink)
                                            }
                                        }
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .pressable(scale: 0.9)
                                .accessibilityLabel(c.title)
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }

                            if store.highlight(ref) != nil {
                                Button {
                                    store.setHighlight(nil, for: ref)
                                    Haptics.tap(enabled: store.hapticsEnabled)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.inkSoft)
                                        .frame(width: 34, height: 34)
                                        .background(Circle().fill(Theme.surfaceAlt))
                                        .frame(minWidth: 44, minHeight: 44)
                                        .contentShape(Rectangle())
                                }
                                .pressable(scale: 0.9)
                                .accessibilityLabel(loc("إزالة التظليل"))
                                .transition(.scale.combined(with: .opacity))
                            }
                            Spacer()
                        }
                    }
                    .animation(Motion.snappy, value: store.highlight(ref))

                    // علامة الوقوف — الإجراء الأبرز، ذهبيّ أنيق
                    stopMarkButton

                    SettingsCard {
                        Button {
                            store.toggleBookmark(ref)
                            Haptics.tap(enabled: store.hapticsEnabled)
                            dismiss()
                        } label: {
                            SettingsRow(icon: store.isBookmarked(ref) ? "bookmark.slash.fill" : "bookmark.fill",
                                        tint: Theme.gold,
                                        title: store.isBookmarked(ref) ? loc("إزالة العلامة") : loc("وضع علامة"))
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()
                        if store.card(for: ref) != nil {
                            // المضافة سلفًا تُزال من هنا: كان الصف يُعطَّل فلا مخرج من الحفظ
                            // في التطبيق كلّه، ولا حتى «تصفير الإحصائيات» يمسّ البطاقات.
                            Button(role: .destructive) {
                                store.forget(ref)
                                Haptics.tap(enabled: store.hapticsEnabled)
                                dismiss()
                            } label: {
                                SettingsRow(icon: "brain.head.profile", tint: Theme.danger,
                                            title: loc("إزالة من الحفظ"),
                                            subtitle: loc("مضافة — للمراجعة"))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                // بطاقةٌ جديدة موعدها اليوم — كما تُضيف شاشة الحفظ تمامًا.
                                // لا مراجعةً راسبة: تلك تُولَد بـ «تعثّرت فيها ١ مرة» في
                                // آيةٍ لم تُعرض بعد، ولا ناجحة: تلك تزعم حفظًا لم يقع.
                                store.enroll([ref])
                                Haptics.done(enabled: store.hapticsEnabled)
                                dismiss()
                            } label: {
                                SettingsRow(icon: "brain.head.profile", tint: Theme.accent(for: "sea"),
                                            title: loc("أضِف إلى الحفظ"))
                            }
                            .buttonStyle(.plain)
                        }

                        SettingsDivider()
                        // مشاركة صورة: بطاقة بخطّ المصحف وسطر من تفسير السعدي — تُصيَّر عند الطلب لا في كل رسمة.
                        if let img = shareImage {
                            ShareLink(item: Image(uiImage: img), preview: SharePreview(loc("آية %1$@ من %2$@", ref.ayah.counterText, surahName), image: Image(uiImage: img))) {
                                SettingsRow(icon: "photo.on.rectangle.angled", tint: Theme.accent(for: "sea"), title: loc("مشاركة كصورة"), subtitle: loc("جاهزة — اضغط للمشاركة"))
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                let snippet = Tafsir.entry(.saadi, for: ref).map { e -> String in
                                    let clean = e.text.replacingOccurrences(of: "{", with: "﴿").replacingOccurrences(of: "}", with: "﴾")
                                    return clean.count > 220 ? String(clean.prefix(220)).trimmingCharacters(in: .whitespaces) + "…" : clean
                                }
                                shareImage = AyahShareCard.render(ref: ref, tafsir: snippet, scheme: actionScheme)
                            } label: {
                                SettingsRow(icon: "photo.on.rectangle.angled", tint: Theme.accent(for: "sea"), title: loc("مشاركة كصورة"), subtitle: loc("بطاقة بخط المصحف مع سطر من التفسير"))
                            }
                            .buttonStyle(.plain)
                        }
                        ShareLink(item: "\(text)\n\n[\(surahName): \(ref.ayah)]\n\nمن تطبيق أثر") {
                            SettingsRow(icon: "square.and.arrow.up.fill", tint: Theme.accent, title: loc("مشاركة الآية"))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showTafsir) {
            TafsirSheet(ref: ref)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
        }
    }
}

// MARK: - عرض آية آية

/// كل آية في بطاقتها — أوضح للقراءة المتأنّية والتدبّر والتظليل.
struct AyahListPage: View {
    let surahId: Int
    let palette: ReadingPalette
    let scale: Double
    let bookmarks: Set<AyahRef>
    let highlights: [String: String]
    var playing: AyahRef? = nil
    let isDark: Bool
    let onTapAyah: (AyahRef) -> Void
    let onVisible: (AyahRef) -> Void

    private var surah: Surah? { Quran.surah(surahId) }

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(1...(surah?.ayahCount ?? 1), id: \.self) { n in
                let ref = AyahRef(surah: surahId, ayah: n)
                let hl = highlights[ref.id].flatMap(HighlightColor.init(rawValue:))

                HStack(alignment: .top, spacing: 12) {
                    AyahMedallion(number: n, size: 30 * min(scale, 1.3), tint: palette.accent)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(Quran.text(ref) ?? "")
                            .font(Theme.dhikrFont(size: 23, scale: scale))
                            .foregroundStyle(palette.ink)
                            .lineSpacing(14 * scale)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if Quran.isSajdah(ref) {
                            Label(loc("موضع سجدة"), systemImage: "figure.and.child.holdinghands")
                                .font(Theme.display(11, weight: .medium))
                                .foregroundStyle(palette.accent)
                        }
                    }

                    if bookmarks.contains(ref) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(palette.accent)
                            .padding(.top, 6)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(ref == playing ? palette.accent.opacity(0.16) : (hl?.color(dark: isDark) ?? palette.ink.opacity(0.03)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .strokeBorder(palette.hairline.opacity(0.6), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .onTapGesture { onTapAyah(ref) }
                // البطاقة عنصر واحد لقارئ الشاشة بسمة زرّ، لا ميدالية ونصّ وعلامة متفرّقة.
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(loc("يفتح خيارات الآية"))
                .onAppear { onVisible(ref) }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - إطار صفحة المصحف

/// إطار الصفحة المزخرف كالمصحف المطبوع — خطّان ووُريدات في الأركان،
/// مرسومة كلّها هنا (لا صور مصحف منسوخة)، فتتبع سِمة القراءة وتعمل بلا إنترنت.
struct MushafFrame: View {
    let palette: ReadingPalette

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: 8, style: .continuous)
        ZStack {
            outer.fill(palette.ink.opacity(0.02))
            outer.strokeBorder(palette.accent.opacity(0.50), lineWidth: 1.6)
            inner.strokeBorder(palette.accent.opacity(0.28), lineWidth: 0.8).padding(5)
        }
        .overlay(alignment: .topLeading)     { rosette }
        .overlay(alignment: .topTrailing)    { rosette }
        .overlay(alignment: .bottomLeading)  { rosette }
        .overlay(alignment: .bottomTrailing) { rosette }
    }

    private var rosette: some View {
        EightPointStar(innerRatio: 0.55)
            .fill(palette.accent.opacity(0.42))
            .frame(width: 11, height: 11)
            .padding(7)
    }
}

