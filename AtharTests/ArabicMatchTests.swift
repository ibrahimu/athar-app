import XCTest
@testable import Athar

final class ArabicMatchTests: XCTestCase {
    func testNormalizeStripsDiacriticsAndUnifiesLetters() {
        XCTAssertEqual(ArabicMatch.normalize("ٱلْحَمْدُ"), "الحمد")
        XCTAssertEqual(ArabicMatch.normalize("إِنَّ"), "ان")
        XCTAssertEqual(ArabicMatch.normalize("رَحْمَةٌ"), "رحمه")
    }

    func testPerfectRecitationIsAllCorrect() {
        let target = "ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ".ayahWords
        let states = ArabicMatch.align(target: target, spoken: ["الحمد", "لله", "رب", "العالمين"])
        XCTAssertEqual(states, Array(repeating: .correct, count: target.count))
        XCTAssertEqual(ArabicMatch.score(states), 1, accuracy: 0.001)
    }

    func testMissedWordIsFlaggedAndTailStaysPending() {
        let target = ["الحمد", "لله", "رب", "العالمين"]
        let states = ArabicMatch.align(target: target, spoken: ["الحمد", "رب"])
        XCTAssertEqual(states[0], .correct)
        XCTAssertEqual(states[1], .missed)
        XCTAssertEqual(states[2], .correct)
        XCTAssertEqual(states[3], .pending)
    }

    func testNearMissIsTolerated() {
        XCTAssertTrue(ArabicMatch.similar("العالمين", "العالمين"))
        XCTAssertTrue(ArabicMatch.similar("العالمين", "العلمين"))
        XCTAssertFalse(ArabicMatch.similar("رب", "لله"))
    }
}
