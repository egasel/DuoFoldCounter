import XCTest
@testable import FoldCounter

final class FoldStoreTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    override func setUp() {
        super.setUp()
        suiteName = "FoldStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func date(_ iso8601: String) -> Date {
        ISO8601DateFormatter().date(from: iso8601)!
    }

    func testCountsOpensAndClosesForTheDay() {
        let store = FoldStore(defaults: defaults)
        store.record(.open, at: date("2026-10-25T09:00:00Z"), calendar: calendar)
        store.record(.close, at: date("2026-10-25T09:05:00Z"), calendar: calendar)
        let stats = store.record(.open, at: date("2026-10-25T12:00:00Z"), calendar: calendar)

        XCTAssertEqual(stats.count(on: date("2026-10-25T23:00:00Z"), calendar: calendar), DayCount(opens: 2, closes: 1))
        XCTAssertEqual(stats.total, DayCount(opens: 2, closes: 1))
        XCTAssertEqual(stats.firstEvent, date("2026-10-25T09:00:00Z"))
        XCTAssertEqual(stats.lastEvent, date("2026-10-25T12:00:00Z"))
    }

    func testNewDayStartsAtZeroWhileTotalKeepsCounting() {
        let store = FoldStore(defaults: defaults)
        store.record(.open, at: date("2026-10-25T23:59:00Z"), calendar: calendar)
        let stats = store.record(.close, at: date("2026-10-26T00:01:00Z"), calendar: calendar)

        XCTAssertEqual(stats.count(on: date("2026-10-25T12:00:00Z"), calendar: calendar), DayCount(opens: 1, closes: 0))
        XCTAssertEqual(stats.count(on: date("2026-10-26T12:00:00Z"), calendar: calendar), DayCount(opens: 0, closes: 1))
        XCTAssertEqual(stats.count(on: date("2026-10-27T12:00:00Z"), calendar: calendar), DayCount())
        XCTAssertEqual(stats.total, DayCount(opens: 1, closes: 1))
    }

    func testCountsSurviveANewStoreInstance() {
        FoldStore(defaults: defaults).record(.open, at: date("2026-10-25T09:00:00Z"), calendar: calendar)

        let reloaded = FoldStore(defaults: defaults).load()
        XCTAssertEqual(reloaded.total, DayCount(opens: 1, closes: 0))
    }

    func testResetClearsEverything() {
        let store = FoldStore(defaults: defaults)
        store.record(.open, at: date("2026-10-25T09:00:00Z"), calendar: calendar)
        store.reset()

        XCTAssertEqual(store.load(), FoldStats())
    }

    func testRecentDaysIncludesDaysWithoutFoldsNewestFirst() {
        let store = FoldStore(defaults: defaults)
        store.record(.open, at: date("2026-10-23T09:00:00Z"), calendar: calendar)
        let stats = store.record(.close, at: date("2026-10-25T09:00:00Z"), calendar: calendar)

        let days = stats.recentDays(3, endingOn: date("2026-10-25T18:00:00Z"), calendar: calendar)
        XCTAssertEqual(days.map(\.date), [
            date("2026-10-25T00:00:00Z"),
            date("2026-10-24T00:00:00Z"),
            date("2026-10-23T00:00:00Z"),
        ])
        XCTAssertEqual(days.map(\.count), [DayCount(opens: 0, closes: 1), DayCount(), DayCount(opens: 1, closes: 0)])
    }
}
