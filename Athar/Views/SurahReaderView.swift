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

    /// اليقظة تلزم التطبيقَ الظاهرَ فقط: قفل الشاشة أو الانتقال إلى تطبيق آخر لا يُطلق
    /// onDisappear، فيُعاد المؤقّت عند مغادرة الواجهة ويُردّ بحسب العدّاد عند العودة —
    /// لا ينتظر خروج القارئ. يُسجَّل مرّة واحدة عند أول دخول.
    private static let lifecycle: [NSObjectProtocol] = {
        let center = NotificationCenter.default
        return [
            center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
                UIApplication.shared.isIdleTimerDisabled = false
            },
            center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { _ in
                UIApplication.shared.isIdleTimerDisabled = depth > 0
            },
        ]
    }()

    static func enter() {
        _ = lifecycle
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
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var audio = Recitation.shared
    @StateObject private var ayahAudio = AyahAudio.shared
    @State private var showControls = false
    /// هل القارئ معروضٌ فعلًا؟ (لا يكفي بقاؤه حيًّا في تبويب غير مختار)
    @State private var isShown = false
    @State private var selected: AyahRef? = nil
    @State private var currentRef: AyahRef?
    @State private var lastCountedPage: Int?
    /// «اذهب إلى صفحة»: القارئ يذكر رقم صفحته، فلا يُكلَّف تقريبَ الصورة وسحبَ
    /// الصفحات حتى يبلغها.
    @State private var showGoToPage = false
    /// الصفحة المطلوبة — يستهلكها القلّاب (أو عرضُ الآيات) ثم تُفرَّغ، فيصحّ
    /// طلبُ الصفحة نفسها مرّتين بعد أن يُقلّب عنها.
    @State private var jumpPage: Int?

    /// السورة الفاعلة الآن — تتبع موضع القراءة الحيّ لا السورة التي فُتح بها
    /// القارئ، وإلا ارتدّ التبديل بين «صفحة» و«آية آية» إلى أول سورةٍ فُتحت
    /// وضاع موضع القارئ بعد تقليب عشرات الصفحات.
    private var activeSurahId: Int { (currentRef ?? scrollTo)?.surah ?? surahId }

    private var surah: Surah? { Quran.surah(activeSurahId) }
    /// الآيات التي كتب عليها القارئ تدبّرًا — لعلامةٍ خفيفة في هامش الصفحة.
    private var noted: Set<AyahRef> { Set(store.notedRefs) }
    /// بين العشاء والفجر يُقرأ على ورق الليل إن فعّل المستخدم الوضع الليلي التلقائي.
    private var effectiveTheme: ReadingTheme { store.readingThemeAuto && store.isNightNow() ? .night : store.readingTheme }
    private var palette: ReadingPalette { .of(effectiveTheme) }

    /// ارتفاعات الشريط السفلي: شريط الموضع (صار زرًّا يفتح «اذهب إلى صفحة»، فهدف
    /// لمسه ٤٤ نقطة وتحته ٨)، وبطاقة المشغّل المصغّر، وشريط التلاوة آيةً آية فوقها
    /// (مع فجوة ٦). تُحجز أسفل كل أوضاع القراءة، لأن البطاقة معتمة تغطّي آخر سطرٍ
    /// من الصفحة ورقمَها وزرَّ «سورة التالية». المشغّل وشريط الآية يتبعان حجم خطّ
    /// النظام، فثابتاهما احتياطٌ أوّلي فقط حتى يُقاس الشريط فعلًا.
    static let positionBarHeight: CGFloat = 52
    static let miniPlayerHeight: CGFloat = 86
    static let ayahBarHeight: CGFloat = 62
    /// ارتفاع الشريط السفلي كما قِيس أثناء التلاوة (المشغّل مع شريط الآية إن كان)؛
    /// صفرٌ قبل أوّل قياس فتُستعمل الثوابت أعلاه.
    @State private var measuredReserve: CGFloat = 0
    /// حجز المشغّل: صفرٌ حين لا تلاوة، فلا تتغيّر الصفحة.
    private var bottomReserve: CGFloat {
        guard audio.surah != nil || ayahAudio.isActive else { return 0 }
        if measuredReserve > 0 { return measuredReserve }
        return (audio.surah == nil ? 0 : Self.miniPlayerHeight) + (ayahAudio.isActive ? Self.ayahBarHeight : 0)
    }
    /// ما تُحسب عليه ملاءمة الصفحة: شريط الموضع وحده، لا المشغّل.
    /// كان المشغّل يدخل في الحساب، فإذا شُغّلت التلاوة ضاق المتاح فأُعيدت الملاءمة، فصغُر
    /// الخطّ وأُعيد توزيع السطور تحت عين القارئ — فيضيع موضعه بلا ذنب. الصفحة الآن ثابتة
    /// كما هي، والمشغّل يعلوها؛ وما غطّاه يُبلغ بتمريرةٍ يسيرة (انظر scrollDisabled أدناه).
    private var bottomOverlay: CGFloat { Self.positionBarHeight }

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
    /// حالها من المخزن لا من حالٍ خاصّ بالشاشة: هي وجهٌ من وجوه الشاشة العريضة
    /// يختاره القارئ من الضوابط، فلو كان لزرّ الشريط حالٌ وللضوابط حالٌ لاختلفا عليه.
    private var sidePanel: Bool { store.mushafSpread == .tafsir }
    private var panelRef: AyahRef { selected ?? currentRef ?? scrollTo ?? AyahRef(surah: surahId, ayah: 1) }

    /// عَرضتان متقابلتان: الشاشة العريضة وحدها تحملهما، والهاتف لا يسع إلا واحدة.
    private var twoPages: Bool { sizeClass == .regular && store.mushafSpread == .two }

    /// ما يُحتسب ببلوغ صفحة: تقدّم الختمة، وعدّ الصفحات، وكهف الجمعة. صفحتا
    /// العَرضة تُحتسبان كلتاهما بالترتيب — وإلا وقفت الختمة عند العرض المزدوج
    /// لأنها لا تتقدّم إلا صفحةً صفحة.
    private func countPage(_ page: Int) {
        store.noteReaderPage(page)          // الختمة تتقدّم بالقراءة
        if lastCountedPage != page { lastCountedPage = page; store.notePageRead() }
        // تُحتسب الكهف عند بلوغ آخر صفحتها لا عند فتح أولها.
        if page == 304, Calendar.current.component(.weekday, from: Date()) == 6 { store.noteKahfRead() }
    }

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
                    noted: noted,
                    playing: ayahAudio.current,
                    selected: selected,
                    isDark: effectiveTheme == .night,
                    framed: store.readingMode == .framed,
                    spread: twoPages,
                    bottomInset: bottomOverlay,
                    playerOverlay: max(0, bottomReserve - Self.positionBarHeight),
                    jumpTo: $jumpPage,
                    onTapAyah: { selected = $0 },
                    onPageVisible: { page in
                        let ref = Quran.firstAyah(ofPage: page)
                        store.lastRead = ref
                        countPage(page)
                        currentRef = ref
                    },
                    onFacingPage: { countPage($0) })
                    // تبديل العَرضة يبني القلّاب من جديد: هويّة كل بطاقةٍ تصير
                    // هويّة عَرضةٍ لا صفحة، فلولا ذلك بقي على موضعٍ لا وجود له.
                    .id(twoPages)
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
            // يُقاس الشريط كما رُسم فعلًا ويصعد ارتفاعه ليُحجز أسفل الصفحة — بالنمط
            // نفسه الذي تقيس به الصفحةُ ارتفاعَها للملاءمة (PageHeightKey).
            .background(
                GeometryReader { g in
                    Color.clear.preference(key: BottomBarHeightKey.self, value: g.size.height)
                }
            )
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
        .onPreferenceChange(BottomBarHeightKey.self) { h in
            // يُسجَّل أثناء التلاوة فقط: بلا تلاوة يُقاس شريط الموضع وهو ثابتٌ أصلًا.
            if audio.surah != nil || ayahAudio.isActive { measuredReserve = h }
        }
        // عالمٌ لونيّ واحد: التطبيق قد يكون داكنًا والورق فاتحًا، فألوان المشغّل
        // المصغّر «المتكيّفة» كانت تُحَلّ على سِمة التطبيق لا على الورق (بطاقة سوداء
        // فوق ورقٍ كريمي). المحتوى والشريط السفلي يتبعان سِمة القراءة؛ الأوراق
        // المنبثقة خارج هذا النطاق فتبقى على سِمة التطبيق.
        .environment(\.colorScheme, effectiveTheme == .night ? .dark : .light)
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
                    // الزرّ يكتب في المخزن كما تكتب الضوابط: طريقان إلى خيارٍ واحد.
                    Button { withAnimation(Motion.snappy) { store.mushafSpread = sidePanel ? .one : .tafsir } } label: {
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
            // سعة الشاشة تُمرَّر من القارئ: الورقة على الآيباد تُعرض ضيّقة فيقول
            // صنف حجمها «مضغوط»، فلو سألتْه لسقط خيار الشاشة العريضة عن الآيباد.
            ReaderControls(wide: sizeClass == .regular).presentationDetents([.height(430), .large])
                .atharSheetChrome()
        }
        .sheet(item: $selected) { ref in
            AyahActions(ref: ref).presentationDetents([.medium, .large])
                .atharSheetChrome()
        }
        .sheet(isPresented: $showGoToPage) {
            GoToPageSheet(start: Quran.page(of: currentRef ?? scrollTo ?? AyahRef(surah: surahId, ayah: 1))) { page in
                jumpPage = page
            }
            .presentationDetents([.height(460), .large])
            .atharSheetChrome()
        }
        // خلفية الشريط بلون الورق وظاهرة: بلا خلفيةٍ ظاهرة لا يقود toolbarColorScheme
        // شريطَ الحالة، فتُرسم الساعة والبطارية بيضاء على ورقٍ كريمي حين يكون
        // التطبيق داكنًا. الشكل لا يتغيّر، وشريط الحالة يتبع سِمة القراءة.
        .toolbarBackground(palette.paper, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(effectiveTheme == .night ? .dark : .light, for: .navigationBar)
        // القارئ يُمسك المصحف دقائق دون لمس — لا تنطفئ الشاشة عليه.
        .onAppear {
            ReaderWake.enter()
            isShown = true
            syncScheme()
        }
        .onDisappear {
            ReaderWake.exit()
            isShown = false
            store.readerScheme = .none
            // تلاوة الآية بالآية تخصّ المصحف المفتوح: بلا هذا استمرّ الصوت بعد الخروج بلا زرّ يوقفه.
            ayahAudio.stop()
            TafsirSpeaker.shared.stop()
        }
        // السِمة المفروضة على النافذة تتبع الورق الفعليّ (بما فيه الليليّ التلقائي) لا الاختيار
        // المحفوظ وحده: اختيار «ورق» بعد العشاء مع الليليّ التلقائي كان يترك الورق ليليًّا وشريط
        // الحالة والمبدّل نهاريَّين. والعودة من الخلفية تعيد المطابقة — فقد يكون العشاء دخل أو
        // الفجر طلع في الغياب.
        .onChange(of: store.readingTheme) { _, _ in syncScheme() }
        .onChange(of: store.readingThemeAuto) { _, _ in syncScheme() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { syncScheme() } }
    }

    /// القارئ في تبويب غير مختار يبقى حيًّا في شجرة TabView، فيصله تبدّل المشهد أيضًا —
    /// لولا حارس الظهور لفرض ورقه على التطبيق كلّه عند كل عودة من الخلفية وهو غير معروض.
    private func syncScheme() {
        guard isShown else { return }
        store.readerScheme = effectiveTheme == .night ? .dark : .light
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
                                 noted: noted,
                                 playing: ayahAudio.current,
                                 selected: selected,
                                 isDark: effectiveTheme == .night,
                                 onTapAyah: { selected = $0 },
                                 onVisible: {
                                     store.lastRead = $0
                                     if $0 == AyahRef(surah: 18, ayah: 110), Calendar.current.component(.weekday, from: Date()) == 6 { store.noteKahfRead() }
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
            // «اذهب إلى صفحة» في عرض الآيات: أول آية الصفحة تُصيّر السورةَ الفاعلة،
            // ثم تُبنى القائمة عليها — فيُمهَل رصّها قبل القفز، كما في الظهور أعلاه.
            .onChange(of: jumpPage) { _, page in
                guard let page else { return }
                let ref = Quran.firstAyah(ofPage: page)
                currentRef = ref
                jumpPage = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation(Motion.smooth) { proxy.scrollTo(ref.ayah, anchor: .center) }
                }
            }
        }
    }

    /// شريط الموضع: الصفحة والجزء ونسبة التقدّم في المصحف كله — وزرٌّ يفتح
    /// «اذهب إلى صفحة»، فالموضع المعروض هو نفسه الموضع الذي يُقصد تبديله.
    private var positionBar: some View {
        let ref = currentRef ?? AyahRef(surah: surahId, ayah: 1)
        let page = Quran.page(of: ref)
        let juz = Quran.juz(of: ref)
        let pct = Int((Double(page) / Double(Quran.pageCount) * 100).rounded())
        return Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            showGoToPage = true
        } label: {
            HStack(spacing: Theme.Space.sm) {
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
            // الكبسولة ٣٠ نقطة رسمًا؛ يُوسَّع هدف اللمس إلى ٤٤ دون تكبيرها.
            .tapTarget()
        }
        .pressable()
        .accessibilityLabel(loc("الجزء %1$@ · صفحة %2$@ من %3$@", juz.counterText, page.counterText, Quran.pageCount.counterText))
        .accessibilityHint(loc("يفتح الانتقال إلى صفحة"))
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
    /// الآيات التي لصاحب المصحف عليها تدبّر — تُعلَّم بعلامةٍ لا تحجب حرفًا.
    var noted: Set<AyahRef> = []
    /// الآية الجارية في التلاوة آيةً آية — تُظلَّل بلون الطابع.
    var playing: AyahRef? = nil
    /// الآية التي نقرها القارئ (ورقة الخيارات مفتوحة عليها) — تُبرَز فوق كل تظليل.
    var selected: AyahRef? = nil
    let isDark: Bool
    var framed: Bool = false
    /// صفحتان متقابلتان تُقلَّبان معًا كالمصحف حين يُفتح — للشاشة العريضة وحدها.
    var spread: Bool = false
    /// ارتفاع ما يعلو حافّة الصفحة السفلية — شريط الموضع وحده، فهو الثابت.
    var bottomInset: CGFloat = 0
    /// وما زاده المشغّل عليه حين تجري التلاوة: فسحةٌ وتمرير لا إعادةَ ملاءمة.
    var playerOverlay: CGFloat = 0
    /// صفحةٌ طُلب الانتقال إليها من «اذهب إلى صفحة» — تُفرَّغ فور بلوغها.
    @Binding var jumpTo: Int?
    let onTapAyah: (AyahRef) -> Void
    let onPageVisible: (Int) -> Void
    /// الصفحة المقابلة في العَرضة: تُحتسب قراءةً ولا تُزحزح موضع القارئ عن
    /// أولى الصفحتين — فالعين تبدأ باليمنى وإن كانت الأخرى مفتوحة معها.
    var onFacingPage: (Int) -> Void = { _ in }

    @State private var current: Int?

    /// مبادئ العَرضات: كلٌّ تبدأ بصفحة وترية (١ مع ٢، ٣ مع ٤) كالمصحف المطبوع.
    /// والوقوف عند ٦٠٣ يضمن لكل مبدأٍ مقابلةً، فلا تبقى صفحةٌ وحدها. ثابتة
    /// تُحسب مرّة: الجسم يُعاد تقويمه مع كل صفحةٍ تُقلَّب.
    private static let spreadStarts = Array(stride(from: 1, through: Quran.pageCount - 1, by: 2))

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    if spread {
                        ForEach(Self.spreadStarts, id: \.self) { first in
                            spreadLeaf(first)
                                .containerRelativeFrame(.horizontal)
                                .id(first)
                        }
                    } else {
                        ForEach(1...Quran.pageCount, id: \.self) { page in
                            pageView(page)
                                .containerRelativeFrame(.horizontal)
                                .id(page)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .onAppear {
                let target = leaf(of: startPage)
                proxy.scrollTo(target, anchor: .center)
                current = target
                report(target)
            }
            .onChange(of: current) { _, page in
                if let page { report(page) }
            }
            // القفزة كالفتح تمامًا: بلا حركةٍ تمرّ على مئات الصفحات — الوصول
            // مقصود لا رحلة. وتغيّر `current` يبلّغ القارئ بالموضع الجديد.
            .onChange(of: jumpTo) { _, page in
                guard let page else { return }
                // المطلوبة قد تكون شفعيّة، والعَرضة تُعرف بأولى صفحتيها — فيُقفز
                // إلى عَرضتها لا إلى هويّةٍ لا وجود لها في العرض المزدوج.
                let target = leaf(of: page)
                proxy.scrollTo(target, anchor: .center)
                current = target
                jumpTo = nil
            }
        }
    }

    /// أولى صفحتَي العَرضة التي تقع فيها الصفحة — وهي نفسها في الصفحة المفردة.
    private func leaf(of page: Int) -> Int {
        guard spread else { return page }
        return page.isMultiple(of: 2) ? max(1, page - 1) : page
    }

    /// الوقوف على عَرضةٍ بلوغٌ لصفحتيها معًا، والترتيب لازم: الختمة لا تتقدّم
    /// إلا صفحةً بعد صفحة، فلو أُهملت المقابلة وقفت عند أول عَرضة.
    private func report(_ page: Int) {
        onPageVisible(page)
        if spread { onFacingPage(min(Quran.pageCount, page + 1)) }
    }

    /// صفحةٌ واحدة كما تُرسم دائمًا — تبنيها العَرضة والصفحة المفردة جميعًا،
    /// فلا يُنسخ رسمُ الصفحة مرّتين.
    private func pageView(_ page: Int) -> some View {
        MushafPageContent(page: page, palette: palette, scale: scale,
                          bookmarks: bookmarks, highlights: highlights,
                          noted: noted,
                          playing: playing, selected: selected,
                          isDark: isDark, framed: framed,
                          bottomInset: bottomInset, playerOverlay: playerOverlay,
                          onTapAyah: onTapAyah)
    }

    /// عَرضة: الأولى يمينًا وتاليتها يسارًا — الترتيب من اتجاه البيئة، والتطبيق عربي.
    /// وكل صفحة تقيس ملاءمتها داخل نصفها وحده لأن لكلٍّ قارئَ هندسةٍ خاصًّا بها،
    /// فيُصغَّر خطّها على نصف العرض لا على العرض كلّه ولا يفيض النصّ.
    private func spreadLeaf(_ first: Int) -> some View {
        HStack(spacing: 0) {
            pageView(first)
            gutter
            pageView(first + 1)
        }
    }

    /// ثنية المصحف بين الصفحتين — خيطٌ خافت يفصل ولا يقطع، ينتهي حيث ينتهي
    /// النصّ فلا يمضي تحت الشريط السفلي.
    private var gutter: some View {
        Rectangle()
            .fill(palette.hairline)
            .frame(width: 1)
            .padding(.top, 22)
            .padding(.bottom, bottomInset + 22)
    }
}

