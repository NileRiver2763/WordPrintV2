import XCTest
@testable import WordPrint

final class SceneTests: XCTestCase {

    func testHourBoundaries() {
        XCTAssertEqual(TimeOfDay.from(hour: 4),  .night)
        XCTAssertEqual(TimeOfDay.from(hour: 5),  .morning)
        XCTAssertEqual(TimeOfDay.from(hour: 11), .morning)
        XCTAssertEqual(TimeOfDay.from(hour: 12), .afternoon)
        XCTAssertEqual(TimeOfDay.from(hour: 16), .afternoon)
        XCTAssertEqual(TimeOfDay.from(hour: 17), .evening)
        XCTAssertEqual(TimeOfDay.from(hour: 20), .evening)
        XCTAssertEqual(TimeOfDay.from(hour: 21), .night)
        XCTAssertEqual(TimeOfDay.from(hour: 0),  .night)
    }

    func testEveryHourMapsToSomePeriod() {
        for h in 0..<24 { XCTAssertFalse(SceneCatalog.scenes(for: .from(hour: h)).isEmpty, "hour \(h)") }
    }

    func testThereAreTenUniqueScenes() {
        XCTAssertEqual(SceneCatalog.all.count, 10)
        XCTAssertEqual(Set(SceneCatalog.all.map(\.id)).count, 10)
    }

    func testEveryPeriodHasAtLeastTwoScenesSoThePictureCanChange() {
        for p in TimeOfDay.allCases {
            XCTAssertGreaterThanOrEqual(SceneCatalog.scenes(for: p).count, 2, "\(p)")
        }
    }

    func testPickMatchesTimeOfDayAndAvoidsLastScene() {
        let noon = Calendar.current.date(bySettingHour: 13, minute: 0, second: 0, of: .now)!
        for _ in 0..<50 {
            let first = SceneCatalog.pick(for: noon)
            XCTAssertEqual(first.period, .afternoon)
            let next = SceneCatalog.pick(for: noon, excluding: first.id)
            XCTAssertNotEqual(next.id, first.id)
            XCTAssertEqual(next.period, .afternoon)
        }
    }

    func testGreetings() {
        XCTAssertEqual(TimeOfDay.morning.greeting, "Good morning!")
        XCTAssertEqual(TimeOfDay.afternoon.greeting, "Good afternoon!")
        XCTAssertEqual(TimeOfDay.evening.greeting, "Good evening!")
    }

    func testScenePositionsStayInsideTheFrame() {
        for s in SceneCatalog.all {
            for p in s.props {
                XCTAssertTrue((0.0...1.0).contains(p.x) && (0.0...1.0).contains(p.y), "\(s.id) \(p.emoji)")
            }
        }
    }
}
