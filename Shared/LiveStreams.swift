import Foundation

// MARK: - مصادر البثّ المباشر
//
// قناتا الحرمين الرسميتان (هيئة الإذاعة والتلفزيون السعودية) على YouTube — معرّفاهما مُتحقَّق منهما —
// وبثّ صوتي للقرآن الكريم عبر radiojar. لا يُفتح أيّ اتصال إلا حين يفتح المستخدم القسم أو يضغط «تشغيل».

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

    // البثّ مرحَّل على radiojar لا من خوادم الهيئة (ترويسة icy-name لا تُثبت جهةً رسمية)، فلا
    // يُنسب إلى الهيئة في الواجهة ولا على شاشة القفل حتى يتوفّر عنوان رسمي مُتحقَّق منه.
    static let radio = LiveSource(
        id: "radio",
        title: "إذاعة القرآن الكريم",
        subtitle: "بثّ صوتي متواصل عبر radiojar",
        kind: .radio(URL(string: "https://stream.radiojar.com/0tpy1h0kxtzuv")!),
        channelName: "إذاعة القرآن الكريم")

    static let all: [LiveSource] = [makkah, madinah, radio]
}
