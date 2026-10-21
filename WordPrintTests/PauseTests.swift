import XCTest
@testable import WordPrint

final class PauseTests: XCTestCase {

    private let speech = -20.0
    private let quiet = -60.0
    private let step = 0.05           // 50 ms buffers

    private func feed(_ d: inout PauseDetector, level: Double, seconds: Double) {
        var t = 0.0
        while t < seconds - 1e-9 { d.add(levelDB: level, duration: step); t += step }
    }

    func testSilenceBeforeAndAfterSpeechIsNotAPause() {
        var d = PauseDetector()
        feed(&d, level: quiet, seconds: 2)
        feed(&d, level: speech, seconds: 3)
        feed(&d, level: quiet, seconds: 4)
        XCTAssertEqual(d.stats.count, 0)
    }

    func testPauseBetweenWordsIsCountedWithItsLength() throws {
        var d = PauseDetector()
        feed(&d, level: speech, seconds: 2)
        feed(&d, level: quiet, seconds: 1.0)
        feed(&d, level: speech, seconds: 2)
        XCTAssertEqual(d.stats.count, 1)
        XCTAssertEqual(d.stats.totalSeconds, 1.0, accuracy: 0.11)
        XCTAssertEqual(d.stats.longestSeconds, 1.0, accuracy: 0.11)
    }

    func testShortGapsBetweenWordsAreIgnored() {
        var d = PauseDetector()
        for _ in 0..<10 {
            feed(&d, level: speech, seconds: 0.6)
            feed(&d, level: quiet, seconds: 0.25)
        }
        feed(&d, level: speech, seconds: 0.6)
        XCTAssertEqual(d.stats.count, 0)
    }

    func testSeveralPausesAddUp() {
        var d = PauseDetector()
        feed(&d, level: speech, seconds: 1)
        feed(&d, level: quiet, seconds: 0.6)
        feed(&d, level: speech, seconds: 1)
        feed(&d, level: quiet, seconds: 1.5)
        feed(&d, level: speech, seconds: 1)
        XCTAssertEqual(d.stats.count, 2)
        XCTAssertEqual(d.stats.longestSeconds, 1.5, accuracy: 0.11)
        XCTAssertEqual(d.stats.meanSeconds, 1.05, accuracy: 0.15)
    }

    func testBriefNoiseInsideAPauseDoesNotSplitIt() {
        var d = PauseDetector()
        feed(&d, level: speech, seconds: 1)
        feed(&d, level: quiet, seconds: 0.5)
        feed(&d, level: speech, seconds: 0.05)      // a click
        feed(&d, level: quiet, seconds: 0.5)
        feed(&d, level: speech, seconds: 1)
        XCTAssertEqual(d.stats.count, 1)
    }

    func testNoisyRoomStillWorksOnceFloorIsLearned() {
        var d = PauseDetector()
        feed(&d, level: -38, seconds: 1)            // background noise before speaking
        feed(&d, level: -15, seconds: 1)
        feed(&d, level: -38, seconds: 1.0)          // a pause, in the noisy room
        feed(&d, level: -15, seconds: 1)
        XCTAssertEqual(d.stats.count, 1)
    }

    func testPausesPerMinuteAndMeanInFingerprint() {
        let stats = PauseStats(count: 6, totalSeconds: 9, longestSeconds: 2.5)
        let f = Fingerprint.analyze(transcript: "one two three four five six seven eight nine ten", durationSeconds: 120, pauses: stats)
        XCTAssertEqual(f.pausesPerMinute, 3.0)
        XCTAssertEqual(f.meanPauseSeconds, 1.5)
        XCTAssertNil(Fingerprint.analyze(transcript: "a b c", durationSeconds: 10).pausesPerMinute)
    }

    func testSessionRoundTripsPauseStats() {
        XCTAssertNil(Session(duration: 5, transcript: "").pauseStats)
        let s = Session(duration: 5, transcript: "", pauses: PauseStats(count: 2, totalSeconds: 3, longestSeconds: 2))
        XCTAssertEqual(s.pauseStats, PauseStats(count: 2, totalSeconds: 3, longestSeconds: 2))
    }

    // MARK: drift

    private func pausedSession(_ i: Int, pauses: Int, on date: Date) -> Session {
        let base = typicalSession(i, on: date)
        return Session(date: date, duration: base.duration, transcript: base.transcript,
                       pauses: PauseStats(count: pauses, totalSeconds: Double(pauses) * (0.7 + 0.1 * Double(i)), longestSeconds: 1))
    }

    func testPauseBaselineNeedsThreeMeasuredCheckIns() {
        // Three old check-ins without pause data, then new ones with it.
        let old = (0..<3).map { typicalSession($0) }
        let new = (3..<5).map { pausedSession($0, pauses: 3 + $0, on: day($0)) }
        let d = DriftAnalysis(sessions: old + new)
        XCTAssertNil(d.baseline[.pausesPerMinute])
        XCTAssertFalse(d.availableFeatures.isEmpty)
        XCTAssertTrue(d.availableFeatures.contains(.pausesPerMinute))
    }

    func testPauseFeaturesJoinTheBaselineWhenAllMeasured() {
        let d = DriftAnalysis(sessions: (0..<3).map { pausedSession($0, pauses: 2 + $0, on: day($0)) })
        XCTAssertNotNil(d.baseline[.pausesPerMinute])
        XCTAssertNotNil(d.baseline[.meanPauseSeconds])
    }

    func testPauseRateAndLengthCountAsOneSignal() {
        var d = DriftAnalysis(sessions: [])
        d.shifted = [(.pausesPerMinute, true), (.meanPauseSeconds, true), (.fillerRate, true)]
        XCTAssertEqual(d.signalCount, 2)
    }

    // MARK: prompts

    func testEachCheckInGetsADifferentQuestionThenItRepeats() {
        XCTAssertNotEqual(DailyPrompt.forCheckIn(number: 0), DailyPrompt.forCheckIn(number: 1))
        XCTAssertEqual(DailyPrompt.forCheckIn(number: 0), DailyPrompt.forCheckIn(number: DailyPrompt.all.count))
    }

    func testEveryPictureResolvesToADrawing() {
        for p in DailyPrompt.all where p.pictureID != nil {
            XCTAssertNotNil(p.picture, p.id)
        }
        XCTAssertEqual(PictureCatalog.all.count, 10)
        XCTAssertEqual(Set(PictureCatalog.all.map(\.id)).count, 10)
        XCTAssertTrue(PictureCatalog.all.allSatisfy { $0.ops.count > 30 })
        let used = Set(DailyPrompt.all.compactMap(\.pictureID))
        XCTAssertEqual(used, Set(PictureCatalog.ids))
        XCTAssertEqual(Set(DailyPrompt.all.map(\.id)).count, DailyPrompt.all.count)
        XCTAssertTrue(DailyPrompt.all.contains { $0.pictureID != nil })
    }

    func testPromptCyclesThroughAll() {
        let ids = Set((0..<DailyPrompt.all.count).map { DailyPrompt.forCheckIn(number: $0).id })
        XCTAssertEqual(ids.count, DailyPrompt.all.count)
    }
}
