import CoreText
import Foundation
import SwiftUI

// MARK: - ما تستعيره المضاعفات من حزمة تطبيق الساعة
//
// حزمة الإضافة خفيفة عمدًا: project.yml يستثني منها كل ملفات json ولا يضمّ إليها الخطوط.
// والإضافة تسكن PlugIns داخل AtharWatch.app، فما ينقصها موجودٌ فوقها بخطوة.

enum WatchHostBundle {
    /// حزمة الحاضن: نصعد من الإضافة حتى نبلغ .app — وفيها النسخ والأذكار.
    static let bundle: Bundle? = {
        var url = Bundle.main.bundleURL
        for _ in 0..<4 {
            if url.pathExtension == "app" { return Bundle(url: url) }
            url.deleteLastPathComponent()
        }
        return nil
    }()

    /// الحزمتان بترتيب البحث: حزمة الإضافة أولًا لو ضُمّ إليها الملف يومًا.
    static var searchOrder: [Bundle] { [Bundle.main, bundle].compactMap { $0 } }
}

/// خطّ النسخ: نصّ الذكر لا يليق به خطّ النظام، والإضافة لا تسجّله في Info.plist
/// فنسجّله في العملية مرة واحدة من ملفات الحاضن نفسها.
enum WatchNaskh {
    private static let ready: Bool = {
        var registered = false
        for face in ["NotoNaskhArabic-Regular", "NotoNaskhArabic-Bold"] {
            guard let url = WatchHostBundle.searchOrder
                .compactMap({ $0.url(forResource: face, withExtension: "ttf") }).first else { continue }
            if CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) { registered = true }
        }
        return registered
    }()

    /// النسخ إن سُجّل، وإلا خطّ النظام — النص يُقرأ على الحالين.
    static func font(_ size: CGFloat, bold: Bool = false) -> Font {
        ready
            ? .custom(bold ? "NotoNaskhArabic-Bold" : "NotoNaskhArabic-Regular", size: size)
            : .system(size: size, weight: bold ? .bold : .regular)
    }
}

/// أذكار المضاعفة: تُقرأ من adhkar.json نفسه بالمعرّف نفسه — لا حرف يُكتب هنا.
enum WatchWidgetAdhkar {
    private struct File: Decodable { let categories: [DhikrCategory] }

    /// القصيرة منها فقط: المستطيل الصغير لا يتّسع لذكرٍ طويل.
    static let items: [Dhikr] = {
        for bundle in WatchHostBundle.searchOrder {
            guard let url = bundle.url(forResource: "adhkar", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let file = try? JSONDecoder().decode(File.self, from: data) else { continue }
            let all = file.categories.flatMap(\.items)
            let short = all.filter { $0.text.count <= 70 && !$0.text.contains("\n") }
            return short.isEmpty ? all : short
        }
        return []
    }()

    /// شريحة نصف ساعة — القسمة نفسها التي في صفحة «ذكر اليوم»، فلا يفترق ما على المعصم عمّا في التطبيق.
    static let slot: TimeInterval = 1800

    static func at(_ date: Date) -> Dhikr? {
        guard !items.isEmpty else { return nil }
        let index = Int(date.timeIntervalSince1970 / slot)
        return items[abs(index) % items.count]
    }

    /// مطلع الشريحة التالية: حدّ المدخل في الجدول الزمني.
    static func nextSlot(after date: Date) -> Date {
        Date(timeIntervalSince1970: (floor(date.timeIntervalSince1970 / slot) + 1) * slot)
    }
}
