# أثر — حالة الإرسال للآب ستور

| | |
|---|---|
| **الاسم في المتجر** | أثر — أذكار وأوقات الصلاة |
| **Apple ID** | 6806411693 |
| **Bundle ID** | com.ibrahim.athar |
| **SKU** | athar-ios-001 |
| **Team** | GV9S3Z8V4G — Ibrahim Al-Dossrai |
| **الإصدار** | 1.0 (build 1) |
| **الحالة** | Waiting for Review — أُرسل في ٢٩ أغسطس ٢٠٢٦ |

## ما تم ضبطه

- **اللقطات:** ٥ لقطات آيفون 6.9" (1320×2868) + ٤ لقطات آيباد 13" (2064×2752). مقاس 6.5" يستخدم لقطات 6.9" تلقائيًا.
- **التصنيف:** أساسي Reference، ثانوي Lifestyle.
- **التصنيف العمري:** 4+ (كل الإجابات None/No).
- **الخصوصية:** Data Not Collected — منشورة.
- **سياسة الخصوصية:** https://ibrahimu.github.io/athar-app/privacy.html
- **الدعم:** https://ibrahimu.github.io/athar-app/support.html
- **التسويق:** https://ibrahimu.github.io/athar-app/
- **حقوق المحتوى:** لا يحتوي على محتوى طرف ثالث.
- **السعر:** مجاني في ١٧٥ دولة.
- **الإصدار بعد الموافقة:** **يدوي** (Manually release this version) — بعد موافقة آبل ما ينشر حتى تضغط Release بنفسك.
- **تسجيل الدخول للمراجعة:** غير مطلوب.

## Digital Services Act — القرار

الحساب **مكتمل الامتثال أصلاً** (Business ← Compliance ← Digital Services Act: `Active` منذ ٦ أغسطس ٢٠٢٦)،
مسجّل **non-trader**. رسالة «Get Started» في صفحة التطبيق ليست نقصًا — هي عرض للتحويل إلى trader.

القرار: **البقاء على non-trader.**

| | non-trader (المختار) | trader | بلا إقرار إطلاقًا |
|---|---|---|---|
| بيانات تُنشر علنًا | لا شيء | العنوان + الجوال + الإيميل على صفحة التطبيق | — |
| التوزيع في الاتحاد الأوروبي (٢٧ دولة) | **نعم**، مع سطر للمستخدم أن حقوق حماية المستهلك لا تنطبق | نعم | **لا** — حجب ورفع من متاجر الاتحاد |
| بقية العالم (١٤٨ دولة) | نعم | نعم | نعم |
| النطاق | على مستوى الحساب، مع إمكان تجاوزه لكل تطبيق | نفس الشيء | — |

**تصحيح:** الظن الأول كان أن non-trader يمنع التوزيع في الاتحاد الأوروبي. غير صحيح.
الحجب يقع على من **لم يقدّم أي إقرار**؛ أما الإقرار بأنك non-trader فحالة صالحة ومكتملة،
والتطبيق يبقى متاحًا في الاتحاد مع عرض تنبيه للمستخدم بأن حقوق حماية المستهلك الأوروبية
لا تنطبق على التعاقد معك. آبل لا تنص على هذا في جملة واحدة صريحة — الاستنتاج مبني على أن
لغة الحجب تستهدف «apps without trader status» وعلى قوائم فعلية لمطوّرين مُقرّين بأنهم
non-traders. للتأكد القاطع: Apple Developer Support.

مسار trader لو احتيج مستقبلاً ليس مجرد تعبئة عنوان: يتطلب تحقّق ثنائي للإيميل **وللجوال**،
ورفع مستند يثبت الاسم والعنوان، وبيانات حساب دفع، وإقرارًا بالامتثال لقانون الاتحاد.
المستندات وبيانات البنك تُجمع ولا تُنشر أبدًا (المادة 30(7) من الـDSA).

للتغيير لاحقًا: App Store Connect ← Business ← Compliance ← Digital Services Act.
وللتجاوز على مستوى تطبيق واحد: App Information ← App Store Regulations and Permits ← Digital Services Act.

## أشياء تستحق الانتباه

- **رقم الجوال وبريد التواصل** في App Review Information يظهران لآبل فقط، لا للمستخدمين.
- بعد موافقة آبل، التطبيق يبقى في حالة «Pending Developer Release» حتى تنشره يدويًا.

## إعادة البناء والرفع لاحقًا

```bash
xcodegen generate
xcodebuild -project Athar.xcodeproj -scheme Athar -configuration Release \
  -destination 'generic/platform=iOS' -archivePath /tmp/Athar.xcarchive \
  -allowProvisioningUpdates archive
xcodebuild -exportArchive -archivePath /tmp/Athar.xcarchive \
  -exportOptionsPlist store/ExportOptions-upload.plist -exportPath /tmp/upload-out \
  -allowProvisioningUpdates
```

ارفع `CURRENT_PROJECT_VERSION` في `project.yml` قبل كل رفع جديد.
