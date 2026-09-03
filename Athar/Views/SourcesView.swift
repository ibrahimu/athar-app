import SwiftUI

/// المصادر والحقوق — إسناد كل محتوى إلى أهله، ووفاءً بشروط تراخيصه.
struct SourcesView: View {
    var body: some View {
        ZStack {
            AtharBackground(tint: Theme.accent(for: "sea"))
            ScrollView {
                VStack(spacing: 22) {
                    block(
                        icon: "book.pages.fill",
                        title: loc("نص المصحف"),
                        body: loc("النص بالرسم العثماني من **مشروع تنزيل (Tanzil Project)**، مُدقَّق على مصحف المدينة النبوية، ومنقول كما هو دون أي تغيير — بما فيه علامات الوقف والسجدات."),
                        linkTitle: "tanzil.net",
                        url: "https://tanzil.net",
                        note: loc("تشترط رخصة المشروع إظهار المصدر بوضوح مع رابط إليه، وعدم تغيير النص."),
                        accent: Theme.accent(for: "gold"),
                        index: 0
                    )

                    block(
                        icon: "text.book.closed.fill",
                        title: loc("الأذكار"),
                        body: loc("الأذكار من القرآن الكريم والسنة النبوية الصحيحة، وكل ذكر مقترن بتخريجه من مصادره: البخاري، ومسلم، وأبي داود، والترمذي، والنسائي، وابن ماجه، وأحمد."),
                        linkTitle: nil, url: nil,
                        note: loc("نصوص الوحي وأحاديث الكتب الستة تراث عام."),
                        accent: Theme.accent(for: "sea"),
                        index: 1
                    )

                    block(
                        icon: "character.book.closed.fill",
                        title: loc("التفسير"),
                        body: loc("تفسير **السعدي** (تيسير الكريم الرحمن في تفسير كلام المنّان) وتفسير **الجلالين** للمحلّي والسيوطي، وكلاهما تراث عام. النص من بيانات quran.com المفتوحة (مشروع tafsir_api) منقولًا كما هو."),
                        linkTitle: "quran.com",
                        url: "https://quran.com",
                        note: loc("تفسيران موجزان يناسبان القراءة على الجوال، ولمن أراد التوسّع كتب التفسير المطوّلة."),
                        accent: Theme.accent(for: "green"),
                        index: 2
                    )

                    block(
                        icon: "text.quote",
                        title: loc("الحديث"),
                        body: loc("**رياض الصالحين** و**الأربعون النووية** للإمام النووي رحمه الله، والنص من موقع sunnah.com. والعزو (متفق عليه، رواه مسلم…) من كلام النووي نفسه، ولا يُنقل في التطبيق تصحيحُ أحدٍ ولا تضعيفه."),
                        linkTitle: "sunnah.com",
                        url: "https://sunnah.com",
                        note: loc("حديث اليوم يُختار مما عزاه المؤلف إلى الصحيحين أو أحدهما."),
                        accent: Theme.accent(for: "dusk"),
                        index: 3
                    )

                    block(
                        icon: "sparkles",
                        title: loc("الأسماء الحسنى"),
                        body: loc("شرح الشيخ عبد الرحمن **السعدي** رحمه الله من كتابه «تفسير أسماء الله الحسنى»، منقول عبر المكتبة الشاملة."),
                        linkTitle: "shamela.ws",
                        url: "https://shamela.ws/book/10090",
                        note: loc("كل اسم مقرون بدليله من الكتاب أو السنّة."),
                        accent: Theme.accent(for: "gold"),
                        index: 4
                    )

                    block(
                        icon: "checklist",
                        title: loc("الأحكام العملية"),
                        body: loc("مكتوبة بأسلوب التطبيق اختصارًا على القارئ، وأدلّتها من الكتاب والصحيحين تُعرض بنصّها، وروابطها إلى موقعَي الشيخ **ابن باز** والشيخ **ابن عثيمين** رحمهما الله لمن أراد الفتوى بتمامها."),
                        linkTitle: "binbaz.org.sa",
                        url: "https://binbaz.org.sa",
                        note: loc("الأحكام إرشاد عام، وما اختلفت فيه الأحوال فاسأل أهل العلم في بلدك."),
                        accent: Theme.accent(for: "sea"),
                        index: 5
                    )

                    block(
                        icon: "textformat",
                        title: loc("الخط"),
                        body: loc("خط **Noto Naskh Arabic** من مشروع Noto، مرخّص برخصة الخطوط المفتوحة SIL Open Font License 1.1 التي تتيح التضمين في التطبيقات."),
                        linkTitle: "notofonts.github.io",
                        url: "https://notofonts.github.io",
                        note: nil,
                        accent: Theme.accent(for: "calm"),
                        index: 6
                    )

                    block(
                        icon: "function",
                        title: loc("أوقات الصلاة والقبلة"),
                        body: loc("تُحسب على جهازك بالخوارزمية الفلكية القياسية، بلا اتصال بأي خادم. واتجاه القبلة بحساب الدائرة العظمى إلى الكعبة."),
                        linkTitle: nil, url: nil,
                        note: loc("الأوقات تقريبية وقد تختلف دقائق عن تقويم مسجد حيّك."),
                        accent: Theme.accent(for: "green"),
                        index: 7
                    )

                    block(
                        icon: "waveform",
                        title: loc("التلاوة الصوتية"),
                        body: loc("التلاوات من موقع **MP3Quran.net**، متاحة للعموم بلا مقابل ولا اشتراك، وكلها برواية حفص عن عاصم مرتّلة."),
                        linkTitle: "mp3quran.net",
                        url: "https://mp3quran.net",
                        note: loc("لا يتصل التطبيق بالشبكة إلا حين تضغط «تشغيل» أو «تنزيل». وما نزّلته يعمل بلا إنترنت."),
                        accent: Theme.accent(for: "dusk"),
                        index: 8
                    )

                    block(
                        icon: "speaker.wave.2.fill",
                        title: loc("أصوات الأذان"),
                        body: loc("«أذان المسجد النبوي»: تسجيل ejaz215 على Freesound برخصة CC BY 3.0. «أذان سعيد حاتم‌زاده» و«أذان عاقب عزيز»: ويكيميديا كومنز برخصة CC BY-SA 4.0. «أذان (تسجيل مفتوح)»: ويكيميديا كومنز، CC0. «أذان صباح فخري»: ويكيميديا كومنز، موسومٌ هناك ملكًا عامًّا."),
                        linkTitle: "commons.wikimedia.org",
                        url: "https://commons.wikimedia.org/wiki/Category:Adhan",
                        note: loc("مقاطع التنبيه مقتطعة من أوائل التسجيلات (٣٠ ثانية حدّ iOS للإشعارات)، والتسجيل الكامل يُسمع من شاشة اختيار الصوت."),
                        accent: Theme.accent(for: "gold"),
                        index: 9
                    )

                    closing.appearStagger(10)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("المصادر والحقوق"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    // MARK: - بطاقة مصدر

    private func block(icon: String, title: String, body: String,
                       linkTitle: String?, url: String?, note: String?,
                       accent: Color, index: Int) -> some View {
        AtharCard(padding: 18, tint: accent) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    // أيقونة القسم في دائرة مصبوغة بلونه، خلفها نجمة باهتة
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(accent)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(accent.opacity(0.14))
                                .overlay(
                                    EightPointStar(innerRatio: 0.66)
                                        .fill(accent.opacity(0.10))
                                        .padding(7)
                                )
                        )
                    Text(title)
                        .font(Theme.display(17, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }

                Text(.init(body))
                    .font(Theme.display(13))
                    .foregroundStyle(Theme.inkSoft)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let linkTitle, let url, let u = URL(string: url) {
                    Link(destination: u) {
                        HStack(spacing: 5) {
                            Text(linkTitle).font(Theme.display(13, weight: .semibold))
                            Image(systemName: "arrow.up.forward").font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Capsule().fill(accent.opacity(0.13)))
                    }
                    .pressable()
                }

                if let note {
                    HStack(spacing: 7) {
                        Capsule()
                            .fill(accent.opacity(0.5))
                            .frame(width: 2.5, height: 13)
                        Text(note)
                            .font(Theme.display(11))
                            .foregroundStyle(Theme.inkFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, 1)
                }
            }
        }
        // نجمة زاويّة باهتة جدًا بلون القسم — مقصوصة على حدّ البطاقة كي لا تنافس النص
        .overlay {
            EightPointStar(innerRatio: 0.68)
                .fill(accent.opacity(0.04))
                .frame(width: 104, height: 104)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
                .allowsHitTesting(false)
        }
        .appearStagger(index)
    }

    // MARK: - ختام الصفحة

    /// إعلان المنهج ثم الدعوة إلى التصحيح، تسبقهما زخرفة نجمة ذهبية كفاصلة المصاحف.
    private var closing: some View {
        VStack(spacing: 14) {
            goldStarDivider
            Text(loc("كل ما في التطبيق من مصادر أهل السنّة والجماعة، ولا يُنقل عن كتب أهل البدع شيء."))
                .font(Theme.display(12, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
            Text(loc("إن رأيت خطأً في نصّ أو إسناد، فأخبرنا — تصحيح النص الشرعي أولى من كل شيء."))
                .font(Theme.display(12))
                .foregroundStyle(Theme.inkFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 4)
    }

    /// فاصلة زخرفية: خيطان ذهبيان يتلاشيان نحو نجمة ثمانية في الوسط.
    private var goldStarDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Theme.gold.opacity(0.35)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
            EightPointStar(innerRatio: 0.6)
                .fill(Theme.goldGradient)
                .frame(width: 12, height: 12)
            Rectangle()
                .fill(LinearGradient(colors: [Theme.gold.opacity(0.35), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
        }
        .frame(maxWidth: 220)
    }
}
