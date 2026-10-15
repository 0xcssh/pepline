import XCTest
@testable import Pepline

final class DoseScheduleTests: XCTestCase {
    /// Paris: DST starts 2026-03-29 (02:00 → 03:00) and ends 2026-10-25.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func schedule(_ pattern: DoseSchedule.Pattern, start: Date? = nil, end: Date? = nil,
                          times: [TimeOfDay] = [TimeOfDay(hour: 8, minute: 0)]) -> DoseSchedule {
        DoseSchedule(pattern: pattern, start: start ?? date(2026, 1, 1), end: end, times: times)
    }

    // MARK: Validation

    func testValidation() {
        XCTAssertTrue(schedule(.everyNDays(1)).isValid)
        XCTAssertFalse(schedule(.everyNDays(0)).isValid)
        XCTAssertFalse(schedule(.weekdays([])).isValid)
        XCTAssertFalse(schedule(.weekdays([0])).isValid)
        XCTAssertFalse(schedule(.weekdays([8])).isValid)
        XCTAssertTrue(schedule(.cycle(onDays: 5, offDays: 0)).isValid)
        XCTAssertFalse(schedule(.cycle(onDays: 0, offDays: 2)).isValid)
        XCTAssertFalse(schedule(.cycle(onDays: 5, offDays: -1)).isValid)
        XCTAssertFalse(schedule(.everyNDays(1), times: []).isValid)
        XCTAssertFalse(schedule(.everyNDays(1), times: [TimeOfDay(hour: 24, minute: 0)]).isValid)
        XCTAssertFalse(schedule(.everyNDays(1), times: [TimeOfDay(hour: 8, minute: 60)]).isValid)
    }

    func testInvalidScheduleHasNoDoses() {
        let invalid = schedule(.everyNDays(0))
        XCTAssertFalse(invalid.isDoseDay(date(2026, 1, 1), calendar: calendar))
        XCTAssertEqual(invalid.occurrences(from: date(2026, 1, 1), through: date(2026, 2, 1), calendar: calendar), [])
        XCTAssertNil(invalid.next(after: date(2026, 1, 1), calendar: calendar))
    }

    // MARK: Patterns

    func testDaily() {
        let doses = schedule(.everyNDays(1))
            .occurrences(from: date(2026, 1, 1), through: date(2026, 1, 3, 23, 59), calendar: calendar)
        XCTAssertEqual(doses, [date(2026, 1, 1, 8), date(2026, 1, 2, 8), date(2026, 1, 3, 8)])
    }

    func testEveryOtherDay() {
        let doses = schedule(.everyNDays(2))
            .occurrences(from: date(2026, 1, 1), through: date(2026, 1, 6, 23), calendar: calendar)
        XCTAssertEqual(doses, [date(2026, 1, 1, 8), date(2026, 1, 3, 8), date(2026, 1, 5, 8)])
    }

    func testWeekdays() {
        // 2026-01-01 is a Thursday (5); Monday is 2.
        let doses = schedule(.weekdays([2, 5]))
            .occurrences(from: date(2026, 1, 1), through: date(2026, 1, 8, 23), calendar: calendar)
        XCTAssertEqual(doses, [date(2026, 1, 1, 8), date(2026, 1, 5, 8), date(2026, 1, 8, 8)])
    }

    func testCycleOnOff() {
        // 5 on / 2 off from Jan 1: on 1–5, off 6–7, on again 8.
        let cycle = schedule(.cycle(onDays: 5, offDays: 2))
        let onDays = (1...9).filter { cycle.isDoseDay(date(2026, 1, $0, 12), calendar: calendar) }
        XCTAssertEqual(onDays, [1, 2, 3, 4, 5, 8, 9])
    }

    func testNoDoseBeforeStartOrAfterEnd() {
        let bounded = schedule(.everyNDays(1), start: date(2026, 1, 10, 15), end: date(2026, 1, 12, 1))
        XCTAssertFalse(bounded.isDoseDay(date(2026, 1, 9), calendar: calendar))
        XCTAssertTrue(bounded.isDoseDay(date(2026, 1, 10), calendar: calendar), "start day counts whatever its time")
        XCTAssertTrue(bounded.isDoseDay(date(2026, 1, 12, 23), calendar: calendar), "end day is inclusive")
        XCTAssertFalse(bounded.isDoseDay(date(2026, 1, 13), calendar: calendar))
        XCTAssertEqual(bounded.occurrences(from: date(2026, 1, 1), through: date(2026, 1, 31), calendar: calendar).count, 3)
        XCTAssertEqual(bounded.nextOccurrences(after: date(2026, 1, 1), count: 10, calendar: calendar).count, 3)
    }

    func testSeveralTimesADayAreSorted() {
        let twice = schedule(.everyNDays(1), times: [TimeOfDay(hour: 20, minute: 30), TimeOfDay(hour: 8, minute: 0)])
        let doses = twice.occurrences(from: date(2026, 1, 1), through: date(2026, 1, 1, 23), calendar: calendar)
        XCTAssertEqual(doses, [date(2026, 1, 1, 8), date(2026, 1, 1, 20, 30)])
    }

    func testRangeIsInclusiveAndClipped() {
        let daily = schedule(.everyNDays(1))
        XCTAssertEqual(daily.occurrences(from: date(2026, 1, 1, 8), through: date(2026, 1, 2, 8), calendar: calendar),
                       [date(2026, 1, 1, 8), date(2026, 1, 2, 8)])
        XCTAssertEqual(daily.occurrences(from: date(2026, 1, 1, 9), through: date(2026, 1, 2, 7), calendar: calendar), [])
        XCTAssertEqual(daily.occurrences(from: date(2026, 1, 2), through: date(2026, 1, 1), calendar: calendar), [])
    }

    // MARK: Daylight saving

    func testDosesKeepTheirClockTimeAcrossDST() {
        let daily = schedule(.everyNDays(1))
        for (from, through) in [(date(2026, 3, 28), date(2026, 3, 30, 23)), (date(2026, 10, 24), date(2026, 10, 26, 23))] {
            let doses = daily.occurrences(from: from, through: through, calendar: calendar)
            XCTAssertEqual(doses.count, 3)
            XCTAssertEqual(doses.map { calendar.component(.hour, from: $0) }, [8, 8, 8])
        }
        // Every-other-day parity does not drift after the change.
        // Apr 1 is day 90 since Jan 1, after the March change.
        XCTAssertTrue(schedule(.everyNDays(2)).isDoseDay(date(2026, 4, 1), calendar: calendar))
        XCTAssertFalse(schedule(.everyNDays(2)).isDoseDay(date(2026, 4, 2), calendar: calendar))
    }

    func testSkippedSpringForwardTimeMovesLater() {
        let night = schedule(.everyNDays(1), times: [TimeOfDay(hour: 2, minute: 30)])
        let doses = night.occurrences(from: date(2026, 3, 29), through: date(2026, 3, 29, 23), calendar: calendar)
        XCTAssertEqual(doses.count, 1)
        XCTAssertGreaterThanOrEqual(calendar.component(.hour, from: doses[0]), 3)
    }

    // MARK: Next doses

    func testNextIsStrictlyAfter() {
        let daily = schedule(.everyNDays(1))
        XCTAssertEqual(daily.next(after: date(2026, 1, 1, 7), calendar: calendar), date(2026, 1, 1, 8))
        XCTAssertEqual(daily.next(after: date(2026, 1, 1, 8), calendar: calendar), date(2026, 1, 2, 8))
        XCTAssertEqual(daily.next(after: date(2025, 6, 1), calendar: calendar), date(2026, 1, 1, 8), "before start")
    }

    func testNextOccurrencesWeekly() {
        let weekly = schedule(.everyNDays(7))
        XCTAssertEqual(weekly.nextOccurrences(after: date(2026, 1, 2), count: 3, calendar: calendar),
                       [date(2026, 1, 8, 8), date(2026, 1, 15, 8), date(2026, 1, 22, 8)])
        XCTAssertEqual(weekly.nextOccurrences(after: date(2026, 1, 2), count: 0, calendar: calendar), [])
    }

    func testCodableRoundTrip() throws {
        for pattern: DoseSchedule.Pattern in [.everyNDays(2), .weekdays([1, 4]), .cycle(onDays: 5, offDays: 2)] {
            let original = schedule(pattern, end: date(2026, 6, 1))
            let data = try JSONEncoder().encode(original)
            XCTAssertEqual(try JSONDecoder().decode(DoseSchedule.self, from: data), original)
        }
    }

    // MARK: Vial forecast

    func testDosesLeft() {
        XCTAssertEqual(VialForecast.dosesLeft(remaining: .mg(5), dose: .mcg(250)), 20)
        XCTAssertEqual(VialForecast.dosesLeft(remaining: .mg(1), dose: .mg(d("0.3"))), 3)
        XCTAssertEqual(VialForecast.dosesLeft(remaining: .zero, dose: .mg(1)), 0)
        XCTAssertEqual(VialForecast.dosesLeft(remaining: .mg(1), dose: .zero), 0)
    }

    func testRunOutDaily() {
        // 20 doses Jan 1…20; the 21st (Jan 21) has no vial left.
        let runOut = VialForecast.runOutDate(remaining: .mg(5), dose: .mcg(250), schedule: schedule(.everyNDays(1)),
                                             after: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(runOut, date(2026, 1, 21, 8))
    }

    func testRunOutWeekly() {
        // 5 mg at 0.25 mg weekly from Jan 1 (Thursday): 20 doses, the 21st is week 20 → May 21.
        let runOut = VialForecast.runOutDate(remaining: .mg(5), dose: .mg(d("0.25")), schedule: schedule(.everyNDays(7)),
                                             after: date(2026, 1, 1), calendar: calendar)
        XCTAssertEqual(runOut, date(2026, 5, 21, 8))
    }

    func testRunOutNilWhenScheduleEndsFirstOrDoseIsZero() {
        let short = schedule(.everyNDays(1), end: date(2026, 1, 5))
        XCTAssertNil(VialForecast.runOutDate(remaining: .mg(5), dose: .mcg(250), schedule: short,
                                             after: date(2026, 1, 1), calendar: calendar))
        XCTAssertNil(VialForecast.runOutDate(remaining: .mg(5), dose: .zero, schedule: schedule(.everyNDays(1)),
                                             after: date(2026, 1, 1), calendar: calendar))
    }

    func testEmptyVialRunsOutAtNextDose() {
        let runOut = VialForecast.runOutDate(remaining: .zero, dose: .mcg(250), schedule: schedule(.everyNDays(1)),
                                             after: date(2026, 1, 3, 9), calendar: calendar)
        XCTAssertEqual(runOut, date(2026, 1, 4, 8))
    }

    func testReorderDate() {
        let runOut = date(2026, 1, 21, 8)
        XCTAssertEqual(VialForecast.reorderDate(runOut: runOut, leadDays: 7, now: date(2026, 1, 1), calendar: calendar),
                       date(2026, 1, 14, 8))
        XCTAssertEqual(VialForecast.reorderDate(runOut: runOut, leadDays: 30, now: date(2026, 1, 10), calendar: calendar),
                       date(2026, 1, 10), "never in the past")
        XCTAssertEqual(VialForecast.reorderDate(runOut: runOut, leadDays: -3, now: date(2026, 1, 1), calendar: calendar),
                       runOut)
    }
}
