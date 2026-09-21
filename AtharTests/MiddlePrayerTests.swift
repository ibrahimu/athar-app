import XCTest
@testable import Athar

/// ﴿وَٱلصَّلَوٰةِ ٱلْوُسْطَىٰ﴾ — الوسطى هي العصر عند الجمهور وبالنصّ: «شغلونا عن
/// الصلاة الوسطى صلاةِ العصر» (متفق عليه). فكانت الآيةُ تظهر في تنبيه المغرب
/// والعشاء كلَّ رابع يوم، ونبّه عليها مستخدمٌ. تُحرَس هنا: للعصر وحده، ولا تغيب عنه.
final class MiddlePrayerTests: XCTestCase {

    private let ayah = "ٱلْوُسْطَىٰ"

    @MainActor
    func testMiddlePrayerAyahNeverReachesAnotherPrayer() {
        for prayer in [Prayer.fajr, .dhuhr, .maghrib, .isha] {
            for day in 0..<30 {
                XCTAssertFalse(Reminders.athanBody(for: prayer, dayOffset: day).contains(ayah),
                               "\(prayer.rawValue) يوم \(day): آية الوسطى ليست له")
            }
        }
    }

    @MainActor
    func testAsrStillCarriesTheMiddlePrayerAyah() {
        let bodies = (0..<30).map { Reminders.athanBody(for: .asr, dayOffset: $0) }
        XCTAssertTrue(bodies.contains { $0.contains(ayah) }, "العصر هو موضعها")
    }

    /// كلُّ آيةٍ في متون الأذان تُطابق المصحفَ المضمَّن حرفًا — لا تُكتب من الذاكرة.
    func testAthanAyahsMatchTheMushafByteForByte() throws {
        let cases: [(Int, Int, String)] = [
            (2, 238, "حَٰفِظُوا۟ عَلَى ٱلصَّلَوَٰتِ وَٱلصَّلَوٰةِ ٱلْوُسْطَىٰ"),
            (20, 14, "وَأَقِمِ ٱلصَّلَوٰةَ لِذِكْرِىٓ"),
            (29, 45, "إِنَّ ٱلصَّلَوٰةَ تَنْهَىٰ عَنِ ٱلْفَحْشَآءِ وَٱلْمُنكَرِ"),
        ]
        for (s, a, fragment) in cases {
            let text = try XCTUnwrap(Quran.text(AyahRef(surah: s, ayah: a)), "\(s):\(a)")
            XCTAssertTrue(text.contains(fragment), "\(s):\(a) يخالف المصحف")
        }
    }
}
