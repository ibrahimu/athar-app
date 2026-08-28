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

| | non-trader (المختار) | trader |
|---|---|---|
| بيانات تُنشر علنًا | لا شيء | العنوان الفعلي + الجوال + الإيميل على صفحة التطبيق |
| التوزيع في الاتحاد الأوروبي (٢٧ دولة) | لا | نعم |
| بقية العالم (١٤٨ دولة، منها الخليج والعالم العربي) | نعم | نعم |
| النطاق | على مستوى الحساب — يشمل كل التطبيقات | نفس الشيء |

آبل لا تقبل صندوق بريد لعنوان الـ trader؛ لا بد من عنوان فعلي يُعرض للعامة.
للتغيير لاحقًا: App Store Connect ← Business ← Compliance ← Digital Services Act.

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