/// محتوى صفحة واحدة من المصحف.
private struct MushafPageContent: View {
    let page: Int
    let palette: ReadingPalette
    let scale: Double
    let bookmarks: Set<AyahRef>
    let highlights: [String: String]
    /// آيات لها تدبّر مكتوب — علامةٌ صغيرة عند ميداليتها لا غير.
    var noted: Set<AyahRef> = []
    var playing: AyahRef? = nil
    /// الآية المنقورة — تُبرَز فوق تظليل التلاوة وألوان القارئ.
    var selected: AyahRef? = nil
    let isDark: Bool
    var framed: Bool = false
    var bottomInset: CGFloat = 0
    /// ما يعلو الصفحة من شريط التلاوة زائدًا على شريط الموضع. لا يدخل في حساب الملاءمة
    /// (فلا يُعاد ضبط الخطّ عند تشغيل القارئ)، وإنما يُفسح له أسفل المحتوى ويُطلَق التمرير
    /// بقدره — فيبلغ القارئ ما غطّاه الشريط بتمريرةٍ يسيرة بدل أن تتبدّل صفحته كلّها.
    var playerOverlay: CGFloat = 0
    let onTapAyah: (AyahRef) -> Void

    // MARK: ملاءمة الصفحة للشاشة

    /// معامل التصغير التلقائي لهذه الصفحة وحدها (١ = بلا تصغير). الصفحة الممتلئة
    /// تطول عن الشاشة بمكبِّر الخطّ أو بحجم نصّ النظام، فتُقاس وتُصغَّر حتى تظهر
    /// كاملةً بلا تمرير كالمصحف المطبوع — إن فعّل القارئ «الصفحة كاملة على الشاشة».
    @State private var fit: Double = 1
    /// عدد جولات الملاءمة منذ آخر إعادة ضبط — سقفٌ يمنع حلقة قياس/رسم لا تنتهي.
    @State private var fitPasses = 0
    /// آخر ارتفاع مقيس لكومة الصفحة — يُعاد استعماله حين يتبدّل المتاح لا المحتوى.
    @State private var measured: CGFloat = 0
    /// الصفحة أطول من المتاح رغم أقصى تصغير (أو قبل اكتمال الملاءمة) — فيبقى التمرير.
    @State private var overflows = false
    /// أحجام «إمكانية الوصول» في الخط الديناميكي: المستخدم كبّر عمدًا، فلا تُصغَّر الصفحة عليه.
    @Environment(\.dynamicTypeSize) private var typeSize

