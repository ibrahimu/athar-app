import SwiftUI
import UIKit

// MARK: - المجلس
//
// شاشةٌ تُفتح للمرّة الثانية، فما الذي يُراد منها؟ شيئان يوميّان — **الإذاعة**
// و**القرّاء** — وشيءٌ شهريٌّ هو الإعدادات. فالاثنان مربّعان كبيران، والثالثُ
// مربّعٌ ضيّقٌ رماديٌّ في **الصفّ نفسه**: أخفُّ وزنًا لا أبعدَ منالًا. كان ترسًا
// في الصدر لا يبلغه التركيزُ إلا بمن يعرف أنّه هناك، ثمّ صار ثالثًا مساويًا
// لِما يُستعمل كلَّ يوم — وكلاهما خطأ. والصفُّ الواحد هو ما يُدار بالمِرقاب
// يمينًا ويسارًا بلا «اضغط إلى أعلى وارجُ».
//
// وحين يكون شيءٌ يُسمَع تقول الشاشةُ ذلك في **شريطٍ** فوق المربّعات: ما الذي
// يُتلى ومَن يتلوه وهل هو جارٍ أم متوقّفٌ أم منقطع — ويُفتح منه المشغّل. كانت
// الشاشةُ صامتةً عمّا يجري فيها، ولا سبيلَ إلى تقديمٍ أو تأخيرٍ أو سرعة.
//
// والصلاةُ القادمة: اسمُها ووقتُها هما ما يُقرأ من آخر الغرفة — «متى العصر؟»
// جوابُه «3:18» لا «بعد ساعتين»، فالوقتُ ثابتٌ يُحفظ والعدُّ يتغيّر كلَّ دقيقة.
// فالعدُّ سطرٌ ثانٍ خافت، ومعه المدينةُ لأنّ الوقتَ وقتُها. ولا جدولَ لليوم كلِّه:
// ستّةُ أزواجٍ من الأسماء والأرقام بحجمٍ يُقرأ من ثلاثة أمتار تملأ الشاشة، وترتيبُ
// الصلوات معلومٌ لكلّ أحد — المجهولُ الوحيد هو القادمة. وهذا ما تفعله شاشةُ
// الهاتف نفسُها.
//
// وكلُّ نصٍّ يبدأ من اليمين ولو كان صندوقُه في الوسط: العينُ العربية تنتظر أوّلَ
// السطر يمينًا، والتوسيطُ يتركها تبحث عنه فتبدو الشاشةُ غريبة.
struct TVMajlisView: View {
    @ObservedObject private var prefs = TVPrefs.shared
    @ObservedObject private var audio = TVAudio.shared
    @ObservedObject private var idle = TVIdle.shared
    @FocusState private var focus: Focus?
    @State private var route: Route?
    /// حيث يهبط التركيزُ بعد أن يُغلق غطاء: يُضبط عند الإغلاق ويُصرف بعده.
    @State private var landing: Focus?

    private enum Focus: Hashable { case player, radio, reciters, settings }
    private enum Route: Hashable, Identifiable {
        case player, reciters, settings
        var id: Self { self }
    }


    /// مقاساتُ الصفّ. ارتفاعٌ واحد للثلاثة، والعريضان للشيئين اليوميّين والضيّقُ
    /// للإعدادات — فالوزنُ يُقرأ من العرض قبل أن يُقرأ الاسم. والثلاثةُ تملأ
    /// ما بين حافّتَي الأمان (١٩٢٠ − ٩٠ × ٢ = ١٧٤٠): صفٌّ يقف قبل الحافّة بكثير
    /// يبدو ناقصًا لا مقصودًا. وتُترك خمسون نقطةً لأنّ التركيزَ يُكبّر ثلاثةً في
    /// المئة، وشريطُ السماع بعرض الصفّ كلِّه — فمكبَّرًا يقف على الحافّة لا خلفها.
    private enum Row {
        static let height: CGFloat = 430
        static let wide: CGFloat = 670
        static let quiet: CGFloat = 298
        static let strip: CGFloat = 116
        static var width: CGFloat { wide * 2 + quiet + TVMetric.gridGap * 2 }
    }

