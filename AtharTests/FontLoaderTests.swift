import XCTest
import UIKit
import SwiftUI
@testable import Athar

/// خط «ثمانية» يُشحن مموَّهًا ويُسجَّل في الذاكرة — هذا يثبت أن الفكّ والتسجيل يعملان
/// وأن الاسم الذي تطلبه AppFont هو ما يعرفه النظام بعد التسجيل.
final class FontLoaderTests: XCTestCase {
    func testThmanyahRegistersAndResolvesByPostScriptName() {
        FontLoader.registerAll()
        FontLoader.registerAll() // الاستدعاء الثاني لا يضرّ
        XCTAssertNotNil(UIFont(name: "thmanyahsans-Regular", size: 14))
        XCTAssertNotNil(UIFont(name: "thmanyahsans-Medium", size: 14))
        XCTAssertNotNil(UIFont(name: "thmanyahsans-Bold", size: 14))
    }

    func testDeobfuscationIsItsOwnInverse() {
        let original = Data((0..<64).map { UInt8($0 * 3 % 251) })
        let masked = FontLoader.deobfuscate(original)
        XCTAssertNotEqual(masked, original)
        XCTAssertEqual(FontLoader.deobfuscate(masked), original)
    }

    func testAppFontBuildsFontsForEveryWeight() {
        // يكفي أن يُترجَم ويُنتج Font لكل حالة؛ الأوزان التسعة تُقرَّب إلى ثلاثة وجوه.
        let weights: [Font.Weight] = [.ultraLight, .thin, .light, .regular, .medium, .semibold, .bold, .heavy, .black]
        for font in AppFont.allCases {
            for w in weights { _ = font.font(size: 14, weight: w) }
        }
        _ = AppFont.thmanyah.font(size: 14, weight: .semibold)
        XCTAssertEqual(AppFont(rawValue: "thmanyah"), .thmanyah)
        XCTAssertEqual(AppFont.allCases.count, 3)
    }
}
