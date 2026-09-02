# أثر — Athar

تطبيق iOS للأذكار وأوقات الصلاة والمسبحة. مجاني بالكامل، بلا إعلانات، بلا حسابات، ويعمل بدون إنترنت.

An iOS app for Islamic remembrances (adhkar), prayer times, and a tasbih counter. Completely free, no ads, no accounts, works entirely offline.

**[الموقع](https://ibrahimu.github.io/athar-app/) · [سياسة الخصوصية](https://ibrahimu.github.io/athar-app/privacy.html) · [الدعم](https://ibrahimu.github.io/athar-app/support.html)**

---

## المزايا

- **١٠٨ أذكار** في ١٠ أقسام — الصباح، المساء، النوم، الاستيقاظ، بعد الصلاة، الهم والكرب، الاستغفار، الصلاة على النبي ﷺ، الباقيات الصالحات، وأذكار اليوم والليلة. كل ذكر مشكول بالكامل ومقترن بتخريجه وفضله.
- **أوقات الصلاة** — تُحسب فلكيًا على الجهاز، مع ٦ طرق حساب (أم القرى افتراضيًا)، مذهبي العصر، عدّ تنازلي حي، وتنبيه عند دخول الوقت.
- **اتجاه القبلة** — بوصلة إلى الكعبة بحساب الدائرة العظمى، مع الزاوية والمسافة، وتنبيه عند الانطباق.
- **المسبحة** — أهداف ٣٣ / ١٠٠ / ٥٠٠ / ١٠٠٠ مع الاهتزاز وعدّ الأشواط.
- **ويدجتات** للشاشة الرئيسية وشاشة القفل: ذِكر متجدد، الصلاة القادمة، والتتابع اليومي.
- **تتابع يومي** يشجّع على المداومة، وتذكير للصباح والمساء.
- **بدون إنترنت ولا حسابات ولا تتبّع** — الطلب الشبكي الوحيد هو تحويل الإحداثيات إلى اسم مدينة عبر خدمة Apple، ولا يقع إلا إن فعّلت الموقع.

## البناء

يتطلب Xcode 16+ و [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open Athar.xcodeproj
```

## البنية

```
Shared/          نماذج ومحرّك أوقات الصلاة والثيم — مشتركة بين التطبيق والويدجت
  adhkar.json    نصوص الأذكار
  PrayerTimes.swift  حساب فلكي بحت، بلا شبكة
Athar/           التطبيق (SwiftUI)
AtharWidget/     إضافة الويدجت (WidgetKit)
docs/            الموقع وسياسة الخصوصية (GitHub Pages)
```

## المصادر والحقوق

**نص المصحف** بالرسم العثماني من **مشروع تنزيل — [tanzil.net](https://tanzil.net)**،
مُدقَّق على مصحف المدينة النبوية، ومنقول كما هو دون أي تغيير.
تشترط رخصة المشروع إظهار المصدر بوضوح مع رابط إليه، وعدم تغيير النص — والتطبيق يعرض
هذا الإسناد في شاشة المصحف وفي «الإعدادات ← المصادر والحقوق».

> Quran text from the [Tanzil Project](https://tanzil.net), verbatim and unmodified.
> Permission is granted to copy and distribute verbatim copies of the Quran text,
> provided the source (Tanzil Project) is clearly indicated and a link is made to tanzil.net.

**نصوص الأذكار** من القرآن الكريم والسنة الصحيحة، مع تخريج كل ذكر.

**الخط** Noto Naskh Arabic من مشروع Noto، برخصة SIL Open Font License 1.1.

**حساب أوقات الصلاة** يتبع الخوارزمية الفلكية القياسية المستخدمة في PrayTimes/ITL،
واتجاه القبلة بحساب الدائرة العظمى.

إن وجدت خطأً في نص أو تخريج، [افتح موضوعًا](https://github.com/ibrahimu/athar-app/issues) — تصحيح النصوص الشرعية أولوية.

## الترخيص

الكود تحت رخصة MIT. نصوص القرآن والحديث تراث عام.
