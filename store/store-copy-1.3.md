# أثر — نصوص المتجر للإصدار 1.3

> مسوّدة للّصق في App Store Connect للإصدار 1.3. الاسم والعنوان الفرعي كما في 1.2:
> «أثر — القرآن والأذكار والصلاة» / «مصحف وتفسير وحديث ومواقيت».

## ما الجديد (عربي)

- **بطاقات Apple Wallet**: آية الكرسي وخواتيم البقرة والمعوّذات وسيد الاستغفار وأذكار الصباح والمساء والنوم والسفر والكرب — ست وستون بطاقة بتصميم أثر تُضاف إلى المحفظة بضغطة، نصّها كاملًا على وجهها وظهرها، بلا إنترنت.
- **البث المباشر**: الحرم المكي والحرم النبوي من قناتيهما الرسميتين، وإذاعة القرآن الكريم من هيئة الإذاعة والتلفزيون — تستمر في الخلفية ومن شاشة القفل، ولها قسمها وبطاقتها في «اليوم».
- **الصفحة كاملة على الشاشة**: المصحف يضبط حجم الصفحة لتظهر كلها بلا تمرير، والآية المختارة تُظلَّل كتلةً واحدة متصلة.
- **خط ثمانية**: خطٌّ عربي معاصر لواجهة التطبيق تختاره من الترحيب أو من الإعدادات، مع حجم الخط في المكان نفسه. النص الشرعي يبقى بخط النسخ.
- **عبارات**: آيات وأدعية وتهانٍ للجمعة والعيد ورمضان تنسخها أو تشاركها مباشرة في سناب وواتساب، أو تحوّلها صورةَ ستوري بخلفية أثر.
- **ترحيب من أربع خطوات**: الموقع والتنبيهات والمظهر والخط من أول تشغيل.
- **الصوت يستمر**: التلاوة والإذاعة تعملان بعد إغلاق التطبيق، بتحكّم كامل من شاشة القفل ومركز التحكم.
- **الإعدادات مرتّبة**: المظهر والخط، الصلاة والمواقيت، التذكيرات، المصحف والقراءة، بياناتك، التطبيق — كلٌّ في صفحته.
- **إحسان**: شعار منصة إحسان الملوّن في بطاقة الصدقة، ويتّبع الطابع الموحّد إن اخترته.
- وأذكار وتوثيق المصادر وعشرات التحسينات.

## What's New (English)

- **Apple Wallet cards**: Ayat al-Kursi, the end of al-Baqarah, the three Qul surahs, the master supplication for forgiveness, and morning, evening, sleep, travel and distress adhkar — 66 cards in Athar's design, added to Wallet with one tap, full text on the front and back, no internet needed.
- **Live**: Masjid al-Haram and the Prophet's Mosque from their official channels, plus Saudi Quran Radio — keeps playing in the background with Lock Screen controls, with its own section and Today card.
- **Whole page on screen**: the Mushaf fits each page without scrolling, and the selected ayah is highlighted as one continuous block.
- **Thmanyah typeface**: a contemporary Arabic UI font you can pick during onboarding or in Settings, with text size in the same place. Sacred text stays in Naskh.
- **Phrases**: ayahs, supplications and greetings for Friday, Eid and Ramadan to copy or share straight into Snapchat and WhatsApp, or turn into a story image.
- **Four-step welcome**: location, notifications, appearance and font on first launch.
- **Audio keeps going** after closing the app, with full Lock Screen and Control Centre controls.
- **Settings reorganised** into clear pages: appearance & font, prayer & times, reminders, Mushaf & reading, your data, the app.
- **Ehsan**: the platform's colour logo on the sadaqah card; follows the unified icon style when chosen.
- Plus adhkar, source credits and dozens of refinements.

## ملاحظات للرفع

- **الخصوصية**: البث المباشر يحمّل YouTube (youtube-nocookie) والإذاعة بثّ HLS من هيئة الإذاعة والتلفزيون — بفعل المستخدم فقط؛ `docs/privacy.html` محدَّثة بذلك (مؤرّخة 6 سبتمبر 2026) و**يجب نشرها** بـ `git push` قبل الإرسال.
- **خط ثمانية**: مضمَّن مموَّهًا فقط (`Athar/Resources/Fonts/Obf/*.bin`) وفق الرخصة؛ لا يُنشر ملف الخط الخام أبدًا. ذُكر في «المصادر والحقوق».
- **بطاقات Wallet**: موقَّعة مسبقًا بشهادة Pass Type ID `pass.com.ibrahim.athar` (تنتهي 2027-10-06) — البطاقات المضافة تبقى تعمل بعد انتهاء الشهادة، لكن توليد بطاقات جديدة يحتاج تجديدها. لا استحقاق مطلوب في التطبيق (`PKAddPassesViewController`).
- App Privacy: لا تغيير — لا جمع بيانات.
- لقطات المتجر 1.3: تُولَّد بـ `swift store/render-store-art.swift` بعد لقطات جديدة للبطاقات والبث والعبارات.
