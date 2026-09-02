import Foundation
import SwiftUI

/// لغات واجهة التطبيق. النص الشرعي (القرآن والأذكار) يبقى عربيًا دائمًا —
/// المترجَم هو واجهة الاستخدام فقط.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, ar, en, ur, fa, tr, id, ms, fr, bn

    var id: String { rawValue }

    /// الاسم بلغته هو — كما تعرضه التطبيقات العالمية.
    var title: String {
        switch self {
        case .system: return loc("sysLanguage")
        case .ar: return "العربية"
        case .en: return "English"
        case .ur: return "اردو"
        case .fa: return "فارسی"
        case .tr: return "Türkçe"
        case .id: return "Bahasa Indonesia"
        case .ms: return "Bahasa Melayu"
        case .fr: return "Français"
        case .bn: return "বাংলা"
        }
    }
    var shortTitle: String { title }
    var detail: String { "" }

    /// اللغة الفعلية بعد حلّ «حسب الجهاز».
    var resolved: AppLanguage {
        guard self == .system else { return self }
        for code in Locale.preferredLanguages {
            let p = String(code.prefix(2))
            if let l = AppLanguage(rawValue: p), l != .system { return l }
        }
        return .en
    }

    var isRTL: Bool {
        switch resolved {
        case .ar, .ur, .fa: return true
        default: return false
        }
    }

    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
}

/// الترجمة: مفتاح ← لغة المستخدم، وإلا الإنجليزية، وإلا العربية.
/// القراءة من مجموعة التطبيقات المشتركة لتعمل في الويدجتات أيضًا.
func loc(_ key: String) -> String {
    let stored = UserDefaults(suiteName: AtharStore.appGroup)?
        .string(forKey: "athar.language") ?? "system"
    let lang = (AppLanguage(rawValue: stored) ?? .system).resolved
    return L10nTable.strings[lang.rawValue]?[key]
        ?? L10nTable.strings["en"]?[key]
        ?? L10nTable.strings["ar"]?[key]
        ?? key
}