    /// أصغر معامل مسموح: أدنى منه يضيق النصّ الشرعي عن القراءة، فيُترك التمرير للباقي.
    /// ٠٫٦٢ (نحو ١٤ نقطة) كي تدخل الصفحات الكثيفة كاملةً كما طلب صاحب التطبيق —
    /// ٠٫٧٥ كان يقف قبل أن تدخل صفحةٌ كصفحة ٣ فيبقى آخر سطرها تحت شريط الموضع.
    private static let minFit = 0.62
    /// هامش التنفّس بين ذيل الصفحة (رقمها) والشريط السفلي.
    private static let breathing: CGFloat = 12
    /// هوامش الفرعين الرأسية: سادة ١٢ فوق؛ مؤطَّرة ١٠ خارج الإطار و٢٠ داخله فوق
    /// و١٦ داخله تحت — والحافّة السفلية للفرعين تأتي من الشريط السفلي وهامش التنفّس.
    private static let plainTop: CGFloat = 12
    private static let framedOuterTop: CGFloat = 10
    private static let framedInnerTop: CGFloat = 20
    private static let framedInnerBottom: CGFloat = 16
    /// ما تأكله هوامش الفرع من الارتفاع فوق المحتوى (الإطار خلفيةٌ لا يزيد الارتفاع شيئًا).
    private var verticalInsets: CGFloat {
        framed ? Self.framedOuterTop + Self.framedInnerTop + Self.framedInnerBottom
               : Self.plainTop
    }
    /// المقياس الفعلي للرسم: مكبِّر القارئ مضروبًا في معامل الملاءمة.
    private var drawScale: Double { scale * fit }

