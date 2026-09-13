import SwiftUI

// MARK: - القرّاء
//
// شبكةُ مربّعات لا قائمةَ أسماء: خمسةَ عشرَ قارئًا في صفوفٍ من خمسة، كلُّ مربّعٍ
// يحمل نجمتَه ورقمَه واسمَه — والألوانُ تتدرّج على سلّمٍ واحد بترتيب الشبكة لا
// بعشوائها، فالعينُ تمشي فيها ولا تتعثّر.
//
// وبعد اختيار القارئ سؤالٌ واحد: **ماذا نسمع؟** الاستمرارَ من حيث وقف، أم
// البقرة، أم المصحفَ كاملًا. ثلاثةُ مربّعاتٍ لا قائمةٌ من مئةٍ وأربعَ عشرة —
// ولا يُتصفَّح مصحفٌ بمِرقاب.
//
// والشبكةُ كلُّها في الشاشة، لا تُمرَّر: كانت الصفوفُ الثلاثةُ أطولَ من الشاشة
// فتُلفّ، والمربّعُ المربّعُ إذا نزل التركيزُ إلى الصفّ الأخير صعدت الشبكةُ فوق
// العنوان وزرِّ الرجوع — فبدت الشاشةُ «لخبطة». فقُصّ ارتفاعُ المربّع حتى يسع
// الصفوفَ الثلاثةَ ما بين العنوان وحافّة الأمان، ولا شيءَ يُلفّ ولا شيءَ يُقصّ.
struct TVRecitersView: View {
    @ObservedObject private var audio = TVAudio.shared
    @ObservedObject private var idle = TVIdle.shared
    @FocusState private var focus: Focus?
    @State private var chosen: Reciter?

    /// nil حين تُفتح الشاشةُ بذاتها من سطر الأوامر: لا مجلسَ خلفها يُرجَع إليه.
    var onClose: (() -> Void)?

