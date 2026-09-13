import SwiftUI
import UIKit

// MARK: - المشغّل
//
// كان الصوتُ يبدأ ولا شاشةَ له: تضغط الإذاعةَ أو سورةً فيُسمَع شيءٌ ولا يُرى ما
// هو، ولا يُقدَّم ولا يُرجَع ولا يُسرَّع ولا يُؤجَّل إيقافُه. فهذه شاشةُ «ما يُسمَع
// الآن»، وإليها يُفضي كلُّ بدءِ صوتٍ — من المجلس أو من القرّاء أو من زرِّ
// التشغيل في المِرقاب — ويُرجَع إليها من المجلس ما دام الصوتُ جاريًا.
//
// وهي من لغة مشغّل الجوال (`PlayerView` في `RecitationView.swift`) لا لغةٍ
// ثانية: النجمةُ برقم السورة، والاسمُ بالنسخ، وشريطُ الموضع يجري من اليسار،
// وصفُّ النقل: السابقة · ترجيع ١٠ · تشغيل · تقديم ١٠ · التالية. ما تعرفه اليدُ
// من الهاتف تجده هنا بمقياس الغرفة.
//
// والإذاعةُ بثٌّ حيٌّ لا أوّلَ له ولا آخر، فلا شريطَ لها ولا تقديمَ ولا «تالية»
// ولا سرعة: ما لا يُقدَر عليه لا يُعرض فيخيب، بل يُحذف فلا يُسأل عنه.
//
// وزرُّ المِرقاب: التشغيل/الإيقاف يعمل من أيّ موضع، والمسحُ يمينًا ويسارًا على
// شريط الموضع يمسح فيه، والقائمةُ ترجع إلى المجلس والصوتُ ماضٍ كما هو.
struct TVPlayerView: View {
    @ObservedObject private var audio = TVAudio.shared
    @ObservedObject private var idle = TVIdle.shared
    @FocusState private var focus: Focus?

    /// nil حين تكون الشاشةَ الجذر (`-screen player` للتصوير): لا شيءَ يُرجَع إليه.
    var onClose: (() -> Void)?

    private enum Focus: Hashable {
        case back, strip, previous, rewind, play, forward, next, speed, sleep, stop
    }

