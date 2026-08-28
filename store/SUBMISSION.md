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
- **الإصدار بعد الموافقة:** تلقائي (Automatically release).
- **تسجيل الدخول للمراجعة:** غير مطلوب.

## أشياء تستحق الانتباه

- **Digital Services Act:** App Store Connect يعرض أن المطوّر مسجّل «non-trader». إن أردت التوزيع في الاتحاد الأوروبي بلا قيود، أكمل متطلبات الامتثال من App Information ← Digital Services Act ← Get Started.
- **الإصدار تلقائي:** يمكن تغييره إلى Manually release أي وقت قبل الموافقة من صفحة الإصدار ← App Store Version Release.
- **رقم الجوال وبريد التواصل** يظهران لآبل فقط، لا للمستخدمين.

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