    private enum Focus: Hashable { case back, reciter(String), what(String) }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: TVMetric.gridGap), count: 5)

    /// نسبةُ ضلعَي مربّع القارئ. خمسةٌ في الصفّ على عرض ١٧٤٠ تعطي ٣٢٧ للمربّع،
    /// وثلاثةُ صفوفٍ مربّعةٍ تحتاج ١٠٣٣ من ٨٥٩ متاحةٍ تحت العنوان — فلا بدّ أن
    /// يكون المربّعُ أعرضَ من طوله. وبهذه النسبة تأخذ الصفوفُ الثلاثةُ ٨٠٧ ويبقى
    /// متّسعٌ لتكبيرة التركيز، والاسمُ ذو السطرين يسعه الارتفاعُ بعدُ.
    private static let aspect: CGFloat = 1.3

    var body: some View {
        TVScreen(title: chosen == nil ? loc("القرّاء") : loc("ماذا نسمع؟"),
                 subtitle: chosen?.name,
                 onBack: canGoBack ? back : nil,
                 backFocused: focus == .back) {
            if let reciter = chosen {
                what(for: reciter)
            } else {
                grid
            }
        }
        // زرُّ القائمة في المِرقاب هو زرُّ «رجوع» نفسُه — يوجد معه ويغيب معه.
        // ولا يُثبَّت دائمًا: `onExitCommand` تبتلع الضغطةَ بمجرّد وجودها ولو
        // لم تفعل شيئًا، فمن فُتحت له الشبكةُ بلا مجلسٍ خلفها كان يضغط القائمة
        // فلا يخرج ولا يرجع.
        .tvExit(canGoBack ? back : nil)
        .onAppear {
            // الشبكةُ تُفتح على قارئه هو. و«ماذا نسمع؟» لها تركيزُها الذي ضُبط
            // عند الاختيار، فلا يُمسّ إن أُعيد الظهورُ ونحن فيها.
            if chosen == nil { focus = .reciter(audio.reciter.id) }
        }
    }

    /// من «ماذا نسمع؟» شيءٌ يُرجَع إليه دائمًا (الشبكة)، ومن الشبكة المجلسُ إن كان.
    private var canGoBack: Bool { chosen != nil || onClose != nil }

    /// من «ماذا نسمع؟» إلى الشبكة — والتركيزُ على القارئ الذي كان قد اختير، لا
    /// على رأس الشبكة — ومن الشبكة إلى المجلس.
    private func back() {
        if let reciter = chosen {
            withAnimation(Motion.gentle) { chosen = nil }
            focus = .reciter(reciter.id)
        } else {
            onClose?()
        }
    }

    // MARK: الشبكة

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: TVMetric.gridGap) {
            ForEach(Array(RecitationLibrary.reciters.enumerated()), id: \.element.id) { pair in
                reciterTile(pair.offset, pair.element)
            }
        }
        .focusSection()
    }

    private func reciterTile(_ index: Int, _ r: Reciter) -> some View {
        let key = Focus.reciter(r.id)
        let isFocused = focus == key
        let sounding = audio.reciter.id == r.id && audio.isPlaying
        return Button {
            audio.choose(r)
            idle.poke()
            withAnimation(Motion.gentle) { chosen = r }
            focus = .what(audio.resumable == nil ? "baqarah" : "continue")
        } label: {
            TVTile(title: r.name,
                   number: index + 1,
                   tint: TVTint.graded(index, of: RecitationLibrary.reciters.count),
                   focused: isFocused,
                   playing: sounding,
                   aspect: Self.aspect)
        }
        .focused($focus, equals: key)
        .tvButton(isFocused, radius: TVMetric.tileRadius)
    }

    // MARK: ماذا نسمع؟

    @ViewBuilder private func what(for reciter: Reciter) -> some View {
        HStack(spacing: TVMetric.gridGap) {
            if let resume = audio.resumable {
                whatTile("continue", loc("الاستمرار"), Quran.surah(resume)?.name,
                         "play.circle", 0) { audio.play(surah: resume) }
            }
            whatTile("baqarah", Quran.surah(2)?.name ?? "", loc("أطول سورة"),
                     "book.closed", 1) { audio.play(surah: 2) }
            whatTile("whole", loc("المصحف كاملًا"), loc("من الفاتحة إلى الناس"),
                     "books.vertical", 2) { audio.play(surah: 1) }
        }
        .frame(maxWidth: 1500, alignment: .leading)
        .focusSection()
    }

    private func whatTile(_ key: String, _ title: String, _ subtitle: String?,
                          _ symbol: String, _ index: Int,
                          action: @escaping () -> Void) -> some View {
        let f = Focus.what(key)
        let isFocused = focus == f
        return Button {
            action()
            idle.poke()
            onClose?()
        } label: {
            TVTile(title: title, subtitle: subtitle, symbol: symbol,
                   tint: TVTint.graded(index, of: 3),
                   focused: isFocused,
                   aspect: 1.15)
        }
        .focused($focus, equals: f)
        .tvButton(isFocused, radius: TVMetric.tileRadius)
    }
}

// MARK: - زرُّ القائمة يتبع زرَّ الرجوع

/// `onExitCommand` لا تُطفأ: وجودُها وحده يبتلع ضغطةَ القائمة، فلا يخرج
/// التطبيقُ من الشاشة الجذر إلى شاشة Apple TV الرئيسة — وذلك شرطُ المراجعة.
/// فتُركَّب حين يكون هناك ما يُرجَع إليه، وتُرفع من الشجرة حين لا يكون؛ وهذا
/// يُعيد بناءَ ما تحتها عند التبدّل، ولا تبدّلَ إلا حيث يتبدّل المحتوى أصلًا.
///
/// موضعُه الطبيعي `TVScreen` — يُلحَق بزرِّ «رجوع» الظاهر فيتّفق الزرّان في
/// كل شاشةٍ بلا سطرٍ فيها — وهو هنا إلى أن يُنقل.
private struct TVExit: ViewModifier {
    var action: (() -> Void)?

    func body(content: Content) -> some View {
        if let action {
            content.onExitCommand(perform: action)
        } else {
            content
        }
    }
}

extension View {
    /// زرُّ القائمة في المِرقاب: `nil` يتركه للنظام.
    func tvExit(_ action: (() -> Void)?) -> some View {
        modifier(TVExit(action: action))
    }
}