    var body: some View {
        TVGround {
            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 0)
                stage
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TVSafe.horizontal)
            .padding(.vertical, TVSafe.vertical)
        }
        .onAppear(perform: arrive)
        .onDisappear { audio.playerShown = false }
        .onPlayPauseCommand { audio.toggle(); idle.poke() }
        .onExitCommand(perform: close)
        // الإغماءُ يأخذ التركيزَ إلى الغطاء، والإفاقةُ تُعيده إلى زرّ التشغيل لا
        // إلى حيث يقع: من أيقظ الشاشةَ أراد غالبًا أن يُوقف أو يُشغّل.
        .onChange(of: idle.state) { _, state in
            if state == .awake, focus == nil { focus = .play }
        }
        .tvDim(idle: idle)
    }

    private func arrive() {
        audio.playerShown = true
        #if DEBUG
        // «-atharTVSurah 2» أو «-atharTVRadio 1» في وسائط التشغيل مع «-screen
        // player»: يبدآن صوتًا حقيقيًّا فتُصوَّر الشاشةُ بحالها لا فارغة. و`#if
        // DEBUG` يمحوهما من الإصدار.
        let d = UserDefaults.standard
        if audio.now == .silent {
            if d.bool(forKey: "atharTVRadio") { audio.playRadio() }
            else if (1...114).contains(d.integer(forKey: "atharTVSurah")) { audio.play(surah: d.integer(forKey: "atharTVSurah")) }
        }
        #endif
        focus = .play
    }

    private func close() {
        onClose?()
    }

    // MARK: الصدر — الحالُ وزرُّ الرجوع

    /// السطرُ الأوّل يقول الحال بكلمة: يُتلى، يُبثّ، متوقّف، يُحمَّل. والزرُّ إلى
    /// اليسار كما هو في `TVScreen` سواءً بسواء — الشاشةُ ليست منها لأنّ عنوانَها
    /// ليس كلمةً في الصدر بل ما يُسمَع في وسطها، لكنّ زرَّ الرجوع لا يُصمَّم مرّتين.
    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: audio.isPlaying ? "waveform" : "pause")
                    .font(.system(size: TVType.caption, weight: .medium))
                Text(state)
                    .font(Theme.display(TVType.caption, weight: .medium))
            }
            .foregroundStyle(audio.isPlaying ? Theme.accent : Theme.inkFaint)
            Spacer(minLength: 0)
            Button(action: close) {
                HStack(spacing: 10) {
                    Text(loc("رجوع"))
                        .font(Theme.display(TVType.caption, weight: .medium))
                    // في العربية يُشار إلى الوراء بسهمٍ إلى اليمين.
                    Image(systemName: "chevron.right")
                        .font(.system(size: TVType.caption, weight: .semibold))
                }
                .foregroundStyle(focus == .back ? Theme.ink : Theme.inkFaint)
                .padding(.horizontal, 26)
                .frame(height: 62)
                .background(Capsule().fill(Theme.accent.opacity(focus == .back ? 0.18 : 0.06)))
            }
            .focused($focus, equals: .back)
            .tvButton(focus == .back, radius: 31)
        }
    }

    private var state: String {
        if audio.isBuffering { return loc("جارٍ التحميل…") }
        switch audio.now {
        case .silent: return loc("لا صوت")
        case .radio:  return audio.isPlaying ? loc("يُبثّ الآن") : loc("متوقّف")
        case .surah:  return audio.isPlaying ? loc("يُتلى الآن") : loc("متوقّف")
        }
    }

    // MARK: المسرح

    @ViewBuilder private var stage: some View {
        switch audio.now {
        case .surah(let id):
            if let su = Quran.surah(id) { surah(su) }
        case .radio:
            radio
        case .silent:
            silent
        }
    }

    /// السورة: النجمةُ برقمها واسمُها والقارئ، ثمّ الشريط، ثمّ صفُّ النقل، ثمّ
    /// الخيارات. كلُّ نصٍّ يبدأ من اليمين؛ وصفُّ النقل وحده في الوسط لأنّ زرَّ
    /// التشغيل قلبُه والزمنُ يجري عن يمينه ويساره.
    private func surah(_ su: Surah) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 40) {
                disc {
                    Text(su.id.counterText)
                        .font(Theme.display(TVType.title, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("سورة %1$@", su.name))
                        .font(Theme.naskhFont(fixed: TVType.hero, bold: true))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    Text("\(audio.reciter.name) · \(su.revelation) · \(su.ayahCount.ayahCountText)")
                        .font(Theme.display(TVType.body, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    if let problem = audio.problem { trouble(problem) }
                }
            }
            strip
                .padding(.top, 50)
            transport
                .padding(.top, 36)
            options
                .padding(.top, 44)
        }
    }

    /// الإذاعة: الاسمُ والجهة وشارةُ «مباشر»، وزرُّ التشغيل وحده في صفّ النقل.
    private var radio: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 40) {
                disc {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: TVType.hero, weight: .light))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(LiveSource.radio.title)
                        .font(Theme.display(TVType.hero, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                    HStack(spacing: 18) {
                        live
                        Text(LiveSource.radio.subtitle)
                            .font(Theme.display(TVType.body, weight: .regular))
                            .foregroundStyle(Theme.inkSoft)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                    }
                    if let problem = audio.problem { trouble(problem) }
                }
            }
            transport
                .padding(.top, 60)
            options
                .padding(.top, 44)
        }
    }

    /// لا صوت: لا يُفتح المشغّلُ على هذا عادةً، لكنّ المصحفَ ينتهي بالناس والمؤقّتَ
    /// يُطفئ — فتبقى الشاشةُ صادقةً ولا تعرض شريطًا لشيءٍ ليس هناك.
    private var silent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 40) {
                disc {
                    Image(systemName: "waveform")
                        .font(.system(size: TVType.hero, weight: .light))
                        .foregroundStyle(Theme.inkFaint)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text(loc("لا شيء يُسمَع الآن"))
                        .font(Theme.display(TVType.hero, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(loc("التشغيل يبدأ الإذاعة، والرجوع يعود إلى المجلس لاختيار قارئ."))
                        .font(Theme.display(TVType.body, weight: .regular))
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
            }
            transport
                .padding(.top, 60)
        }
    }

    /// شارةُ «مباشر»: نقطةٌ حمراء وكلمة — هي شارةُ الإذاعة في الجوال (`RadioLivePill`).
    private var live: some View {
        HStack(spacing: 10) {
            Circle().fill(Theme.danger)
                .frame(width: TVPlayerMetric.liveDot, height: TVPlayerMetric.liveDot)
            Text(loc("مباشر"))
                .font(Theme.display(TVType.caption, weight: .bold))
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 18)
        .frame(height: 46)
        .background(Capsule().fill(Theme.danger.opacity(0.14)))
    }

    /// العلّةُ بلفظها وحيث يقع أثرُها — تحت اسم ما تعذّر، لا في زاويةٍ بعيدة.
    private func trouble(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: TVType.caption, weight: .medium))
            Text(text)
                .font(Theme.display(TVType.caption, weight: .regular))
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(Theme.danger)
        .padding(.top, 6)
    }

    /// قرصُ السورة — نجمةُ `SurahDisc` في الجوال بمقياس الغرفة: تعبئةٌ خفيفة،
    /// وحدٌّ بتدرّج الطابع، ونجمةٌ داخلية أرفع.
    private func disc<Inner: View>(@ViewBuilder inner: () -> Inner) -> some View {
        let size = TVPlayerMetric.disc
        return ZStack {
            TVStar(innerRatio: 0.66)
                .fill(Theme.accent.opacity(0.10))
            TVStar(innerRatio: 0.66)
                .stroke(Theme.accentGradient, lineWidth: 4)
            TVStar(innerRatio: 0.74)
                .stroke(Theme.accent.opacity(0.30), lineWidth: 1.5)
                .padding(size * 0.11)
            inner()
        }
        .frame(width: size, height: size)
    }

    // MARK: شريط الموضع

    /// زرٌّ يُركَّز عليه: المسحُ يمينًا ويسارًا يمسح في السورة (`scrub`)، والضغطُ
    /// يُوقف ويُعيد، والأعلى والأسفل يُنقلان بأيدينا — لأنّ `onMoveCommand`
    /// يأخذ الجهاتِ الأربعَ كلَّها ولا يترك للنظام منها شيئًا.
    ///
    /// والزمنُ يجري من اليسار دائمًا، فالشريطُ ثابتٌ على `.leftToRight` ولو كانت
    /// الشاشةُ كلُّها من اليمين — كما في الجوال حرفًا.
    private var strip: some View {
        let focused = focus == .strip
        let clamped = min(1, max(0, audio.progress))
        return Button { audio.toggle() } label: {
            VStack(spacing: 16) {
                GeometryReader { g in
                    let h = TVPlayerMetric.stripHeight
                    let knob = TVPlayerMetric.knob
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.accent.opacity(0.16))
                            .frame(height: h)
                        Capsule().fill(Theme.accentGradient)
                            .frame(width: max(h, g.size.width * clamped), height: h)
                        if audio.duration > 0 {
                            Circle()
                                .fill(Theme.canvas)
                                .overlay(Circle().strokeBorder(Theme.accent, lineWidth: focused ? 6 : 4))
                                .frame(width: knob, height: knob)
                                .offset(x: (g.size.width - knob) * clamped)
                        }
                    }
                    .frame(height: knob)
                }
                .frame(height: TVPlayerMetric.knob)
                HStack {
                    Text(clock(audio.elapsed))
                    Spacer(minLength: 0)
                    Text(audio.duration > 0 ? "−" + clock(max(0, audio.duration - audio.elapsed)) : "—")
                }
                .font(Theme.display(TVType.footnote, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(focused ? Theme.ink : Theme.inkFaint)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: TVPlayerMetric.stripRadius, style: .continuous)
                    .fill(Theme.accent.opacity(focused ? 0.10 : 0))
                    .overlay(
                        RoundedRectangle(cornerRadius: TVPlayerMetric.stripRadius, style: .continuous)
                            .strokeBorder(Theme.accent.opacity(focused ? 0.85 : 0), lineWidth: 3)
                    )
            )
            .environment(\.layoutDirection, .leftToRight)
        }
        .focused($focus, equals: .strip)
        .tvButton(focused, radius: TVPlayerMetric.stripRadius)
        .onMoveCommand { direction in
            switch direction {
            case .left:  audio.scrub(forward: false)
            case .right: audio.scrub(forward: true)
            case .up:    focus = .back
            case .down:  focus = .play
            @unknown default: break
            }
            idle.poke()
        }
        .accessibilityLabel(loc("موضع التلاوة"))
    }

    // MARK: صفُّ النقل

    /// السابقة · ترجيع ١٠ · تشغيل · تقديم ١٠ · التالية، من اليسار كالشريط فوقه:
    /// الرجوعُ يسارًا حيث أوّلُ الشريط، والتقديمُ يمينًا حيث آخرُه. وللإذاعة
    /// زرُّ التشغيل وحده.
    private var transport: some View {
        HStack(spacing: TVPlayerMetric.transportGap) {
            if audio.canSeek {
                round(.previous, "backward.end.fill", size: TVType.body,
                      label: loc("السورة السابقة"), enabled: audio.canGoPrevious) { audio.previous() }
                round(.rewind, "gobackward.10", size: TVType.title,
                      label: loc("ترجيع عشر ثوانٍ")) { audio.seek(by: -TVAudio.skip) }
            }
            play
            if audio.canSeek {
                round(.forward, "goforward.10", size: TVType.title,
                      label: loc("تقديم عشر ثوانٍ")) { audio.seek(by: TVAudio.skip) }
                round(.next, "forward.end.fill", size: TVType.body,
                      label: loc("السورة التالية"), enabled: audio.canGoNext) { audio.next() }
            }
        }
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .leftToRight)
    }

    /// زرُّ التشغيل: القرصُ الممتلئ بتدرّج الطابع كما في الجوال (`PlayGlyph`)،
    /// وفي التحميل دوّامةٌ مكانَ الرمز — حركةٌ تقول شيئًا لا زينة.
    private var play: some View {
        let focused = focus == .play
        let d = TVPlayerMetric.play
        return Button { audio.toggle() } label: {
            ZStack {
                Circle().fill(Theme.accentGradient)
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(focused ? 0.9 : 0), lineWidth: 4))
                if audio.isBuffering {
                    ProgressView()
                        .tint(Theme.onAccent)
                        .scaleEffect(2)
                } else {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: TVType.hero, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                }
            }
            .frame(width: d, height: d)
        }
        .focused($focus, equals: .play)
        .tvButton(focused, radius: d / 2)
        .accessibilityLabel(audio.isBuffering ? loc("جارٍ التحميل")
                            : (audio.isPlaying ? loc("إيقاف مؤقّت") : loc("تشغيل")))
    }

    /// زرٌّ دائريّ من أزرار النقل. التعبئةُ والحدُّ على شكلٍ واحد لا شكلين.
    private func round(_ key: Focus, _ symbol: String, size: CGFloat, label: String,
                       enabled: Bool = true, _ action: @escaping () -> Void) -> some View {
        let focused = focus == key
        let d = TVPlayerMetric.skip
        return Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(enabled ? (focused ? Theme.ink : Theme.inkSoft) : Theme.inkFaint.opacity(0.35))
                .frame(width: d, height: d)
                .background(
                    Circle().fill(Theme.accent.opacity(focused ? 0.28 : 0.10))
                        .overlay(Circle().strokeBorder(Theme.accent.opacity(focused ? 0.9 : 0), lineWidth: 3))
                )
        }
        .focused($focus, equals: key)
        .tvButton(focused, radius: d / 2)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    // MARK: الخيارات — السرعة، مؤقّت النوم، الإنهاء

    /// رقائقُ نصٍّ إلى اليمين: كلُّ رقيقةٍ تقول حالَها بلفظه وتُبدّله بضغطة —
    /// لا قوائمَ منبثقة على مِرقاب. والعدُّ التنازلي للمؤقّت يتجدّد كلَّ نصف
    /// دقيقة لا كلَّ ثانية: يُقرأ بالدقائق، والثانيةُ فيه حركةٌ بلا معنى.
    private var options: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 18) {
                chip(.sleep, "moon.zzz.fill", sleepLabel(at: context.date), on: audio.sleep.isOn) {
                    audio.cycleSleep()
                }
                if audio.canChangeRate {
                    chip(.speed, "speedometer", rateLabel, on: audio.rate != 1) { audio.cycleRate() }
                }
                chip(.stop, "stop.fill", loc("إنهاء"), on: false) {
                    audio.stop()
                    close()
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func chip(_ key: Focus, _ symbol: String, _ title: String, on: Bool,
                      _ action: @escaping () -> Void) -> some View {
        let focused = focus == key
        return Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: TVType.caption, weight: .medium))
                    .foregroundStyle(on || focused ? Theme.accent : Theme.inkFaint)
                Text(title)
                    .font(Theme.display(TVType.caption, weight: on ? .semibold : .medium))
                    .foregroundStyle(focused ? Theme.ink : (on ? Theme.accent : Theme.inkSoft))
                    .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .frame(height: TVPlayerMetric.chip)
            .background(
                Capsule()
                    .fill(Theme.accent.opacity(focused ? 0.18 : (on ? 0.12 : 0.06)))
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(focused ? 0.85 : 0), lineWidth: 3))
            )
        }
        .focused($focus, equals: key)
        .tvButton(focused, radius: TVPlayerMetric.chip / 2)
    }

    private var rateLabel: String {
        audio.rate == 1 ? loc("السرعة العادية")
                        : loc("السرعة ×%1$@", String(format: "%g", audio.rate))
    }

    /// «مؤقّت النوم» مطفأً، و«يتوقّف بعد ١٤ دقيقة» جاريًا — بتمييز العدد: من
    /// ثلاثٍ إلى عشرٍ «دقائق» وما عداها «دقيقة».
    private func sleepLabel(at date: Date) -> String {
        switch audio.sleep {
        case .off:
            return loc("مؤقّت النوم")
        case .endOfSurah:
            return loc("يتوقّف عند نهاية السورة")
        case .minutes:
            guard let end = audio.sleepEndsAt else { return loc("مؤقّت النوم") }
            let m = max(1, Int(ceil(end.timeIntervalSince(date) / 60)))
            let unit = (3...10).contains(m) ? loc("دقائق") : loc("دقيقة")
            return loc("يتوقّف بعد %1$@ %2$@", m.counterText, unit)
        }
    }

    /// «د:ثث» بأرقامٍ غربية — صيغةُ `clockText` في الجوال، وهي في ملفٍّ ليس في
    /// هدف التلفاز.
    private func clock(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let t = Int(seconds)
        let h = t / 3600, m = (t % 3600) / 60, s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s)
                     : String(format: "%d:%02d", m, s)
    }
}

