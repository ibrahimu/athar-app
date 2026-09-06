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
}
