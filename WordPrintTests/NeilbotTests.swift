import XCTest
@testable import WordPrint

final class NeilbotTests: XCTestCase {

    func testHelloUsesName() {
        XCTAssertEqual(Neilbot.hello(name: "Jeff"), "Hi Jeff.")
        XCTAssertEqual(Neilbot.hello(name: "  Jeff \n"), "Hi Jeff.")
        XCTAssertEqual(Neilbot.hello(name: ""), "Hi there.")
    }

    func testGreetingUsesNameAndPeriod() {
        XCTAssertEqual(Neilbot.greeting(name: "Jeff", period: .morning), "Good morning, Jeff!")
        XCTAssertEqual(Neilbot.greeting(name: "Jeff", period: .afternoon), "Good afternoon, Jeff!")
        XCTAssertEqual(Neilbot.greeting(name: "Jeff", period: .evening), "Good evening, Jeff!")
        XCTAssertEqual(Neilbot.greeting(name: "Jeff", period: .night), "Good evening, Jeff!")
        XCTAssertEqual(Neilbot.greeting(name: "", period: .morning), "Good morning!")
    }

    func testGrowthStagesByDay() {
        XCTAssertEqual(GrowthStage.forStreak(1), .seedling)
        XCTAssertEqual(GrowthStage.forStreak(2), .plant)
        XCTAssertEqual(GrowthStage.forStreak(3), .flower)
        XCTAssertEqual(GrowthStage.forStreak(4), .fruit)
        XCTAssertEqual(GrowthStage.forStreak(5), .basket)
        XCTAssertTrue(GrowthStage.forStreak(5).pdfReady)
        XCTAssertFalse(GrowthStage.forStreak(4).pdfReady)
        XCTAssertEqual(GrowthStage.forStreak(6), .seedling)   // new seed after harvest
        XCTAssertEqual(GrowthStage.forStreak(0), .seedling)
    }

    func testStreakCountsConsecutiveDaysEndingToday() {
        let cal = Calendar.current
        let now = Date()
        func ago(_ d: Int) -> Date { cal.date(byAdding: .day, value: -d, to: now)! }
        XCTAssertEqual(Streak.count(dates: [], now: now), 0)
        XCTAssertEqual(Streak.count(dates: [now, now], now: now), 1)
        XCTAssertEqual(Streak.count(dates: [now, ago(1), ago(2)], now: now), 3)
        XCTAssertEqual(Streak.count(dates: [now, ago(2)], now: now), 1)      // gap breaks it
        XCTAssertEqual(Streak.count(dates: [ago(1), ago(2)], now: now), 0)   // nothing today yet
    }

    func testReminderTextMentionsNeilbotAndName() {
        XCTAssertTrue(ReminderScheduler.body(name: "Jeff").contains("Jeff"))
        XCTAssertTrue(ReminderScheduler.body(name: "").contains("Neilbot"))
    }
}
