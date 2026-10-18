import XCTest
@testable import WordPrint

final class ReportTests: XCTestCase {

    private func flaggedDrift() -> DriftAnalysis {
        DriftAnalysis(sessions: (0..<5).map { typicalSession($0) }
                      + [shiftedSession(on: day(5)), shiftedSession(on: day(6))])
    }

    private func calmDrift() -> DriftAnalysis {
        DriftAnalysis(sessions: (0..<5).map { typicalSession($0) })
    }

    func testStatusWording() {
        XCTAssertEqual(ReportNotes.status(z: 0.3), "close to your usual")
        XCTAssertEqual(ReportNotes.status(z: -0.99), "close to your usual")
        XCTAssertEqual(ReportNotes.status(z: 1.2), "a little higher than usual")
        XCTAssertEqual(ReportNotes.status(z: -1.5), "a little lower than usual")
        XCTAssertEqual(ReportNotes.status(z: 2.4), "noticeably higher than usual")
        XCTAssertEqual(ReportNotes.status(z: -3), "noticeably lower than usual")
    }

    func testSummaryIsCalmWhenNotFlagged() {
        let text = ReportNotes.summary(for: calmDrift())
        XCTAssertTrue(text.contains("within this person's usual range"))
        XCTAssertFalse(text.lowercased().contains("diagnos"))
    }

    func testSummaryNamesShiftedFeaturesWhenFlagged() {
        let d = flaggedDrift()
        XCTAssertTrue(d.isFlagged)
        let text = ReportNotes.summary(for: d)
        XCTAssertTrue(text.contains("filler words (higher)"))
        XCTAssertTrue(text.contains("not a finding"))
    }

    func testOneNotePerMeasuredFeature() {
        let d = calmDrift()
        XCTAssertEqual(ReportNotes.featureNotes(for: d).count, d.baseline.count)
    }

    func testNotesAreEmptyWithoutData() {
        XCTAssertTrue(ReportNotes.featureNotes(for: DriftAnalysis(sessions: [])).isEmpty)
    }

    func testEveryFeatureHasPlainDescription() {
        for f in FingerprintFeature.allCases {
            XCTAssertFalse(f.plainDescription.isEmpty, f.rawValue)
        }
    }

    @MainActor
    func testPDFIsCreatedWithOnePage() throws {
        let url = try XCTUnwrap(ReportPDF.make(name: "Test Person", drift: flaggedDrift()))
        defer { try? FileManager.default.removeItem(at: url) }
        let doc = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertEqual(doc.numberOfPages, 1)
        let page = try XCTUnwrap(doc.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        XCTAssertEqual(box.width, 612, accuracy: 0.5)
        XCTAssertEqual(box.height, 792, accuracy: 0.5)
    }
}