    var body: some View {
        TVGround {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 0)
                if audio.now != .silent {
                    playing
                        .padding(.bottom, TVMetric.gridGap)
                }
                choices
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TVSafe.horizontal)
            .padding(.vertical, TVSafe.vertical)
        }
        .fullScreenCover(item: $route, onDismiss: land) { r in
            switch r {
            case .player:   EmptyView() // مؤقّت حتى يصل TVPlayerView
            case .settings: TVSettingsView { route = nil }
            case .reciters:
                // من رجع من القرّاء وقد بدأ صوتًا يهبط على الشريط — فهو الجواب
                // المرئيّ على ما اختار. ومن رجع بلا شيء، أو من الإعدادات، يجد
                // التركيزَ حيث تركه: قفزُه إلى الإذاعة كلَّ رجوعٍ يُشعر أنّ الرجوع
                // لا يرجع.
                TVRecitersView {
                    route = nil
                    if audio.now != .silent { landing = .player }
                }
            }
        }
        .onAppear { settle(); idle.begin(); rehearse() }
        .onPlayPauseCommand { audio.toggle(); idle.poke() }
        .onChange(of: audio.now) { old, new in
            // بدأ صوتٌ من هذه الشاشة: الشريطُ ظهر لتوّه، والتركيزُ إليه — فهو
            // الجوابُ المرئيّ على الضغطة، والبابُ إلى المشغّل. وسكت: الشريطُ
            // زال، فلا يبقى التركيزُ معلّقًا على ما لم يعد موجودًا.
            if old == .silent, new != .silent { focus = .player }
            if new == .silent, focus == .player { focus = .radio }
        }
        .onChange(of: audio.isPlaying) { _, playing in
            // الشاشة تبقى مضيئة ما دام هناك صوت، وتُترك للنظام متى سكت.
            UIApplication.shared.isIdleTimerDisabled = playing
        }
        .tvDim(idle: idle)
    }

    #if DEBUG
    /// «-atharTVPlay radio» أو «-atharTVPlay surah» في وسائط التشغيل تبدأ صوتًا
    /// عند الظهور حتى يُرى شريطُ السماع ويُصوَّر — فالمِرقاب لا يُضغط من سطر
    /// الأوامر. و`#if DEBUG` يمحوها من الإصدار محوًا، كعتبتَي `TVIdle`.
    private func rehearse() {
        switch UserDefaults.standard.string(forKey: "atharTVPlay") {
        case "radio": audio.playRadio()
        case "surah": audio.play(surah: audio.resumable ?? 2)
        default: break
        }
    }
    #else
    private func rehearse() {}
    #endif

    /// أين يقف التركيزُ حين تُرى الشاشة أوّلَ مرّة: على الشريط إن كان شيءٌ يُسمَع،
    /// وإلا على الإذاعة — أقربُ صوتٍ بضغطةٍ واحدة.
    private func settle() {
        focus = audio.now == .silent ? .radio : .player
    }

    /// بعد إغلاق الغطاء. يُؤجَّل دورةً لأنّ النظام يُعيد التركيزَ إلى ما كان قبل
    /// الغطاء حين ينتهي إغلاقُه، فمن سبقه خسر.
    private func land() {
        guard let l = landing else { return }
        landing = nil
        DispatchQueue.main.async { focus = l }
    }

    // MARK: الصدر

    private var header: some View {
        HStack(spacing: 20) {
            Text(loc("أثر"))
                .font(Theme.naskhFont(fixed: TVType.caption, bold: true))
                .foregroundStyle(Theme.inkSoft)
            Spacer(minLength: 0)
        }
    }

    // MARK: ما يُسمَع الآن

    /// سطران وحالٌ ورمز: اسمُ ما يُسمَع، ومَن يُسمِعه أو ما وقع له، وعلى يساره
    /// «المشغّل» بسهمٍ إلى الأمام — فلا يبقى مَن يسأل أين يُقدَّم ويُؤخَّر.
    private var playing: some View {
        let f = focus == .player
        let hurt = audio.problem != nil
        return Button { route = .player; idle.poke() } label: {
            HStack(spacing: 24) {
                Image(systemName: glyph)
                    .font(.system(size: TVType.title, weight: .medium))
                    .foregroundStyle(hurt ? Theme.danger : Theme.accent)
                    .frame(width: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(audio.title)
                        .font(Theme.display(TVType.body, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    Text(status)
                        .font(Theme.display(TVType.footnote, weight: .regular))
                        .foregroundStyle(hurt ? Theme.danger : Theme.inkFaint)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                }
                Spacer(minLength: 14)
                HStack(spacing: 10) {
                    Text(loc("المشغّل"))
                        .font(Theme.display(TVType.caption, weight: .medium))
                    // في العربية يُشار إلى الأمام بسهمٍ إلى اليسار.
                    Image(systemName: "chevron.left")
                        .font(.system(size: TVType.footnote, weight: .semibold))
                }
                .foregroundStyle(f ? Theme.ink : Theme.inkFaint)
            }
            .padding(.horizontal, 32)
            .frame(width: Row.width, height: Row.strip, alignment: .leading)
            .background(
                // التعبئةُ والحدُّ على شكلٍ واحد، وإلا ظهرا مستطيلين متزحزحين.
                RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous)
                    .fill(Theme.accent.opacity(f ? 0.18 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(f ? 0.85 : 0.22), lineWidth: 3)
                    )
            )
        }
        .focused($focus, equals: .player)
        .tvButton(f, radius: TVMetric.tileRadius)
    }

    private var glyph: String {
        if audio.problem != nil { return "wifi.exclamationmark" }
        return audio.isPlaying || audio.isBuffering ? "waveform" : "pause.fill"
    }

    /// الحالُ بلفظها: المنقطعُ يقول ما وقع، والمتوقّفُ يقول إنّه متوقّف — وصمتٌ
    /// بلا سببٍ ظاهر أسوأُ من عطل.
    private var status: String {
        if let problem = audio.problem { return problem }
        if audio.isBuffering { return loc("جارٍ الاتصال…") }
        if !audio.isPlaying { return loc("متوقّف · %1$@", audio.voice) }
        return audio.voice
    }

    // MARK: الصفّ

    private var choices: some View {
        HStack(spacing: TVMetric.gridGap) {
            // الإذاعةُ وهي تُبثّ بالفعل: الضغطةُ تفتح المشغّل لا تُعيد الاتصال
            // من أوّله — من ضغط على ما يسمعه إنّما يُريد أن يراه.
            Button {
                if audio.now == .radio { route = .player } else { audio.playRadio() }
                idle.poke()
            } label: {
                TVTile(title: loc("الإذاعة"),
                       subtitle: LiveSource.radio.channelName,
                       symbol: "dot.radiowaves.left.and.right",
                       tint: Theme.accent,
                       focused: focus == .radio,
                       playing: audio.now == .radio && audio.isPlaying,
                       aspect: Row.wide / Row.height)
                    .frame(width: Row.wide, height: Row.height)
            }
            .focused($focus, equals: .radio)
            .tvButton(focus == .radio, radius: TVMetric.tileRadius)

            Button { route = .reciters } label: {
                TVTile(title: loc("القرّاء"),
                       subtitle: audio.reciter.name,
                       symbol: "person.wave.2",
                       tint: Theme.accent2,
                       focused: focus == .reciters,
                       playing: isSurahPlaying,
                       aspect: Row.wide / Row.height)
                    .frame(width: Row.wide, height: Row.height)
            }
            .focused($focus, equals: .reciters)
            .tvButton(focus == .reciters, radius: TVMetric.tileRadius)

            settings
        }
        .focusSection()
    }

    /// الإعداداتُ مربّعٌ هادئ: حبرٌ لا لونُ طابع، وأضيقُ من جارَيه، وتحت اسمه
    /// ما فيه — فمن يفتحه مرّةً في الشهر يعرف قبل أن يفتحه أنّ اللونَ والنقشَ هناك.
    private var settings: some View {
        let f = focus == .settings
        return Button { route = .settings } label: {
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: "gearshape")
                    .font(.system(size: TVMetric.tileGlyph, weight: .light))
                    .foregroundStyle(f ? Theme.ink : Theme.inkFaint)
                Spacer(minLength: 0)
                Text(loc("الإعدادات"))
                    .font(Theme.display(TVType.body, weight: .bold))
                    .foregroundStyle(f ? Theme.ink : Theme.inkSoft)
                    .multilineTextAlignment(.leading)
                Text(loc("اللون والنقش"))
                    .font(Theme.display(TVType.footnote, weight: .regular))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(TVMetric.tilePad)
            .frame(width: Row.quiet, height: Row.height)
            .background(
                RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous)
                    .fill(Theme.ink.opacity(f ? 0.12 : 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: TVMetric.tileRadius, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(f ? 0.85 : 0), lineWidth: 3)
                    )
            )
        }
        .focused($focus, equals: .settings)
        .tvButton(f, radius: TVMetric.tileRadius)
    }

    private var isSurahPlaying: Bool {
        if case .surah = audio.now { return audio.isPlaying }
        return false
    }

}
