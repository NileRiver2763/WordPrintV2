import XCTest
@testable import WordPrint

final class ModelTests: XCTestCase {

    func testFormattedDuration() {
        XCTAssertEqual(Session(duration: 0, transcript: "").formattedDuration, "0:00")
        XCTAssertEqual(Session(duration: 5, transcript: "").formattedDuration, "0:05")
        XCTAssertEqual(Session(duration: 75, transcript: "").formattedDuration, "1:15")
        XCTAssertEqual(Session(duration: 60, transcript: "").formattedDuration, "1:00")
    }

    func testSessionDefaultsMoodToEmpty() {
        let s = Session(duration: 10, transcript: "hi")
        XCTAssertEqual(s.mood, "")
        XCTAssertEqual(s.emoji, "")
    }

    func testCheckInDefaults() {
        let c = CheckIn(mood: "Good", emoji: "🙂")
        XCTAssertEqual(c.note, "")
        XCTAssertEqual(c.mood, "Good")
    }

    func testMoodColorsAreDefinedAndUnknownFallsBackToGray() {
        for mood in ["Great", "Good", "Okay", "Low", "Tired"] {
            XCTAssertNotEqual(colorForMood(mood), .gray, mood)
        }
        XCTAssertEqual(colorForMood("???"), .gray)
    }

    func testFeatureListCoversEveryFingerprintField() {
        let f = Fingerprint(typeTokenRatio: 1, movingAverageTTR: 2, vagueLanguageIndex: 3,
                            fillerRate: 4, wordsPerMinute: 5, meanSentenceLength: 6, pronounNounRatio: 7)
        let values = FingerprintFeature.allCases.compactMap { $0.value(in: f) }
        XCTAssertEqual(Set(values), [1, 2, 3, 4, 5, 6, 7])
    }
}
