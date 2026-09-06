import Foundation

// MARK: - مصادر البثّ المباشر
//
// قناتا الحرمين الرسميتان (هيئة الإذاعة والتلفزيون السعودية) على YouTube — معرّفاهما مُتحقَّق منهما —
// وبثّ إذاعة القرآن الكريم الرسمي من هيئة الإذاعة والتلفزيون. لا يُفتح أيّ اتصال إلا حين يفتح المستخدم القسم أو يضغط «تشغيل».

struct LiveSource: Identifiable, Hashable {
    enum Kind: Hashable {
        /// معرّف قناة YouTube — يُعرض بثّها الحيّ الجاري عبر مشغّل التضمين الرسمي.
        case youtubeChannel(String)
        /// عنوان بثّ صوتي (audio/mpeg) يُشغَّل بـ AVPlayer.
        case radio(URL)
    }

    let id: String
    let title: String
    let subtitle: String
    let kind: Kind
    /// اسم القناة كما يظهر في سطر «المصدر» أسفل المشغّل.
    let channelName: String

    var isVideo: Bool {
        if case .youtubeChannel = kind { return true }
        return false
    }

    /// رابط تضمين البثّ الحيّ للقناة — بلا تشغيل تلقائي: الاتصال بـ YouTube بيد المستخدم.
    /// المضيف youtube-nocookie هو «وضع الخصوصية المحسَّن» الرسمي: لا كعكات تتبّع قبل التشغيل.
    var embedURL: URL? {
        guard case .youtubeChannel(let channel) = kind else { return nil }
        return URL(string: "https://www.youtube-nocookie.com/embed/live_stream?channel=\(channel)&playsinline=1&rel=0&modestbranding=1")
    }

    var streamURL: URL? {
        guard case .radio(let url) = kind else { return nil }
        return url
    }

    static let makkah = LiveSource(
        id: "makkah",
        title: "المسجد الحرام",
        subtitle: "قناة القرآن الكريم — بث مباشر من مكة",
        kind: .youtubeChannel("UCos52azQNBgW63_9uDJoPDA"),   // @SaudiQuranTv الرسمية
        channelName: "القرآن الكريم")

    static let madinah = LiveSource(
        id: "madinah",
        title: "المسجد النبوي",
        subtitle: "قناة السنة النبوية — بث مباشر من المدينة",
        kind: .youtubeChannel("UCROKYPep-UuODNwyipe6JMw"),   // @SaudiSunnahTv الرسمية
        channelName: "السنة النبوية")

    // البثّ الرسمي: عنوان HLS الذي يستخدمه مشغّل «Saudi Radio +» التابع لهيئة الإذاعة والتلفزيون
    // (radioplus.sba.sa ← api/v1.1/channels/4/player/audio)، تحقّقنا منه في 6 سبتمبر 2026.
    static let radio = LiveSource(
        id: "radio",
        title: "إذاعة القرآن الكريم",
        subtitle: "هيئة الإذاعة والتلفزيون السعودية — بثّ رسمي متواصل",
        kind: .radio(URL(string: "https://live.kwikmotion.com/sbrksaquranradiolive/ksaquranradio/playlist.m3u8")!),
        channelName: "إذاعة القرآن الكريم")

    static let all: [LiveSource] = [makkah, madinah, radio]

    /// تضمين البثّ بمعرّف القناة لا يعمل لكل القنوات («هذا الفيديو غير متاح» لقناة القرآن الكريم)، بينما تضمين
    /// معرّف الفيديو الجاري يعمل — لكنه يتغيّر حين تُعاد إذاعة البثّ. فنستخرج المعرّف الجاري من صفحة
    /// «/live» للقناة عند فتح القسم ونسقط إلى تضمين القناة إن تعذّر.
    static func resolveLiveVideoId(channel: String) async -> String? {
        guard let url = URL(string: "https://www.youtube.com/channel/\(channel)/live") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36", forHTTPHeaderField: "User-Agent")
        req.setValue("ar,en", forHTTPHeaderField: "Accept-Language")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let html = String(data: data, encoding: .utf8),
              let range = html.range(of: #"<link rel="canonical" href="https://www\.youtube\.com/watch\?v=([A-Za-z0-9_-]{11})""#, options: .regularExpression)
        else { return nil }
        let tag = html[range]
        guard let eq = tag.range(of: "v=") else { return nil }
        return String(tag[eq.upperBound...].prefix(11))
    }

    /// رابط تضمين فيديو بعينه (وضع الخصوصية المحسَّن).
    static func embedURL(videoId: String) -> URL? {
        URL(string: "https://www.youtube-nocookie.com/embed/\(videoId)?playsinline=1&rel=0&modestbranding=1")
    }
}
