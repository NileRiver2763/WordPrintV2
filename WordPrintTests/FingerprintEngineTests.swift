import XCTest
@testable import WordPrint

final class FingerprintEngineTests: XCTestCase {

    func testEmptyTranscriptReturnsAllZeros() {
        let f = Fingerprint.analyze(transcript: "", durationSeconds: 30)
        XCTAssertEqual(f.typeTokenRatio, 0)
        XCTAssertEqual(f.movingAverageTTR, 0)
        XCTAssertEqual(f.vagueLanguageIndex, 0)
        XCTAssertEqual(f.fillerRate, 0)
        XCTAssertEqual(f.wordsPerMinute, 0)
        XCTAssertEqual(f.meanSentenceLength, 0)
        XCTAssertEqual(f.pronounNounRatio, 0)
    }

    func testPunctuationOnlyTranscriptReturnsZeros() {
        let f = Fingerprint.analyze(transcript: "... !!! ???", durationSeconds: 10)
        XCTAssertEqual(f.typeTokenRatio, 0)
        XCTAssertEqual(f.wordsPerMinute, 0)
    }

    func testTypeTokenRatio() {
        // 3 unique words out of 4 tokens
        let f = Fingerprint.analyze(transcript: "The cat the dog", durationSeconds: 10)
        XCTAssertEqual(f.typeTokenRatio, 0.75, accuracy: 0.0001)
    }

    func testTypeTokenRatioIsCaseInsensitive() {
        let f = Fingerprint.analyze(transcript: "Dog DOG dog", durationSeconds: 10)
        XCTAssertEqual(f.typeTokenRatio, 1.0 / 3.0, accuracy: 0.0001)
    }

    func testMSTTRFallsBackToTTRUnderOneWindow() {
        let f = Fingerprint.analyze(transcript: "the cat the dog", durationSeconds: 10)
        XCTAssertEqual(f.movingAverageTTR, f.typeTokenRatio, accuracy: 0.0001)
    }

    func testMSTTRAveragesFiftyTokenWindows() {
        // 50 unique words said twice: each 50-token window is 100% unique,
        // but across all 100 tokens only half are unique.
        let words = distinctWords(50)
        let text = (words + words).joined(separator: " ")
        let f = Fingerprint.analyze(transcript: text, durationSeconds: 60)
        XCTAssertEqual(f.typeTokenRatio, 0.5, accuracy: 0.0001)
        XCTAssertEqual(f.movingAverageTTR, 1.0, accuracy: 0.0001)
    }

    func testMSTTRDiscardsPartialLastWindow() {
        // 50 unique words + 10 repeats of one word: the trailing 10 are dropped.
        let text = (distinctWords(50) + Array(repeating: "zz", count: 10)).joined(separator: " ")
        let f = Fingerprint.analyze(transcript: text, durationSeconds: 60)
        XCTAssertEqual(f.movingAverageTTR, 1.0, accuracy: 0.0001)
    }

    func testFillerRatePer100Tokens() {
        // um, like, uh = 3 fillers out of 5 tokens
        let f = Fingerprint.analyze(transcript: "Um I like uh went", durationSeconds: 10)
        XCTAssertEqual(f.fillerRate, 60.0, accuracy: 0.01)
    }

    func testNoFillersGivesZeroRate() {
        let f = Fingerprint.analyze(transcript: "I went to the shop", durationSeconds: 10)
        XCTAssertEqual(f.fillerRate, 0)
    }

    func testWordsPerMinute() {
        let text = distinctWords(30).joined(separator: " ")
        let f = Fingerprint.analyze(transcript: text, durationSeconds: 30)
        XCTAssertEqual(f.wordsPerMinute, 60.0, accuracy: 0.1)
    }

    func testWordsPerMinuteIsZeroWithoutDuration() {
        let f = Fingerprint.analyze(transcript: "hello there friend", durationSeconds: 0)
        XCTAssertEqual(f.wordsPerMinute, 0)
    }

    func testMeanSentenceLength() {
        // 6 words, 2 sentences
        let f = Fingerprint.analyze(transcript: "I went home. We ate dinner.", durationSeconds: 10)
        XCTAssertEqual(f.meanSentenceLength, 3.0, accuracy: 0.01)
    }

    func testContractionsCountAsOneWord() {
        XCTAssertEqual(Fingerprint.wordCount("I don't know"), 3)
        XCTAssertEqual(Fingerprint.wordCount("it’s fine"), 2)   // curly apostrophe
    }

    func testStrayApostrophesAreIgnored() {
        XCTAssertEqual(Fingerprint.wordCount("'hello' ' world'"), 2)
    }

    func testNoPronounsGivesZeroPronounNounRatio() {
        let f = Fingerprint.analyze(transcript: "Dogs and cats and birds", durationSeconds: 10)
        XCTAssertEqual(f.pronounNounRatio, 0, accuracy: 0.0001)
    }

    func testVagueLanguageIndexStaysBetweenZeroAndOne() {
        let f = Fingerprint.analyze(transcript: "It is a thing. That is some stuff. I did the thing.", durationSeconds: 20)
        XCTAssertGreaterThanOrEqual(f.vagueLanguageIndex, 0)
        XCTAssertLessThanOrEqual(f.vagueLanguageIndex, 1)
    }

    func testFillersContributeToVagueLanguageIndex() {
        // VLI = 0.4·IPR + 0.35·NNR + 0.25·(filler fraction), and the first two
        // terms can't be negative, so VLI is at least a quarter of the filler
        // fraction. (Which words Apple's tagger calls pronouns/nouns can vary,
        // so we don't assert on those parts.)
        let f = Fingerprint.analyze(transcript: "um uh um uh ok", durationSeconds: 10)
        XCTAssertGreaterThanOrEqual(f.vagueLanguageIndex, 0.25 * 0.8 - 0.0001)
    }

    func testValuesAreRounded() {
        let f = Fingerprint.analyze(transcript: "one two three", durationSeconds: 7)
        // TTR 1.0 and wpm = 3 / (7/60) = 25.714… → one decimal place
        XCTAssertEqual(f.wordsPerMinute, 25.7, accuracy: 0.0001)
    }
}