// MARK: - مقاساتُ المشغّل

/// لا رقمَ في موضعه — tvOS بلا «حجمٍ ديناميكي»، فما كُتب رقمًا بقي رقمًا على
/// شاشة خمسٍ وستّين بوصة. والأحجامُ من مسافة النظر: ثلاثةُ أمتار.
private enum TVPlayerMetric {
    /// نجمةُ السورة — أكبرُ ما في المسرح بعد الاسم.
    static let disc: CGFloat = 170
    /// زرُّ التشغيل، قلبُ الصفّ.
    static let play: CGFloat = 150
    /// أزرارُ النقل حوله.
    static let skip: CGFloat = 110
    static let transportGap: CGFloat = 34
    /// شريطُ الموضع ومقبضُه.
    static let stripHeight: CGFloat = 10
    static let knob: CGFloat = 30
    static let stripRadius: CGFloat = 22
    /// رقائقُ الخيارات.
    static let chip: CGFloat = 72
    /// نقطةُ «مباشر».
    static let liveDot: CGFloat = 14
}

// MARK: - مربّعُ «يُسمَع الآن» للمجلس

/// عنوانُ ما يُسمَع وصوتُه في مربّعٍ كسائر مربّعات المجلس، يُوضع فيه ما دام
/// الصوتُ جاريًا وضغطتُه تفتح المشغّل (`TVPlayerPresenter.present()`). المجلسُ
/// هو من يضعه — زرًّا بتركيزه هو — وهذا تسميتُه وشكلُه فقط، فلا يُصمَّم مرّتين.
struct TVNowPlayingTile: View {
    @ObservedObject private var audio = TVAudio.shared
    var focused: Bool
    var aspect: CGFloat = 1.35

