import XCTest
@testable import Athar

/// كلُّ نصٍّ شرعيٍّ يظهر للمستخدم يحمل تخريجَه معه. وما لا يُحلّ من بيانات
/// التطبيق (`hadith.json` = رياض الصالحين والأربعين) يُراجَع عزوُه قبل أن
/// يُكتب — لا من الذاكرة. هذا الاختبار يحرس ألّا يعود متنٌ بلا عزو.
final class ScriptureAttributionTests: XCTestCase {

    /// عباراتُ التخريج المقبولة — ما عداها ليس عزوًا.
    private let takhrij = ["متفق عليه", "رواه البخاري", "رواه مسلم", "رياض الصالحين", "سورة "]

    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    /// المتنان اللذان لا يُحلّان من البيانات: يظهران في تنبيهٍ وفي شاشة، وكانا
    /// في التنبيه بلا عزو وفي الشاشة بعزو — فاستوى الموضعان.
    func testTheTwoUnresolvableMatnsCarryTheirTakhrijEverywhere() throws {
        let places: [(file: String, matn: String)] = [
            ("Athar/Models/Reminders.swift", "ينزل ربنا إلى السماء الدنيا"),
            ("Athar/Models/Reminders.swift", "أحبُّ الأعمال إلى الله أدومها"),
            ("Athar/Views/PrayerView.swift",  "ينزل ربنا إلى السماء الدنيا"),
            ("Athar/Views/WirdView.swift",    "أحبُّ الأعمال إلى الله أدومها"),
        ]
        for place in places {
            let text = try source(place.file)
            guard let range = text.range(of: place.matn) else {
                return XCTFail("لم يعد المتن موجودًا: \(place.matn) في \(place.file)")
            }
            // التخريج يقع بعد المتن في السطر نفسه.
            let line = text[text.lineRange(for: range)]
            XCTAssertTrue(takhrij.contains { line.contains($0) },
                          "متنٌ بلا عزو في \(place.file): \(place.matn)")
        }
    }

    /// أدلّةُ المناسبات والزكاة المكتوبةُ في الشيفرة (لا تُحلّ من البيانات):
    /// كلُّ واحدٍ منها يحمل تخريجَه في موضعه — وإلّا فلا يُعرض.
    func testEveryWrittenProofInOccasionsAndZakatIsAttributed() {
        for occasion in Occasions.all {
            XCTAssertFalse(occasion.evidenceSource.trimmingCharacters(in: .whitespaces).isEmpty,
                           occasion.id)
            XCTAssertFalse(occasion.evidence.trimmingCharacters(in: .whitespaces).isEmpty, occasion.id)
        }
        for item in Zakat.evidence {
            XCTAssertFalse(item.source.trimmingCharacters(in: .whitespaces).isEmpty, item.text)
        }
    }
}