    /// جولة ملاءمة: الارتفاع ينمو مع المقياس شبه تربيعيًّا (سطورٌ أكثر وأطول)،
    /// فالجذر التربيعي للنسبة يقرّب في جولةٍ أو جولتين، مع هامش ١٫٥٪ احتياطًا.
    private func refit(measured h: CGFloat, available: CGFloat) {
        guard store.fitPage, available > 0, h > 0 else { overflows = false; return }
        let over = h > available + 1
        overflows = over
        // حجم إمكانية الوصول يُلغي التصغير لا التمرير: overflows بقيت صادقة فيبقى التمرير.
        guard !typeSize.isAccessibilitySize else { return }
        guard over, fitPasses < 4, fit > Self.minFit else { return }
        let next = max(Self.minFit, fit * sqrt(Double(available / h)) * 0.985)
        guard abs(next - fit) > 0.002 else { return }
        fitPasses += 1
        fit = next
    }

    /// إعادة الضبط حين يتبدّل المكبِّر أو المتاح: الرجوع إلى ١ يغيّر الارتفاع فيعيد
    /// القياسُ الملاءمةَ من جديد؛ وإن كان ١ أصلًا لم يتغيّر شيء، فتُحسب بالقياس المحفوظ.
    private func resetFit(available: CGFloat) {
        fitPasses = 0
        if fit != 1 { fit = 1 } else { refit(measured: measured, available: available) }
    }

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
        // فيثبت الرقم في ذيل الصفحة ولا يتغيّر شيء في الصفحات الممتلئة.
        // المتاح = ما يُرى فعلًا: ارتفاع الفرع ناقص ما يعلو الحافّة السفلية (شريط
        // الموضع أو المشغّل) وهامش التنفّس، وناقص هوامش الفرع — فيقف رقم الصفحة
        // ظاهرًا فوق الشريط لا تحته.
        // الملاءمة تقيس الارتفاع الطبيعي للكومة نفسها (قبل الحدّ الأدنى) بالمتاح
        // ذاته، وتصغّر الخطّ حتى تدخل الصفحة في الشاشة؛ والتمرير يُعطَّل ما دامت
        // داخلةً، ويبقى لصفحةٍ لا تنزل عن أقصى تصغير.
        GeometryReader { geo in
            let bottomPad = bottomInset + Self.breathing
            // المتاح يُحسب على شريط الموضع وحده؛ والمشغّل يُفسح له بالحشو لا بالحساب.
            let available = max(0, geo.size.height - verticalInsets - bottomPad)
            let contentPad = bottomPad + playerOverlay
            ScrollView {
                if framed {
                    measuredStack
                        .frame(minHeight: available, alignment: .top)
                        .padding(.horizontal, 17)
                        .padding(.top, Self.framedInnerTop)
                        .padding(.bottom, Self.framedInnerBottom)
                        .background(MushafFrame(palette: palette))
                        .padding(.horizontal, 12)
                        .padding(.top, Self.framedOuterTop)
                        .padding(.bottom, contentPad)
                        .readableWidth(700)
                } else {
                    measuredStack
                        .frame(minHeight: available, alignment: .top)
                        .padding(.horizontal, 20)
                        .padding(.top, Self.plainTop)
                        .padding(.bottom, contentPad)
                        .readableWidth(700)
                }
            }
            .scrollIndicators(.hidden)
            // التمرير يُطلَق ما دام المشغّل يعلو الصفحة، وإلا حُجب آخر سطرٍ خلفه بلا سبيل إليه.
            .scrollDisabled(store.fitPage && !overflows && playerOverlay == 0)
            .onPreferenceChange(PageHeightKey.self) { h in
                measured = h
                refit(measured: h, available: available)
            }
            .onChange(of: store.fitPage) { _, on in
                fitPasses = 0
                if on { refit(measured: measured, available: available) } else { fit = 1; overflows = false }
            }
            .onChange(of: scale) { _, _ in resetFit(available: available) }
            .onChange(of: typeSize) { _, _ in resetFit(available: available) }   // الخروج من حجم إمكانية الوصول يعيد الملاءمة، والدخول إليه يعيد الخطّ إلى ١
            .onChange(of: available) { _, a in resetFit(available: a) }
        }
        .animation(Motion.snappy, value: selected)
    }

    /// الكومة مع قياس ارتفاعها الطبيعي — القياس على الكومة ذاتها لا على إطار الحدّ الأدنى.
    private var measuredStack: some View {
        pageStack.background(
            GeometryReader { g in
                Color.clear.preference(key: PageHeightKey.self, value: g.size.height)
            }
        )
    }

    private var pageStack: some View {
            VStack(spacing: 14 * drawScale) {
                ForEach(runs, id: \.first) { run in
                    if let first = run.first, first.ayah == 1 {
                        surahHeader(first.surah)
                    }
                    FlowLayout(lineSpacing: 14 * drawScale, wordSpacing: 5 * drawScale) {
                        ForEach(tokens(of: run)) { tokenView($0) }
                    }
                    // شريط التظليل يُرسم هنا خلف السطور آيةً كاملة من مواضع كلماتها،
                    // لا كلمةً كلمة — داخل تثبيت LTR أدناه كي تطابق إحداثياته الرصّ.
                    .backgroundPreferenceValue(AyahBandKey.self) { ayahBands($0) }
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
                                    .accessibilityLabel(ayahLabel(ref))
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

    /// وصف الآية لقارئ الشاشة: نصّها ورقمها، وتُذكر ورقة التدبّر كلامًا لأنها
    /// في الصفحة رسمٌ لا يُقرأ.
    private func ayahLabel(_ ref: AyahRef) -> String {
        let base = loc("%1$@ — الآية %2$@", Quran.text(ref) ?? "", ref.ayah.counterText)
        return noted.contains(ref) ? loc("%1$@ · لك تدبّر هنا", base) : base
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
                        .font(Theme.naskhFont(size: 18, scale: min(fit, 1), bold: true))
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
                        .font(Theme.dhikrFont(size: 20, scale: min(scale, 1.4) * fit))
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

    /// لون شريط الآية: المنقورة أولًا، ثم الجارية في التلاوة، ثم تظليل القارئ.
    private func bandColor(_ ref: AyahRef) -> Color? {
        if ref == selected { return palette.accent.opacity(0.22) }
        if ref == playing { return palette.accent.opacity(0.18) }
        return highlights[ref.id].flatMap(HighlightColor.init(rawValue:))?.color(dark: isDark)
    }

    /// أشرطة التظليل: شريط واحد متّصل لكل آية كقلم التحديد على الورق. كل سطرٍ من
    /// الآية مستطيل يمتدّ نصف مسافة الكلمات (+١) أفقيًّا ونصف مسافة الأسطر رأسيًّا،
    /// فتلتحم الكلمات المتجاورة والأسطر المتتالية كتلةً واحدة؛ والمسار واحد لكل آية
    /// كي لا تتضاعف الشفافية عند التقاء المستطيلات. تُدوَّر الزوايا الخارجية فقط:
    /// الطرف الأيمن من أول سطر (أول كلمة) والطرف الأيسر من آخر سطر (علامة الآية).
    private func ayahBands(_ tokens: [AyahBandToken]) -> some View {
        GeometryReader { g in
            let hx = 5 * drawScale / 2 + 1
            let vy = 14 * drawScale / 2
            ForEach(Self.bands(tokens), id: \.ayah) { band in
                Self.bandPath(band.anchors.map { g[$0] }, hx: hx, vy: vy, radius: 6 * drawScale)
                    .fill(band.color)
            }
        }
    }

    private struct Band { let ayah: String; let color: Color; var anchors: [Anchor<CGRect>] }

    /// كلمات كل آية مجموعةً بترتيب ورودها (ترتيب القراءة).
    private static func bands(_ tokens: [AyahBandToken]) -> [Band] {
        var out: [Band] = []
        for t in tokens {
            if let i = out.firstIndex(where: { $0.ayah == t.ayah }) { out[i].anchors.append(t.anchor) }
            else { out.append(Band(ayah: t.ayah, color: t.color, anchors: [t.anchor])) }
        }
        return out
    }

    /// مسار الشريط من مستطيلات الكلمات: الكلمات المتساوية منتصفًا رأسيًّا على سطرٍ
    /// واحد (FlowLayout يوسّطها في السطر)، فيتّحد كل سطر مستطيلًا واحدًا من أول كلمة
    /// إلى آخرها — فيغطّي حتى فراغ الضبط بين الكلمات لا مسافتها الأصلية فقط.
    private static func bandPath(_ rects: [CGRect], hx: CGFloat, vy: CGFloat, radius: CGFloat) -> Path {
        var lines: [CGRect] = []
        for r in rects.sorted(by: { $0.midY < $1.midY }) {
            if let last = lines.last, abs(r.midY - last.midY) < max(r.height, last.height) / 2 {
                lines[lines.count - 1] = last.union(r)
            } else {
                lines.append(r)
            }
        }
        var path = Path()
        for (i, line) in lines.enumerated() {
            // نصف نقطة زيادة رأسيًّا تُغلق أي شعرة بين سطرين متلاصقين من تقريب الأرقام.
            let rect = line.insetBy(dx: -hx, dy: -(vy + 0.5))
            let r = min(radius, rect.height / 2)
            let first = i == 0, last = i == lines.count - 1
            // الرصّ مثبَّت LTR، فالبادئة (leading) هي اليسار: الآية تبدأ يمينًا وتنتهي يسارًا.
            let shape = UnevenRoundedRectangle(topLeadingRadius: last ? r : 0, bottomLeadingRadius: last ? r : 0,
                                               bottomTrailingRadius: first ? r : 0, topTrailingRadius: first ? r : 0,
                                               style: .continuous)
            path.addPath(shape.path(in: rect))
        }
        return path
    }

    @ViewBuilder
    private func tokenView(_ t: Token) -> some View {
        let band = bandColor(t.ref)
        let hidden = isHidden(t)
        Group {
            if t.isMarker {
                // الميدالية بارتفاع سطر الكلمات نفسه (نصّ خفيّ بخطّها يحدّد الارتفاع)
                // كي يمتدّ شريط الآية عليها بلا ثلمة وتكبر لمستها — ولا يطول السطر
                // لأنها لا تعلو الكلمات. العلامة المرجعية تبقى على الميدالية ذاتها.
                Text(verbatim: " ")
                    .font(Theme.dhikrFont(size: 23, scale: drawScale))
                    .frame(width: 26 * drawScale)
                    .overlay {
                        AyahMedallion(number: t.number, size: 26 * drawScale, tint: palette.accent)
                            .overlay(alignment: .topLeading) {
                                if bookmarks.contains(t.ref) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 8))
                                        .foregroundStyle(palette.accent)
                                        .offset(x: -2, y: -3)
                                }
                            }
                            // ورقةٌ صغيرة عند ذيل الميدالية تقول «هنا لك كلام» —
                            // خافتة لا تزاحم حرفًا، وقارئ الشاشة يسمعها في وصف الآية.
                            .overlay(alignment: .bottomTrailing) {
                                if noted.contains(t.ref) {
                                    Image(systemName: "leaf.fill")
                                        .font(.system(size: 7))
                                        .foregroundStyle(palette.accent.opacity(0.75))
                                        .offset(x: 2, y: 3)
                                        .accessibilityHidden(true)
                                }
                            }
                    }
            } else {
                Text(t.text)
                    .font(Theme.dhikrFont(size: 23, scale: drawScale))
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
        // موضع الكلمة يصعد إلى FlowLayout ليُرسم شريط الآية كاملًا خلف السطر —
        // لا شيء يصعد من كلمةٍ في آيةٍ غير مظلَّلة.
        .anchorPreference(key: AyahBandKey.self, value: .bounds) { anchor in
            guard let band else { return [] }
            return [AyahBandToken(ayah: t.ref.id, color: band, anchor: anchor)]
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

/// موضع كلمةٍ مظلَّلة مع آيتها ولونها — تُجمع في FlowLayout لرسم شريط الآية كاملًا.
private struct AyahBandToken {
    let ayah: String
    let color: Color
    let anchor: Anchor<CGRect>
}

private struct AyahBandKey: PreferenceKey {
    static let defaultValue: [AyahBandToken] = []
    static func reduce(value: inout [AyahBandToken], nextValue: () -> [AyahBandToken]) { value += nextValue() }
}

/// ارتفاع كومة الصفحة الطبيعي — يصعد من خلفية الكومة إلى الصفحة لتقرّر الملاءمة.
private struct PageHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// ارتفاع الشريط السفلي (المشغّل وشريط الآية) كما رُسم — يصعد من الطبقة العلوية إلى القارئ.
private struct BottomBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - ضوابط القراءة

struct ReaderControls: View {
    /// أعريضةٌ شاشةُ القارئ؟ يُمرَّر من القارئ نفسه لا يُسأل عنه هنا — الورقة
    /// تُعرض ضيّقة على الآيباد فيقول صنف حجمها «مضغوط» وهي فوق شاشةٍ عريضة.
    let wide: Bool

    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AtharBackground()
            // المحتوى يطول مع مكبِّر الخطّ ومع حجم نصّ النظام، فبلا تمرير
            // تُقتطع «سِمة الصفحة» أسفل الورقة ولا سبيل للوصول إليها.
            ScrollView {
                VStack(spacing: 22) {
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
                        // الشاشة العريضة تحمل أكثر من صفحة: صفحتين متقابلتين كالمصحف
                        // حين يُفتح، أو صفحةً والتفسير إلى جانبها. وفي «آية آية» تمريرٌ
                        // متصل لا صفحات، فلا موضع للخيار.
                        if wide, store.readingMode != .ayah {
                            Picker("", selection: spreadChoice) {
                                ForEach(MushafSpread.allCases) { Text($0.title).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .accessibilityLabel(loc("عرض الشاشة العريضة"))

                            Text(loc("صفحتان تُقلَّبان معًا كالمصحف حين يُفتح، أو صفحة وتفسيرها إلى جانبها."))
                                .font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                        }

                        // في وضعَي الصفحة: تصغيرٌ تلقائي حتى تظهر الصفحة كاملةً بلا تمرير
                        // كالمصحف المطبوع. لا معنى له في «آية آية» فيُخفى هناك.
                        if store.readingMode != .ayah {
                            Toggle(isOn: Binding(get: { store.fitPage }, set: { store.fitPage = $0 })) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc("الصفحة كاملة على الشاشة")).font(Theme.display(14, weight: .medium)).foregroundStyle(Theme.ink)
                                    Text(loc("تصغير الخط تلقائيًّا حتى تظهر الصفحة بلا تمرير")).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                                }
                            }
                            .tint(Theme.accent)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceAlt))
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
                        // الوضع الليلي التلقائي: بين العشاء والفجر يُقرأ على ورق الليل مهما كانت السِمة.
                        Toggle(isOn: Binding(get: { store.readingThemeAuto }, set: { store.readingThemeAuto = $0 })) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc("ليلي تلقائيًّا")).font(Theme.display(14, weight: .medium)).foregroundStyle(Theme.ink)
                                Text(loc("بين العشاء والفجر بحساب مواقيتك")).font(Theme.display(11)).foregroundStyle(Theme.inkFaint)
                            }
                        }
                        .tint(Theme.accent)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surfaceAlt))
                        HStack(spacing: 10) {
                            ForEach(ReadingTheme.allCases) { theme in
                                themeChip(theme)
                            }
                        }
                    }

                    Spacer(minLength: 0)
                }
                // مقبض السحب من النظام (كسوة الأوراق)، فيبدأ المحتوى تحته بهامشٍ لا بمقبضٍ مرسوم.
                .padding(.top, Theme.Space.xl)
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            }
        }
    }

    /// اختيار الشاشة العريضة — تُحسّ نقرتُه كما تُحسّ رقائق وضع العرض المجاورة.
    private var spreadChoice: Binding<MushafSpread> {
        Binding(get: { store.mushafSpread },
                set: { store.mushafSpread = $0; Haptics.tap(enabled: store.hapticsEnabled) })
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

// MARK: - اذهب إلى صفحة

/// «أذكر رقم الصفحة، وما في إلّا أن أقرّب لأرى أقرب صورة ثم أسحب» — فصار الرقم
/// نفسه بابًا: يُكتب أو يُجَرّ، ويُقال له إلى أين يمضي قبل أن يمضي.
struct GoToPageSheet: View {
    let start: Int
    let onGo: (Int) -> Void

    @EnvironmentObject private var store: AtharStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var typing: Bool
    @State private var mode: JumpMode = .page

    /// بأيّهما يذكر القارئ موضعه: بالصفحة أو بالجزء. وكلاهما ينتهي إلى صفحة،
    /// فالقارئ لا يعرف إلا الصفحات.
    enum JumpMode: String, CaseIterable, Identifiable {
        case page, juz
        var id: String { rawValue }
        var title: String { self == .page ? loc("صفحة") : loc("جزء") }
        var bound: Int { self == .page ? Quran.pageCount : Quran.juzCount }
        /// الصفحة المقصودة من الرقم المكتوب — وأوّل الجزء صفحةٌ كسائرها.
        func page(_ n: Int) -> Int { self == .page ? n : Quran.page(of: Quran.firstAyah(ofJuz: n)) }
    }

    /// ما في الحقل رقمًا قائمًا في مداه — وما خرج عنه فلا وجهة له.
    private var number: Int? {
        guard let n = text.bareNumberValue, (1...mode.bound).contains(n) else { return nil }
        return n
    }

    /// الصفحة التي سيقف عندها القارئ فعلًا.
    private var page: Int? { number.map(mode.page) }

    /// المنزلق لا يقبل الفراغ: يقف على المكتوب إن صحّ، وإلا على موضع القارئ.
    private var slider: Binding<Double> {
        Binding(get: { Double(number ?? (mode == .page ? start : Quran.juz(of: Quran.firstAyah(ofPage: start)))) },
                set: { text = String(Int($0.rounded())) })
    }

    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.gold)
            ScrollView {
                VStack(spacing: Theme.Space.lg) {
                    Text(loc("اذهب إلى موضع"))
                        .font(Theme.display(19, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    // بالصفحة أو بالجزء: كلاهما موضعٌ يُحفظ، ومن حفظ جزءه لا يلزمه أن يحسب صفحته.
                    Picker("", selection: $mode) {
                        ForEach(JumpMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel(loc("اذهب إلى موضع"))

                    // الأرقام الغربية في الواجهة كلّها؛ ولوحةُ الأرقام العربية تُخرج
                    // الهندية فتُقرأ كما هي وتُردّ غربيةً إلى الحقل.
                    TextField("", text: $text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .monospacedDigit()
                        .focused($typing)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .fill(Theme.surfaceAlt))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                            .strokeBorder(Theme.hairline.opacity(0.6), lineWidth: 0.5))
                        .accessibilityLabel(mode == .page ? loc("رقم الصفحة") : loc("رقم الجزء"))

                    Slider(value: slider, in: 1...Double(mode.bound), step: 1)
                        .tint(Theme.accent)
                        .accessibilityLabel(mode == .page ? loc("رقم الصفحة") : loc("رقم الجزء"))
                        .accessibilityValue(loc("%1$@ %2$@ من %3$@", mode.title,
                                                (number ?? start).counterText, mode.bound.counterText))

                    destination

                    Button {
                        guard let p = page else { return }
                        Haptics.done(enabled: store.hapticsEnabled)
                        onGo(p)
                        dismiss()
                    } label: {
                        Text(loc("اذهب"))
                            .font(Theme.display(16, weight: .semibold))
                            .gradientButton(Theme.accentGradient, glow: Theme.accent)
                    }
                    .pressable()
                    .disabled(page == nil)
                    .opacity(page == nil ? 0.45 : 1)

                    Spacer(minLength: 0)
                }
                .padding(.top, Theme.Space.xl)
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
                .readableWidth(520)
            }
            .scrollIndicators(.hidden)
        }
        .animation(Motion.snappy, value: page)
        // الحقل هو مقصود الورقة، فيُفتح على لوحة المفاتيح — بعد استقرارها كي ترتفع.
        .task {
            text = String(start)
            try? await Task.sleep(for: .milliseconds(350))
            typing = true
        }
        .environment(\.layoutDirection, AppConfig.arabicOnly ? .rightToLeft : store.appLanguage.layoutDirection)
    }

    /// إلى أين تمضي هذه الصفحة — سورتها وجزؤها قبل القفز لا بعده.
    @ViewBuilder
    private var destination: some View {
        if let p = page {
            let ref = Quran.firstAyah(ofPage: p)
            HStack(spacing: Theme.Space.sm) {
                IconChip(icon: "doc.plaintext.fill", tint: Theme.gold, size: .sm)
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc("سورة %1$@", Quran.surah(ref.surah)?.name ?? ""))
                        .font(Theme.display(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    // في وضع الجزء تُذكر صفحته أيضًا: المقصد واحد وإن اختلف مدخله.
                    Text(loc("الجزء %1$@ · صفحة %2$@ · تبدأ بالآية %3$@",
                             Quran.juz(of: ref).counterText, p.counterText, ref.ayah.counterText))
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.inkFaint)
                }
                Spacer(minLength: 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Theme.surfaceAlt))
            .accessibilityElement(children: .combine)
        } else {
            Text(loc("اكتب رقمًا بين %1$@ و%2$@", 1.counterText, mode.bound.counterText))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    @State private var showTasmi = false
    @State private var showNote = false
    @State private var shareImage: UIImage?

    private var text: String { Quran.text(ref) ?? "" }
    private var surahName: String { Quran.surah(ref.surah)?.name ?? "" }

    /// طرفٌ من التدبّر في الصفّ: يخبر بوجوده ولا يعرضه كلّه — موضعه المحرّر.
    private var noteGlimpse: String? {
        guard let n = store.note(for: ref) else { return nil }
        let line = NotesView.firstLine(n)
        return line.count > 60 ? String(line.prefix(60)) + "…" : line
    }

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
                    // بطاقة الآية أولًا مباشرة — مقبض السحب من النظام (كسوة الأوراق)،
                    // لا مقبضٌ ثانٍ مرسوم تحته.
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

                    // التسميع: اقرأ الآية بصوتك ويُظلَّل الصواب والخطأ.
                    // ورقة لا رابط تنقّل: الورقة هذه بلا NavigationStack فكان الرابط يظهر باهتًا ولا يستجيب.
                    Button { showTasmi = true } label: {
                        HStack(spacing: 12) {
                            IconChip(icon: "mic.fill", tint: Theme.accent(for: "hifz"), size: .md)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc("سمّع هذه الآية")).font(Theme.display(16, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(loc("اقرأها بصوتك ويُظلَّل ما صحّ وما فاتك")).font(Theme.display(12)).foregroundStyle(Theme.inkFaint)
                            }
                            Spacer(minLength: 6)
                            Image(systemName: "chevron.forward").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent(for: "hifz"))
                        }
                        .padding(14)
                        .background(CardSurface(radius: Theme.Radius.lg))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

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
                        // التدبّر بجوار العلامة والتظليل: كلّها أثرٌ يتركه القارئ على آيته.
                        Button {
                            Haptics.tap(enabled: store.hapticsEnabled)
                            showNote = true
                        } label: {
                            SettingsRow(icon: "square.and.pencil",
                                        tint: Theme.accent(for: "dusk"),
                                        title: noteGlimpse == nil ? loc("اكتب تدبّرك") : loc("تدبّرك في هذه الآية"),
                                        subtitle: noteGlimpse ?? loc("ملاحظة خاصة تبقى في جهازك"))
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
                                    // «» لا ﴿﴾: القوسان المزخرفان غير موجودين في خطّ Noto فيُرسمان مربّعين.
                                    let clean = e.text.replacingOccurrences(of: "{", with: "«").replacingOccurrences(of: "}", with: "»")
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
                .padding(.top, Theme.Space.xl)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showTafsir) {
            TafsirSheet(ref: ref)
                .presentationDetents([.large])
                .atharSheetChrome()
        }
        .sheet(isPresented: $showNote) {
            AyahNoteEditor(ref: ref)
                .presentationDetents([.medium, .large])
                .atharSheetChrome()
        }
        .sheet(isPresented: $showTasmi) {
            NavigationStack {
                TasmiView(refs: [ref])
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(loc("إغلاق")) { showTasmi = false }
                        }
                    }
            }
            .atharSheetChrome()
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
    /// آيات لها تدبّر مكتوب — ورقة صغيرة في حاشية البطاقة.
    var noted: Set<AyahRef> = []
    var playing: AyahRef? = nil
    /// الآية المنقورة — بطاقتها تُبرَز فوق تظليل التلاوة والألوان.
    var selected: AyahRef? = nil
    let isDark: Bool
    let onTapAyah: (AyahRef) -> Void
    let onVisible: (AyahRef) -> Void

    private var surah: Surah? { Quran.surah(surahId) }

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(1...(surah?.ayahCount ?? 1), id: \.self) { n in
                card(AyahRef(surah: surahId, ayah: n))
            }
        }
        .padding(.top, 8)
        .animation(Motion.snappy, value: selected)
    }

    /// بطاقة الآية مفردةً في دالّة: الجسم الواحد الطويل أعجز المُحلِّل عن تحديد نوعه
    /// حين زادته ورقةُ التدبّر شرطًا.
    private func card(_ ref: AyahRef) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AyahMedallion(number: ref.ayah, size: 30 * min(scale, 1.3), tint: palette.accent)
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

            marks(ref)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                .fill(fill(ref))
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
        .accessibilityValue(noted.contains(ref) ? loc("لك تدبّر هنا") : "")
        .accessibilityHint(loc("يفتح خيارات الآية"))
        .onAppear { onVisible(ref) }
    }

    /// علامات الحاشية: علامة القارئ، وورقة تدبّره — رسمٌ للعين وحدها، وقارئ الشاشة
    /// يسمع «لك تدبّر هنا» قيمةً للبطاقة.
    @ViewBuilder
    private func marks(_ ref: AyahRef) -> some View {
        if bookmarks.contains(ref) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 11))
                .foregroundStyle(palette.accent)
                .padding(.top, 6)
        }
        if noted.contains(ref) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 10))
                .foregroundStyle(palette.accent.opacity(0.75))
                .padding(.top, 7)
                .accessibilityHidden(true)
        }
    }

    /// لون بطاقة الآية: المنقورة أولًا، ثم الجارية في التلاوة، ثم تظليل القارئ.
    private func fill(_ ref: AyahRef) -> Color {
        if ref == selected { return palette.accent.opacity(0.22) }
        if ref == playing { return palette.accent.opacity(0.16) }
        return highlights[ref.id].flatMap(HighlightColor.init(rawValue:))?.color(dark: isDark)
            ?? palette.ink.opacity(0.03)
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

