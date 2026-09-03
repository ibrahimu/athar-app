# أثر — نصوص المتجر للإصدار القادم (build 6)

> مسوّدة جاهزة للّصق في App Store Connect. القرار المعلَّق: هل يُرفع كبناء ٦ بديلًا عن البناء ٥ المنتظر للمراجعة (فيُسحب ٥)، أم كإصدار 1.2 بعد نزول 1.1؟ في الحالة الثانية غيّر `MARKETING_VERSION` إلى 1.2 قبل الأرشفة.

## ما الجديد (عربي)

- **التلاوة الصوتية**: استمع للقرآن بصوت ١٥ قارئًا — بثًّا مباشرًا، أو نزّل السور لتسمعها بلا إنترنت. مشغّل كامل: تقديم وترجيع، تكرار، سرعة، مؤقّت نوم، وتحكّم من شاشة القفل.
- **أصوات الأذان**: اختر صوت تنبيه الأذان من عدّة تسجيلات باسم أصحابها، واستمع إليه كاملًا قبل اختياره.
- **الأقسام**: كل أقسام التطبيق في متناول اليد — الحج والعمرة، القبلة، الحفظ، التلاوة — حتى ما لم يسعه الشريط السفلي.
- **مصحف مؤطَّر**: نمط عرض ثالث للمصحف بإطار مزخرف كالمصحف المطبوع.
- **خطّ يتبع حجم خطّ النظام**، وتباين أعلى للنصوص الصغيرة، وتسميات صوتية لكل الأزرار.
- الختمة تتقدّم من قراءتك في المصحف نفسه، والورد اليومي صار له مدخل من المصحف.
- عشرات التحسينات في التصميم واللغة بعد مراجعة كل شاشة، وإصلاح ما وُجد من أخطاء.

## What's New (English)

- **Quran recitation**: listen with 15 reciters — stream, or download surahs for offline listening. Full player with seek, repeat, speed, sleep timer and lock-screen controls.
- **Adhan sounds**: pick the athan alert from several named recordings and preview each in full.
- **Sections**: every part of the app is one tap away — Hajj & Umrah, Qibla, memorization, recitation — even when it doesn't fit the tab bar.
- **Framed Mushaf**: a third reading style with an ornamental page frame.
- UI text now follows Dynamic Type, small text has higher contrast, and every control has a VoiceOver label.
- Khatmah progress advances from what you actually read in the Mushaf; the daily wird is reachable from the Mushaf.
- Dozens of design and wording refinements after a screen-by-screen review, plus bug fixes.

## ملاحظات للرفع

- سياسة الخصوصية (docs/privacy.html) حُدِّثت محليًّا لذكر اتصال التلاوة الاختياري بـ MP3Quran.net — **يجب نشرها على GitHub Pages قبل الإرسال** (`git push`).
- في App Privacy بالمتجر لا تغيير: التطبيق لا يجمع بيانات؛ الطلبات الشبكية بفعل المستخدم ولا تحمل معرّفات.
- لقطات المتجر ما زالت من 1.0 — تحديثها بالسحب والإفلات من `store_final/` في مجلّد الجلسة.
