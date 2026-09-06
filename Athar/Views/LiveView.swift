import SwiftUI
import WebKit

/// البثّ المباشر: قناتا الحرمين الرسميتان (مشغّل YouTube المضمّن) وإذاعة القرآن الكريم صوتًا.
/// لا يُفتح اتصال إلا بفتح هذا القسم (المشغّلان) أو بضغطة «تشغيل» (الإذاعة).
struct LiveView: View {
    @EnvironmentObject private var store: AtharStore
    var isRootTab = false

    private var tint: Color { Theme.accent(for: "sea") }

    var body: some View {
        ZStack {
            AtharBackground(tint: tint, secondary: Theme.gold)
            ScrollView {
                VStack(spacing: 18) {
                    intro.appearStagger(0)
                    ForEach(Array(LiveSource.all.filter(\.isVideo).enumerated()), id: \.element.id) { i, src in
                        LiveVideoCard(source: src, tint: tint, live: Theme.danger)
                            .appearStagger(i + 1)
                    }
                    LiveRadioCard(source: .radio, tint: tint, live: Theme.danger)
                        .appearStagger(3)
                    footer.appearStagger(4)
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 8)
                .padding(.bottom, 34)
                .readableWidth(560)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(loc("البث المباشر"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRootTab ? .visible : .hidden, for: .tabBar)
    }

    private var intro: some View {
        HStack(alignment: .top, spacing: 12) {
            IconChip(icon: "dot.radiowaves.left.and.right", tint: tint, size: .md)
            Text(loc("الحرمان الشريفان من قناتيهما الرسميتين، وإذاعة القرآن الكريم — بثّ حيّ يحتاج اتصالًا بالإنترنت."))
                .font(Theme.display(13))
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        Text(loc("مشغّل الفيديو من YouTube (Google) وتسري سياسته منذ تحميله عند فتح القسم، ولا تبقى بياناته بعد إغلاقه؛ والإذاعة بثّ هيئة الإذاعة والتلفزيون الرسمي ولا يُفتح إلا حين تضغط تشغيلًا."))
            .font(Theme.display(11))
            .foregroundStyle(Theme.inkFaint)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
    }
}

// MARK: - شارة «مباشر»

/// نقطة حمراء وكلمة — اللون يُمرَّر قيمةً ليُعاد رسمها مع تبديل الطابع.
private struct LivePill: View {
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(loc("مباشر"))
        }
        .font(Theme.display(10, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - بطاقة فيديو

private struct LiveVideoCard: View {
    let source: LiveSource
    var tint: Color
    var live: Color
    /// رابط التضمين بعد استخراج معرّف البثّ الجاري (أو تضمين القناة إن تعذّر).
    @State private var embed: URL?

    var body: some View {
        AtharCard(padding: 14, tint: tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    IconChip(icon: source.id == "makkah" ? "building.columns.fill" : "moon.stars.fill", tint: tint, size: .md)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.title)
                            .font(Theme.display(16, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(source.subtitle)
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 6)
                    LivePill(color: live)
                }
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous).fill(Color.black)
                    if let url = embed {
                        LiveWebView(url: url)
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
                .task {
                    guard embed == nil, case .youtubeChannel(let channel) = source.kind else { return }
                    if let id = await LiveSource.resolveLiveVideoId(channel: channel), let u = LiveSource.embedURL(videoId: id) { embed = u }
                    else { embed = source.embedURL }
                }
                Text(loc("المصدر: قناة %1$@ الرسمية على YouTube", source.channelName))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// مشغّل YouTube المضمّن: يُحمَّل الرابط مرة واحدة عند الإنشاء، ويعمل داخل البطاقة بلا ملء الشاشة الإجباري.
private struct LiveWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // مخزن غير دائم: لا تبقى كعكات Google ومعرّفاته بعد إغلاق القسم — كما تعد سياسة الخصوصية.
        config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        // لا يُحمَّل رابط التضمين مباشرةً: YouTube يرفضه بلا مُحيل («خطأ 153 — إعداد المشغّل غير صالح»)،
        // فيُضمَّن في صفحة صغيرة لها أصلٌ حقيقي (موقع التطبيق) داخل iframe، وتُفعَّل واجهة JS لإيقافه.
        let src = url.absoluteString + "&enablejsapi=1&origin=https://ibrahimu.github.io"
        let html = """
        <!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">
        <style>html,body{margin:0;background:transparent;height:100%;overflow:hidden}iframe{position:absolute;inset:0;width:100%;height:100%;border:0}</style>
        </head><body><iframe id="p" src="\(src)" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen playsinline></iframe></body></html>
        """
        web.loadHTMLString(html, baseURL: URL(string: "https://ibrahimu.github.io/athar-app/"))
        context.coordinator.attach(web)
        return web
    }

    // لا إعادة تحميل مع كل إعادة رسم — البثّ يبقى كما تركه المستخدم.
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// محرّكات الصوت (الإذاعة والتلاوة والآية) لا تعرف صفحة الويب، فتُعلن بدءها إشعارًا
    /// ونوقف نحن الفيديو — وإلا سُمع صوتان معًا وعرضت شاشة القفل الإذاعة بينما YouTube يصدح.
    final class Coordinator {
        private weak var web: WKWebView?
        private var observer: NSObjectProtocol?

        func attach(_ web: WKWebView) {
            self.web = web
            observer = NotificationCenter.default.addObserver(
                forName: .atharAudioStarted, object: nil, queue: .main
            ) { [weak self] _ in
                // المشغّل داخل iframe فلا نصل إلى عنصر الفيديو؛ نرسل أمر الإيقاف عبر واجهة YouTube.
                self?.web?.evaluateJavaScript("document.getElementById('p')?.contentWindow.postMessage(JSON.stringify({event:'command',func:'pauseVideo',args:[]}), '*')", completionHandler: nil)
            }
        }

        func detach() {
            if let o = observer { NotificationCenter.default.removeObserver(o); observer = nil }
            web = nil
        }
    }
}

// MARK: - بطاقة الإذاعة

private struct LiveRadioCard: View {
    @EnvironmentObject private var store: AtharStore
    let source: LiveSource
    var tint: Color
    var live: Color
    @ObservedObject private var radio = RadioPlayer.shared

    private var isThisSource: Bool { radio.source?.id == source.id }
    private var playing: Bool { isThisSource && radio.isPlaying }

    var body: some View {
        AtharCard(padding: 16, elevation: .e2, tint: tint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    IconChip(icon: "radio.fill", tint: tint, size: .lg)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(source.title)
                            .font(Theme.display(17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(source.subtitle)
                            .font(Theme.display(12))
                            .foregroundStyle(Theme.inkSoft)
                    }
                    Spacer(minLength: 6)
                    LivePill(color: live)
                }

                playButton

                if isThisSource, radio.isBuffering {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(tint)
                        Text(loc("جارٍ الاتصال…"))
                    }
                    .font(Theme.display(12))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                }
                if isThisSource, let err = radio.error {
                    Text(err)
                        .font(Theme.display(12))
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isThisSource {
                    // الإنهاء بيد المستخدم لا بمغادرة الشاشة: البثّ يستمرّ في الخلفية كالتلاوة.
                    Button {
                        Haptics.tap(enabled: store.hapticsEnabled)
                        radio.stop()
                    } label: {
                        Label(loc("إنهاء البثّ"), systemImage: "stop.fill")
                            .font(Theme.display(13, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(maxWidth: .infinity)
                    }
                    .pressable()
                }

                Text(loc("يُبثّ عبر الإنترنت ويستمرّ في الخلفية وعلى شاشة القفل حتى تُنهيه."))
                    .font(Theme.display(11))
                    .foregroundStyle(Theme.inkFaint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var playButton: some View {
        let label = Label(playing ? loc("إيقاف مؤقّت") : loc("تشغيل"),
                          systemImage: playing ? "pause.fill" : "play.fill")
            .font(Theme.display(17, weight: .semibold))
        Button {
            Haptics.tap(enabled: store.hapticsEnabled)
            if playing { radio.pause() } else if isThisSource { radio.resume() } else { radio.play(source) }
        } label: {
            if playing {
                label.gradientButton(LinearGradient(colors: [tint, tint.opacity(0.82)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                     glow: tint)
            } else {
                label.softButton(tint)
            }
        }
        .pressable()
        .animation(Motion.snappy, value: playing)
    }
}