enum L10nTable {
    static let strings: [String: [String: String]] = [

    "ar": [
      "calc_ummAlQura":"أم القرى (مكة المكرمة)","calc_mwl":"رابطة العالم الإسلامي","calc_egypt":"الهيئة المصرية العامة للمساحة","calc_karachi":"جامعة العلوم الإسلامية، كراتشي","calc_isna":"الجمعية الإسلامية لأمريكا الشمالية","calc_dubai":"الإمارات (دبي)",
      "calcShort_ummAlQura":"أم القرى","calcShort_mwl":"رابطة العالم الإسلامي","calcShort_egypt":"الهيئة المصرية","calcShort_karachi":"كراتشي","calcShort_isna":"ISNA","calcShort_dubai":"الإمارات",
      "asr_standard":"الجمهور (الشافعي والمالكي والحنبلي)","asr_hanafi":"الحنفي","asrShort_standard":"الجمهور","asrShort_hanafi":"الحنفي",
      "theme_paper":"ورق","theme_sepia":"دافئ","theme_night":"ليلي",
      "today":"اليوم","mushaf":"المصحف","adhkar":"الأذكار","prayer":"الصلاة","tasbih":"المسبحة",
      "hajj":"الحج والعمرة","qibla":"القبلة","hifz":"الحفظ","settings":"الإعدادات",
      "fajr":"الفجر","sunrise":"الشروق","dhuhr":"الظهر","asr":"العصر","maghrib":"المغرب","isha":"العشاء",
      "done":"تم","cancel":"إلغاء","later":"لاحقًا","all":"الكل","start":"ابدأ",
      "grpReminders":"التذكير","rowAdhkarRem":"تذكير الأذكار","rowMorning":"أذكار الصباح","rowEvening":"أذكار المساء",
      "grpSunan":"تنويع التذكيرات","rowJumuah":"الجمعة","subJumuah":"الكهف والصلاة على النبي ﷺ",
      "rowFasting":"صيام الاثنين والخميس","subFasting":"تذكير ليلة الصيام",
      "rowWhite":"الأيام البيض","subWhite":"١٣ و١٤ و١٥ من كل شهر هجري",
      "rowQiyam":"قيام الليل","subQiyam":"عند دخول الثلث الأخير",
      "rowIstighfar":"الاستغفار والتسبيح","subIstighfar":"على مدار اليوم",
      "grpPrayer":"الصلاة","rowAthan":"تنبيه دخول الوقت","subAthan":"إشعار عند أذان كل صلاة",
      "rowCalc":"طريقة الحساب","rowAsr":"وقت العصر","rowLocation":"الموقع",
      "grpDisplay":"العرض","rowAppearance":"المظهر","rowFont":"حجم الخط","rowHaptics":"الاهتزاز عند العدّ",
      "grpStats":"أثري","statStreak":"يوم متتابع","statBest":"أطول تتابع","statTotal":"مجموع الأذكار","rowReset":"تصفير الإحصائيات",
      "grpAbout":"عن التطبيق","rowVersion":"الإصدار","rowPrivacy":"سياسة الخصوصية","rowSupport":"الدعم والتواصل",
      "rowSources":"المصادر والحقوق","rowSadaqah":"تصدّق عبر إحسان","rowShare":"انشر التطبيق",
      "appearance":"المظهر","lighting":"الإضاءة","sysMode":"حسب الجهاز","lightMode":"فاتح","darkMode":"داكن",
      "colorTheme":"الطابع اللوني","bottomBar":"الشريط السفلي","reorderBtn":"ترتيب","basicBtn":"الأساسي",
      "language":"اللغة","sysLanguage":"حسب الجهاز",
      "continueReading":"تابع القراءة","myStop":"وقوفي","memorize":"الحفظ","khatmah":"الختمة",
      "startKhatmahSub":"ابدأ تحدي الختم","suras":"السور","searchMushaf":"سورة أو آية",
      "readerFont":"حجم الخط","pageTheme":"سِمة الصفحة","displayMode":"طريقة العرض","modePage":"صفحة","modeAyah":"آية آية",
      "goodMorning":"صباح الخير","goodDay":"طاب يومك","goodEvening":"مساء الخير","goodNight":"طابت ليلتك",
      "dhikrOfDay":"ذكر اليوم","startNow":"ابدأ الآن",
    ],

    "en": [
      "calc_ummAlQura":"Umm al-Qura (Makkah)","calc_mwl":"Muslim World League","calc_egypt":"Egyptian General Authority","calc_karachi":"Univ. of Islamic Sciences, Karachi","calc_isna":"ISNA (North America)","calc_dubai":"UAE (Dubai)",
      "calcShort_ummAlQura":"Umm al-Qura","calcShort_mwl":"MWL","calcShort_egypt":"Egyptian","calcShort_karachi":"Karachi","calcShort_isna":"ISNA","calcShort_dubai":"UAE",
      "asr_standard":"Majority (Shafi'i, Maliki, Hanbali)","asr_hanafi":"Hanafi","asrShort_standard":"Majority","asrShort_hanafi":"Hanafi",
      "theme_paper":"Paper","theme_sepia":"Sepia","theme_night":"Night",
      "today":"Today","mushaf":"Mushaf","adhkar":"Adhkar","prayer":"Prayer","tasbih":"Tasbih",
      "hajj":"Hajj & Umrah","qibla":"Qibla","hifz":"Memorize","settings":"Settings",
      "fajr":"Fajr","sunrise":"Sunrise","dhuhr":"Dhuhr","asr":"Asr","maghrib":"Maghrib","isha":"Isha",
      "done":"Done","cancel":"Cancel","later":"Later","all":"All","start":"Start",
      "grpReminders":"Reminders","rowAdhkarRem":"Adhkar reminder","rowMorning":"Morning adhkar","rowEvening":"Evening adhkar",
      "grpSunan":"More reminders","rowJumuah":"Friday","subJumuah":"Al-Kahf & salawat on the Prophet ﷺ",
      "rowFasting":"Monday & Thursday fasting","subFasting":"Reminder the night before",
      "rowWhite":"White days","subWhite":"13, 14 & 15 of each Hijri month",
      "rowQiyam":"Night prayer","subQiyam":"At the last third of the night",
      "rowIstighfar":"Istighfar & tasbih","subIstighfar":"Gentle reminders through the day",
      "grpPrayer":"Prayer","rowAthan":"Prayer time alert","subAthan":"Notification at every adhan",
      "rowCalc":"Calculation method","rowAsr":"Asr method","rowLocation":"Location",
      "grpDisplay":"Display","rowAppearance":"Appearance","rowFont":"Font size","rowHaptics":"Haptics on count",
      "grpStats":"My athar","statStreak":"day streak","statBest":"best streak","statTotal":"total adhkar","rowReset":"Reset statistics",
      "grpAbout":"About","rowVersion":"Version","rowPrivacy":"Privacy policy","rowSupport":"Support",
      "rowSources":"Sources & rights","rowSadaqah":"Give sadaqah via Ehsan","rowShare":"Share the app",
      "appearance":"Appearance","lighting":"Lighting","sysMode":"System","lightMode":"Light","darkMode":"Dark",
      "colorTheme":"Color theme","bottomBar":"Bottom bar","reorderBtn":"Reorder","basicBtn":"Default",
      "language":"Language","sysLanguage":"System default",
      "continueReading":"Continue reading","myStop":"My stop","memorize":"Memorize","khatmah":"Khatmah",
      "startKhatmahSub":"Start a khatmah challenge","suras":"Surahs","searchMushaf":"Surah or verse",
      "readerFont":"Font size","pageTheme":"Page theme","displayMode":"Display mode","modePage":"Pages","modeAyah":"Verse by verse",
      "goodMorning":"Good morning","goodDay":"Good day","goodEvening":"Good evening","goodNight":"Good night",
      "dhikrOfDay":"Dhikr of the day","startNow":"Start now",
    ],

    "ur": [
      "today":"آج","mushaf":"مصحف","adhkar":"اذکار","prayer":"نماز","tasbih":"تسبیح",
      "hajj":"حج و عمرہ","qibla":"قبلہ","hifz":"حفظ","settings":"ترتیبات",
      "fajr":"فجر","sunrise":"طلوعِ آفتاب","dhuhr":"ظہر","asr":"عصر","maghrib":"مغرب","isha":"عشاء",
      "done":"مکمل","cancel":"منسوخ","later":"بعد میں","all":"سب","start":"شروع کریں",
      "grpReminders":"یاد دہانیاں","rowAdhkarRem":"اذکار کی یاد دہانی","rowMorning":"صبح کے اذکار","rowEvening":"شام کے اذکار",
      "grpSunan":"مزید یاد دہانیاں","rowJumuah":"جمعہ","rowFasting":"پیر اور جمعرات کا روزہ",
      "rowWhite":"ایامِ بیض","rowQiyam":"قیام اللیل","rowIstighfar":"استغفار و تسبیح",
      "grpPrayer":"نماز","rowAthan":"اذان کی اطلاع","rowCalc":"حسابی طریقہ","rowAsr":"عصر کا طریقہ","rowLocation":"مقام",
      "grpDisplay":"ڈسپلے","rowAppearance":"ظاہری شکل","rowFont":"فونٹ سائز","rowHaptics":"گنتی پر ارتعاش",
      "grpStats":"میرا اثر","rowReset":"اعداد و شمار صاف کریں",
      "grpAbout":"ایپ کے بارے میں","rowVersion":"ورژن","rowPrivacy":"رازداری کی پالیسی","rowSupport":"معاونت",
      "appearance":"ظاہری شکل","lighting":"روشنی","sysMode":"سسٹم","lightMode":"روشن","darkMode":"تاریک",
      "colorTheme":"رنگین تھیم","bottomBar":"نچلی پٹی","reorderBtn":"ترتیب","basicBtn":"بنیادی",
      "language":"زبان","sysLanguage":"سسٹم کے مطابق",
      "continueReading":"پڑھنا جاری رکھیں","myStop":"میرا نشان","memorize":"حفظ","khatmah":"ختمِ قرآن",
      "startKhatmahSub":"ختم کا چیلنج شروع کریں","suras":"سورتیں","searchMushaf":"سورت یا آیت",
      "readerFont":"فونٹ سائز","pageTheme":"صفحے کی تھیم","displayMode":"انداز","modePage":"صفحات","modeAyah":"آیت بہ آیت",
      "goodMorning":"صبح بخیر","goodDay":"دن بخیر","goodEvening":"شام بخیر","goodNight":"شب بخیر",
      "dhikrOfDay":"آج کا ذکر","startNow":"ابھی شروع کریں",
    ],

    "fa": [
      "today":"امروز","mushaf":"مصحف","adhkar":"اذکار","prayer":"نماز","tasbih":"تسبیح",
      "hajj":"حج و عمره","qibla":"قبله","hifz":"حفظ","settings":"تنظیمات",
      "fajr":"فجر","sunrise":"طلوع آفتاب","dhuhr":"ظهر","asr":"عصر","maghrib":"مغرب","isha":"عشاء",
      "done":"تمام","cancel":"لغو","later":"بعداً","all":"همه","start":"شروع",
      "grpReminders":"یادآوری‌ها","rowAdhkarRem":"یادآوری اذکار","rowMorning":"اذکار صبح","rowEvening":"اذکار شام",
      "grpSunan":"یادآوری‌های بیشتر","rowJumuah":"جمعه","rowFasting":"روزه دوشنبه و پنجشنبه",
      "rowWhite":"ایام البیض","rowQiyam":"قیام شب","rowIstighfar":"استغفار و تسبیح",
      "grpPrayer":"نماز","rowAthan":"اعلان اذان","rowCalc":"روش محاسبه","rowAsr":"روش عصر","rowLocation":"مکان",
      "grpDisplay":"نمایش","rowAppearance":"ظاهر","rowFont":"اندازه قلم","rowHaptics":"لرزش هنگام شمارش",
      "grpStats":"اثر من","rowReset":"پاک‌کردن آمار",
      "grpAbout":"درباره برنامه","rowVersion":"نسخه","rowPrivacy":"حریم خصوصی","rowSupport":"پشتیبانی",
      "appearance":"ظاهر","lighting":"روشنایی","sysMode":"سیستم","lightMode":"روشن","darkMode":"تیره",
      "colorTheme":"تم رنگی","bottomBar":"نوار پایین","reorderBtn":"مرتب‌سازی","basicBtn":"پیش‌فرض",
      "language":"زبان","sysLanguage":"مطابق دستگاه",
      "continueReading":"ادامه خواندن","myStop":"نشان من","memorize":"حفظ","khatmah":"ختم قرآن",
      "startKhatmahSub":"چالش ختم را شروع کن","suras":"سوره‌ها","searchMushaf":"سوره یا آیه",
      "readerFont":"اندازه قلم","pageTheme":"تم صفحه","displayMode":"حالت نمایش","modePage":"صفحه‌ای","modeAyah":"آیه به آیه",
      "goodMorning":"صبح بخیر","goodDay":"روز بخیر","goodEvening":"عصر بخیر","goodNight":"شب بخیر",
      "dhikrOfDay":"ذکر امروز","startNow":"شروع کن",
    ],

    "tr": [
      "today":"Bugün","mushaf":"Mushaf","adhkar":"Zikirler","prayer":"Namaz","tasbih":"Tesbih",
      "hajj":"Hac ve Umre","qibla":"Kıble","hifz":"Ezber","settings":"Ayarlar",
      "fajr":"Sabah","sunrise":"Güneş","dhuhr":"Öğle","asr":"İkindi","maghrib":"Akşam","isha":"Yatsı",
      "done":"Tamam","cancel":"İptal","later":"Sonra","all":"Tümü","start":"Başla",
      "grpReminders":"Hatırlatıcılar","rowAdhkarRem":"Zikir hatırlatıcısı","rowMorning":"Sabah zikirleri","rowEvening":"Akşam zikirleri",
      "grpSunan":"Diğer hatırlatıcılar","rowJumuah":"Cuma","rowFasting":"Pazartesi-Perşembe orucu",
      "rowWhite":"Eyyam-ı Biyz","rowQiyam":"Gece namazı","rowIstighfar":"İstiğfar ve tesbih",
      "grpPrayer":"Namaz","rowAthan":"Ezan bildirimi","rowCalc":"Hesaplama yöntemi","rowAsr":"İkindi yöntemi","rowLocation":"Konum",
      "grpDisplay":"Görünüm","rowAppearance":"Görünüm","rowFont":"Yazı boyutu","rowHaptics":"Sayımda titreşim",
      "grpStats":"Eserim","rowReset":"İstatistikleri sıfırla",
      "grpAbout":"Uygulama hakkında","rowVersion":"Sürüm","rowPrivacy":"Gizlilik politikası","rowSupport":"Destek",
      "appearance":"Görünüm","lighting":"Aydınlatma","sysMode":"Sistem","lightMode":"Açık","darkMode":"Koyu",
      "colorTheme":"Renk teması","bottomBar":"Alt çubuk","reorderBtn":"Düzenle","basicBtn":"Varsayılan",
      "language":"Dil","sysLanguage":"Sistem dili",
      "continueReading":"Okumaya devam et","myStop":"İşaretim","memorize":"Ezber","khatmah":"Hatim",
      "startKhatmahSub":"Hatim mücadelesi başlat","suras":"Sureler","searchMushaf":"Sure veya ayet",
      "readerFont":"Yazı boyutu","pageTheme":"Sayfa teması","displayMode":"Görünüm modu","modePage":"Sayfa","modeAyah":"Ayet ayet",
      "goodMorning":"Günaydın","goodDay":"İyi günler","goodEvening":"İyi akşamlar","goodNight":"İyi geceler",
      "dhikrOfDay":"Günün zikri","startNow":"Şimdi başla",
    ],

    "id": [
      "today":"Hari Ini","mushaf":"Mushaf","adhkar":"Dzikir","prayer":"Shalat","tasbih":"Tasbih",
      "hajj":"Haji & Umrah","qibla":"Kiblat","hifz":"Hafalan","settings":"Pengaturan",
      "fajr":"Subuh","sunrise":"Terbit","dhuhr":"Dzuhur","asr":"Ashar","maghrib":"Maghrib","isha":"Isya",
      "done":"Selesai","cancel":"Batal","later":"Nanti","all":"Semua","start":"Mulai",
      "grpReminders":"Pengingat","rowAdhkarRem":"Pengingat dzikir","rowMorning":"Dzikir pagi","rowEvening":"Dzikir petang",
      "grpSunan":"Pengingat lainnya","rowJumuah":"Jumat","rowFasting":"Puasa Senin-Kamis",
      "rowWhite":"Ayyamul Bidh","rowQiyam":"Qiyamul lail","rowIstighfar":"Istighfar & tasbih",
      "grpPrayer":"Shalat","rowAthan":"Notifikasi adzan","rowCalc":"Metode hitung","rowAsr":"Metode Ashar","rowLocation":"Lokasi",
      "grpDisplay":"Tampilan","rowAppearance":"Tampilan","rowFont":"Ukuran huruf","rowHaptics":"Getaran saat hitung",
      "grpStats":"Atsarku","rowReset":"Reset statistik",
      "grpAbout":"Tentang aplikasi","rowVersion":"Versi","rowPrivacy":"Kebijakan privasi","rowSupport":"Dukungan",
      "appearance":"Tampilan","lighting":"Pencahayaan","sysMode":"Sistem","lightMode":"Terang","darkMode":"Gelap",
      "colorTheme":"Tema warna","bottomBar":"Bilah bawah","reorderBtn":"Atur","basicBtn":"Bawaan",
      "language":"Bahasa","sysLanguage":"Ikuti perangkat",
      "continueReading":"Lanjutkan membaca","myStop":"Penanda saya","memorize":"Hafalan","khatmah":"Khataman",
      "startKhatmahSub":"Mulai tantangan khatam","suras":"Surah","searchMushaf":"Surah atau ayat",
      "readerFont":"Ukuran huruf","pageTheme":"Tema halaman","displayMode":"Mode tampilan","modePage":"Halaman","modeAyah":"Per ayat",
      "goodMorning":"Selamat pagi","goodDay":"Selamat siang","goodEvening":"Selamat sore","goodNight":"Selamat malam",
      "dhikrOfDay":"Dzikir hari ini","startNow":"Mulai sekarang",
    ],

    "ms": [
      "today":"Hari Ini","mushaf":"Mushaf","adhkar":"Zikir","prayer":"Solat","tasbih":"Tasbih",
      "hajj":"Haji & Umrah","qibla":"Kiblat","hifz":"Hafazan","settings":"Tetapan",
      "fajr":"Subuh","sunrise":"Syuruk","dhuhr":"Zohor","asr":"Asar","maghrib":"Maghrib","isha":"Isyak",
      "done":"Selesai","cancel":"Batal","later":"Kemudian","all":"Semua","start":"Mula",
      "grpReminders":"Peringatan","rowAdhkarRem":"Peringatan zikir","rowMorning":"Zikir pagi","rowEvening":"Zikir petang",
      "grpSunan":"Peringatan lain","rowJumuah":"Jumaat","rowFasting":"Puasa Isnin-Khamis",
      "rowWhite":"Ayyamul Bidh","rowQiyam":"Qiyamullail","rowIstighfar":"Istighfar & tasbih",
      "grpPrayer":"Solat","rowAthan":"Notifikasi azan","rowCalc":"Kaedah kiraan","rowAsr":"Kaedah Asar","rowLocation":"Lokasi",
      "grpDisplay":"Paparan","rowAppearance":"Penampilan","rowFont":"Saiz tulisan","rowHaptics":"Getaran semasa kiraan",
      "grpStats":"Atharku","rowReset":"Set semula statistik",
      "grpAbout":"Tentang aplikasi","rowVersion":"Versi","rowPrivacy":"Dasar privasi","rowSupport":"Sokongan",
      "appearance":"Penampilan","lighting":"Pencahayaan","sysMode":"Sistem","lightMode":"Cerah","darkMode":"Gelap",
      "colorTheme":"Tema warna","bottomBar":"Bar bawah","reorderBtn":"Susun","basicBtn":"Asal",
      "language":"Bahasa","sysLanguage":"Ikut peranti",
      "continueReading":"Sambung bacaan","myStop":"Penanda saya","memorize":"Hafazan","khatmah":"Khatam",
      "startKhatmahSub":"Mula cabaran khatam","suras":"Surah","searchMushaf":"Surah atau ayat",
      "readerFont":"Saiz tulisan","pageTheme":"Tema halaman","displayMode":"Mod paparan","modePage":"Halaman","modeAyah":"Ayat demi ayat",
      "goodMorning":"Selamat pagi","goodDay":"Selamat hari","goodEvening":"Selamat petang","goodNight":"Selamat malam",
      "dhikrOfDay":"Zikir hari ini","startNow":"Mula sekarang",
    ],

    "fr": [
      "today":"Aujourd'hui","mushaf":"Mushaf","adhkar":"Adhkar","prayer":"Prière","tasbih":"Tasbih",
      "hajj":"Hajj et Omra","qibla":"Qibla","hifz":"Mémorisation","settings":"Réglages",
      "fajr":"Fajr","sunrise":"Lever du soleil","dhuhr":"Dhohr","asr":"Asr","maghrib":"Maghreb","isha":"Icha",
      "done":"OK","cancel":"Annuler","later":"Plus tard","all":"Tout","start":"Commencer",
      "grpReminders":"Rappels","rowAdhkarRem":"Rappel des adhkar","rowMorning":"Adhkar du matin","rowEvening":"Adhkar du soir",
      "grpSunan":"Autres rappels","rowJumuah":"Vendredi","rowFasting":"Jeûne lundi-jeudi",
      "rowWhite":"Jours blancs","rowQiyam":"Prière de nuit","rowIstighfar":"Istighfar et tasbih",
      "grpPrayer":"Prière","rowAthan":"Alerte de prière","rowCalc":"Méthode de calcul","rowAsr":"Méthode Asr","rowLocation":"Position",
      "grpDisplay":"Affichage","rowAppearance":"Apparence","rowFont":"Taille du texte","rowHaptics":"Vibration au comptage",
      "grpStats":"Mon athar","rowReset":"Réinitialiser les statistiques",
      "grpAbout":"À propos","rowVersion":"Version","rowPrivacy":"Confidentialité","rowSupport":"Assistance",
      "appearance":"Apparence","lighting":"Éclairage","sysMode":"Système","lightMode":"Clair","darkMode":"Sombre",
      "colorTheme":"Thème de couleur","bottomBar":"Barre inférieure","reorderBtn":"Réorganiser","basicBtn":"Par défaut",
      "language":"Langue","sysLanguage":"Langue du système",
      "continueReading":"Continuer la lecture","myStop":"Mon repère","memorize":"Mémorisation","khatmah":"Khatma",
      "startKhatmahSub":"Lancer un défi de khatma","suras":"Sourates","searchMushaf":"Sourate ou verset",
      "readerFont":"Taille du texte","pageTheme":"Thème de page","displayMode":"Mode d'affichage","modePage":"Pages","modeAyah":"Verset par verset",
      "goodMorning":"Bonjour","goodDay":"Bonne journée","goodEvening":"Bonsoir","goodNight":"Bonne nuit",
      "dhikrOfDay":"Dhikr du jour","startNow":"Commencer",
    ],

    "bn": [
      "today":"আজ","mushaf":"মুসহাফ","adhkar":"যিকির","prayer":"নামায","tasbih":"তাসবীহ",
      "hajj":"হজ ও উমরাহ","qibla":"কিবলা","hifz":"হিফয","settings":"সেটিংস",
      "fajr":"ফজর","sunrise":"সূর্যোদয়","dhuhr":"যোহর","asr":"আসর","maghrib":"মাগরিব","isha":"এশা",
      "done":"সম্পন্ন","cancel":"বাতিল","later":"পরে","all":"সব","start":"শুরু",
      "grpReminders":"রিমাইন্ডার","rowAdhkarRem":"যিকিরের রিমাইন্ডার","rowMorning":"সকালের যিকির","rowEvening":"সন্ধ্যার যিকির",
      "grpSunan":"আরও রিমাইন্ডার","rowJumuah":"জুমা","rowFasting":"সোম-বৃহস্পতিবারের রোযা",
      "rowWhite":"আইয়ামে বীয","rowQiyam":"কিয়ামুল লাইল","rowIstighfar":"ইস্তিগফার ও তাসবীহ",
      "grpPrayer":"নামায","rowAthan":"আযানের নোটিফিকেশন","rowCalc":"হিসাবের পদ্ধতি","rowAsr":"আসরের পদ্ধতি","rowLocation":"অবস্থান",
      "grpDisplay":"ডিসপ্লে","rowAppearance":"চেহারা","rowFont":"লেখার আকার","rowHaptics":"গণনায় কম্পন",
      "grpStats":"আমার আসার","rowReset":"পরিসংখ্যান মুছুন",
      "grpAbout":"অ্যাপ সম্পর্কে","rowVersion":"সংস্করণ","rowPrivacy":"গোপনীয়তা নীতি","rowSupport":"সহায়তা",
      "appearance":"চেহারা","lighting":"আলো","sysMode":"সিস্টেম","lightMode":"হালকা","darkMode":"গাঢ়",
      "colorTheme":"রঙের থিম","bottomBar":"নিচের বার","reorderBtn":"সাজান","basicBtn":"ডিফল্ট",
      "language":"ভাষা","sysLanguage":"ডিভাইস অনুযায়ী",
      "continueReading":"পড়া চালিয়ে যান","myStop":"আমার চিহ্ন","memorize":"হিফয","khatmah":"খতম",
      "startKhatmahSub":"খতম চ্যালেঞ্জ শুরু করুন","suras":"সূরাসমূহ","searchMushaf":"সূরা বা আয়াত",
      "readerFont":"লেখার আকার","pageTheme":"পৃষ্ঠার থিম","displayMode":"প্রদর্শন মোড","modePage":"পৃষ্ঠা","modeAyah":"আয়াত ধরে",
      "goodMorning":"শুভ সকাল","goodDay":"শুভ দিন","goodEvening":"শুভ সন্ধ্যা","goodNight":"শুভ রাত্রি",
      "dhikrOfDay":"আজকের যিকির","startNow":"এখনই শুরু",
    ],
    ]
}
