import XCTest
@testable import WordPrint

final class DriftAnalysisTests: XCTestCase {

    // MARK: Baseline availability

    func testNoSessionsHasNoBaseline() {
        let d = DriftAnalysis(sessions: [])
        XCTAssertFalse(d.hasBaseline)
        XCTAssertFalse(d.isFlagged)
        XCTAssertTrue(d.points.isEmpty)
    }

    func testTwoSessionsIsNotEnoughForBaseline() {
        let d = DriftAnalysis(sessions: (0..<2).map { typicalSession($0) })
        XCTAssertFalse(d.hasBaseline)
        XCTAssertEqual(d.points.count, 2)
    }

    func testBaselineAppearsAtThreeSessions() {
        let d = DriftAnalysis(sessions: (0..<3).map { typicalSession($0) })
        XCTAssertTrue(d.hasBaseline)
        XCTAssertEqual(d.baselineSize, 3)
    }

    func testBaselineWindowGrowsToFiveFromFiveSessions() {
        XCTAssertEqual(DriftAnalysis(sessions: (0..<4).map { typicalSession($0) }).baselineSize, 3)
        XCTAssertEqual(DriftAnalysis(sessions: (0..<5).map { typicalSession($0) }).baselineSize, 5)
        XCTAssertEqual(DriftAnalysis(sessions: (0..<9).map { typicalSession($0) }).baselineSize, 5)
    }

    func testShortTranscriptsAreIgnored() {
        var sessions = (0..<2).map { typicalSession($0) }
        sessions.append(Session(date: day(5), duration: 5, transcript: "just a few words"))
        let d = DriftAnalysis(sessions: sessions)
        XCTAssertEqual(d.points.count, 2)
        XCTAssertFalse(d.hasBaseline)
    }

    func testSessionsAreSortedByDate() {
        let sessions = [typicalSession(2), typicalSession(0), typicalSession(1)]
        let d = DriftAnalysis(sessions: sessions)
        XCTAssertEqual(d.points.map(\.date), [day(0), day(1), day(2)])
    }

    func testIdenticalSessionsHaveNoSpreadAndNoBaseline() {
        // Standard deviation of 0 would make every z-score infinite, so those
        // features are skipped.
        let same = (0..<5).map {
            Session(date: day($0), duration: 30, transcript: distinctWords(20).joined(separator: " "))
        }
        let d = DriftAnalysis(sessions: same)
        XCTAssertFalse(d.hasBaseline)
        XCTAssertFalse(d.isFlagged)
    }

    // MARK: Statistics

    func testBaselineMeanAndSampleStandardDeviation() {
        let sessions = (0..<5).map { typicalSession($0) }
        let d = DriftAnalysis(sessions: sessions)
        let values = d.points.prefix(5).map { $0.fingerprint.wordsPerMinute }
        let mean = values.reduce(0, +) / 5
        let sd = (values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / 4).squareRoot()   // n − 1

        let b = try! XCTUnwrap(d.baseline[.wordsPerMinute])
        XCTAssertEqual(b.mean, mean, accuracy: 0.0001)
        XCTAssertEqual(b.sd, sd, accuracy: 0.0001)
    }

    func testZScoreIsDistanceFromMeanInStandardDeviations() {
        let d = DriftAnalysis(sessions: (0..<6).map { typicalSession($0) })
        let b = try! XCTUnwrap(d.baseline[.wordsPerMinute])
        let p = d.points[5]
        let expected = (p.fingerprint.wordsPerMinute - b.mean) / b.sd
        XCTAssertEqual(try XCTUnwrap(p.zScores[.wordsPerMinute]), expected, accuracy: 0.0001)
    }

    func testBaselinePointsAreMarked() {
        let d = DriftAnalysis(sessions: (0..<7).map { typicalSession($0) })
        XCTAssertEqual(d.points.map(\.inBaseline), [true, true, true, true, true, false, false])
    }

    // MARK: Flag

    private func baselineSessions() -> [Session] { (0..<5).map { typicalSession($0) } }

    func testTwoShiftedCheckInsInARowRaiseFlag() throws {
        let d = DriftAnalysis(sessions: baselineSessions() + [shiftedSession(on: day(5)), shiftedSession(on: day(6))])
        XCTAssertTrue(d.isFlagged)
        XCTAssertGreaterThanOrEqual(d.shifted.count, DriftAnalysis.featuresNeeded)

        // Direction: more fillers (higher), less word variety (lower), slower pace (lower).
        let filler = try XCTUnwrap(d.shifted.first { $0.feature == .fillerRate })
        XCTAssertTrue(filler.higher)
        let ttr = try XCTUnwrap(d.shifted.first { $0.feature == .typeTokenRatio })
        XCTAssertFalse(ttr.higher)
        let pace = try XCTUnwrap(d.shifted.first { $0.feature == .wordsPerMinute })
        XCTAssertFalse(pace.higher)
    }

    func testSingleShiftedCheckInDoesNotRaiseFlag() {
        let d = DriftAnalysis(sessions: baselineSessions() + [typicalSession(2, on: day(5)), shiftedSession(on: day(6))])
        XCTAssertFalse(d.isFlagged)
        // A couple of features may overlap, but never enough to reach the threshold.
        XCTAssertLessThan(d.shifted.count, DriftAnalysis.featuresNeeded)
    }

    func testShiftFollowedByRecoveryDoesNotRaiseFlag() {
        let d = DriftAnalysis(sessions: baselineSessions() + [shiftedSession(on: day(5)), typicalSession(2, on: day(6))])
        XCTAssertFalse(d.isFlagged)
    }

    func testNormalCheckInsAfterBaselineDoNotRaiseFlag() {
        let d = DriftAnalysis(sessions: baselineSessions() + [typicalSession(1, on: day(5)), typicalSession(3, on: day(6))])
        XCTAssertFalse(d.isFlagged)
    }

    func testShiftedCheckInsInsideBaselineWindowAreNotFlagged() {
        // With only 6 sessions there aren't two post-baseline check-ins yet.
        let d = DriftAnalysis(sessions: baselineSessions() + [shiftedSession(on: day(5))])
        XCTAssertFalse(d.isFlagged)
    }

    func testOnlyEarlierShiftIsNotFlagged() {
        // Flag describes the latest two check-ins, not history.
        let d = DriftAnalysis(sessions: baselineSessions()
            + [shiftedSession(on: day(5)), shiftedSession(on: day(6)),
               typicalSession(1, on: day(7)), typicalSession(2, on: day(8))])
        XCTAssertFalse(d.isFlagged)
    }

    func testFlagRequiresThreeFeatures() {
        // Fewer than `featuresNeeded` shifted features must never flag.
        var d = DriftAnalysis(sessions: [])
        d.shifted = [(.fillerRate, true), (.wordsPerMinute, false)]
        XCTAssertFalse(d.isFlagged)
        d.shifted.append((.typeTokenRatio, false))
        XCTAssertTrue(d.isFlagged)
    }
}