    var body: some View {
        TVTile(title: audio.title,
               subtitle: audio.voice,
               symbol: audio.isPlaying ? "waveform" : "pause.circle",
               tint: Theme.accent,
               focused: focused,
               playing: audio.isPlaying,
               aspect: aspect)
    }
}

// MARK: - فتحُ المشغّل

/// يُفتح من `TVAudio` حين يبدأ صوت، أيًّا كانت الشاشةُ التي بدأته — فلا يُعلَّق
/// بمجلسٍ ولا بقرّاء. ويُقدَّم بـUIKit لا بـ`fullScreenCover`: الغطاءُ يلزمه
/// عرضٌ في شاشةٍ بعينها، وشاشةُ القرّاء تُغلق نفسها في اللحظة التي تبدأ فيها
/// الصوت، فلو قُدّم المشغّلُ فوقها لذهب بذهابها. فيُنتظر حتى لا يبقى شيءٌ
/// معروضًا فوق الجذر ثمّ يُقدَّم من الجذر نفسه — نافذةٌ واحدة، فمراقبُ المِرقاب
/// في `TVIdle` يرى ضغطاتِه كما يرى ضغطاتِ المجلس.
@MainActor
enum TVPlayerPresenter {
    private static var host: UIViewController?

    static func present() {
        guard host == nil, !TVAudio.shared.playerShown else { return }
        Task { await presentWhenClear() }
    }

    static func dismiss() {
        guard let vc = host else { return }
        host = nil
        vc.dismiss(animated: true)
    }

    private static func presentWhenClear() async {
        // غطاءُ القرّاء يُغلق نفسه في نحو نصف ثانية؛ والسقفُ ثلاثُ ثوانٍ لئلّا
        // ينتظر أحدٌ شاشةً لا تأتي: بعدها يُقدَّم فوق ما هو معروض كائنًا ما كان.
        for _ in 0..<30 {
            guard let root else { return }
            if root.presentedViewController == nil { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        guard host == nil, !TVAudio.shared.playerShown, var top = root else { return }
        while let above = top.presentedViewController { top = above }
        let vc = UIHostingController(rootView:
            TVPlayerView { dismiss() }
                .environment(\.layoutDirection, .rightToLeft))
        vc.modalPresentationStyle = .fullScreen
        vc.overrideUserInterfaceStyle = .dark
        host = vc
        top.present(vc, animated: true)
    }

    private static var root: UIViewController? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        return (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
    }
}
