import UIKit

/// تبديل أيقونة التطبيق على الشاشة الرئيسية.
///
/// الأيقونة ملك النظام لا ملك مخزننا: هو يحفظها بين التشغيلات ويُسأل عنها، فلا
/// نكتبها في التفضيلات كي لا يفترق ما نظنّه عمّا يراه المستخدم على شاشته.
@MainActor
enum AppIconManager {

    /// أجهزة وبيئات تمنع الأيقونات البديلة (إدارة مؤسسية، أو نسخة مقيّدة).
    /// حيث يُمنع تُطوى المجموعة كلها فلا يُعرض خيارٌ لا يُنفَّذ.
    static var supported: Bool { UIApplication.shared.supportsAlternateIcons }

    /// الحاضرة الآن — الأصل حين لا اسم بديل عند النظام.
    static var current: AppIconChoice {
        AppIconChoice(assetName: UIApplication.shared.alternateIconName)
    }

    static func set(_ choice: AppIconChoice) async throws {
        // طلب الأيقونة الحاضرة نفسها يرمي خطأً عند النظام، وهو خطأ لا معنى له:
        // المطلوب حاصلٌ أصلًا. فيُردّ من هنا بلا ضجّة بدل أن يُعرض عطبٌ لم يقع.
        guard choice != current else { return }
        // ويعرض النظام بعدها تنبيهه «تم تغيير أيقونة التطبيق» — تنبيهه هو، لا سبيل
        // إلى كتمه ولا إلى تبديل نصّه؛ فلا نُتبعه بتنبيهٍ منّا يُخبر بالخبر مرّتين.
        try await UIApplication.shared.setAlternateIconName(choice.assetName)
    }
}
