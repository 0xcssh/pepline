import XCTest
@testable import Pepline

final class DailyLoopTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2  // weeks start on Monday
        return calendar
    }()

    /// March 2026: the 2nd is a Monday.
    private func date(_ day: Int, _ hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    private let sema = Compound(name: "Semaglutide")

    private func daily(start: Date? = nil) -> Regimen {
        Regimen(compoundID: sema.id, dose: DoseAmount(value: 1, unit: .mg),
                schedule: DoseSchedule(pattern: .everyNDays(1), start: start ?? date(1, 0), end: nil,
                                       times: [TimeOfDay(hour: 8, minute: 0)]))
    }

    private func dose(_ day: Int, _ hour: Int = 8) -> DoseEntry {
        DoseEntry(date: date(day, hour), compoundID: sema.id, amount: DoseAmount(value: 1, unit: .mg))
    }

    // MARK: Quick log

    func testLogDateKeepsNowAroundTheSlotAndTheSlotOtherwise() {
        XCTAssertEqual(QuickLog.date(forSlot: date(3), now: date(3, 10)), date(3, 10))
        XCTAssertEqual(QuickLog.date(forSlot: date(3), now: date(4, 9)), date(3), "a day late answers its own slot")
    }

    func testQuickDoseUsesNewestVialAndLeastRecentZone() throws {
        var journal = Journal()
        let regimen = daily()
        let old = Vial(compoundID: sema.id, reconstitution: try Reconstitution(vial: .mg(5), waterMl: 2),
                       syringe: .ml05, mixedAt: date(1))
        var archived = Vial(compoundID: sema.id, reconstitution: try Reconstitution(vial: .mg(5), waterMl: 2),
                            syringe: .ml05, mixedAt: date(3))
        archived.isArchived = true
        let older = Vial(compoundID: sema.id, reconstitution: try Reconstitution(vial: .mg(5), waterMl: 2),
                         syringe: .ml05, mixedAt: date(1, 0))
        journal.save(older)
        journal.save(old)
        journal.save(archived)
        var used = dose(2)
        used.site = .abdomen
        used.side = .left
        journal.save(used)
        let entry = QuickLog.dose(for: regimen, in: journal, at: date(4))
        XCTAssertEqual(entry.vialID, old.id)
        XCTAssertEqual(entry.amount, regimen.dose)
        XCTAssertEqual(SiteZone(site: entry.site!, side: entry.side!), SiteZone(site: .abdomen, side: .right))
        XCTAssertEqual(entry.date, date(4))
    }

    // MARK: Adherence fixes

    func testScheduleOwesNothingBeforeItExisted() {
        var journal = Journal()
        let regimen = daily(start: date(3, 21))
        journal.save(regimen)
        let doses = Adherence.doses(of: regimen, in: journal, from: date(3, 0), through: date(4, 23),
                                    now: date(4, 9), calendar: calendar)
        XCTAssertEqual(doses.map(\.date), [date(4)])
    }

    func testLoggedDoseWinsOverASkip() {
        var journal = Journal()
        let regimen = daily()
        journal.save(regimen)
        journal.save(SkippedDose(regimenID: regimen.id, scheduledAt: date(2)))
        journal.save(dose(2, 9))
        let doses = Adherence.doses(of: regimen, in: journal, from: date(2, 0), through: date(2, 23),
                                    now: date(3), calendar: calendar)
        guard case .taken = doses[0].status else { return XCTFail("\(doses)") }
    }

    func testIsAnswered() {
        var journal = Journal()
        let regimen = daily()
        journal.save(regimen)
        XCTAssertFalse(Adherence.isAnswered(regimen, at: date(2), in: journal, calendar: calendar))
        journal.save(dose(2, 7))
        XCTAssertTrue(Adherence.isAnswered(regimen, at: date(2), in: journal, calendar: calendar))
        journal.save(SkippedDose(regimenID: regimen.id, scheduledAt: date(3)))
        XCTAssertTrue(Adherence.isAnswered(regimen, at: date(3), in: journal, calendar: calendar))
    }

    // MARK: Schedule versions

    func testEditingAStartedScheduleKeepsItsHistory() {
        var journal = Journal()
        let original = daily()
        journal.save(original)
        for day in [1, 2, 3] { journal.save(dose(day)) }

        // On the 3rd at 21:00 the time moves from 08:00 to 21:30.
        var edited = original
        edited.schedule.times = [TimeOfDay(hour: 21, minute: 30)]
        journal.saveEdited(edited, now: date(3, 21))

        XCTAssertEqual(journal.regimens.count, 2)
        XCTAssertEqual(journal.activeRegimens.count, 1)
        let next = journal.activeRegimens[0]
        XCTAssertNotEqual(next.id, original.id)
        XCTAssertEqual(next.schedule.start, date(3, 21))

        // The past stays taken; the new version owes 21:30 from the 3rd on.
        let doses = Adherence.doses(in: journal, from: date(1, 0), through: date(4, 23), now: date(5, 12), calendar: calendar)
        XCTAssertEqual(doses.map(\.date), [date(1), date(2), date(3), calendar.date(byAdding: .minute, value: 30, to: date(3, 21))!,
                                           calendar.date(byAdding: .minute, value: 30, to: date(4, 21))!])
        XCTAssertEqual(Adherence.summary(doses), AdherenceSummary(taken: 3, skipped: 0, missed: 2))
    }

    func testEditsThatDoNotChangeThePlanStayInPlace() {
        var journal = Journal()
        var regimen = daily()
        journal.save(regimen)
        regimen.remindersOn = false
        journal.saveEdited(regimen, now: date(3))
        XCTAssertEqual(journal.regimens, [regimen])

        // A schedule that has not begun yet is simply replaced too.
        var future = daily(start: date(10))
        journal.save(future)
        future.dose = DoseAmount(value: 2, unit: .mg)
        journal.saveEdited(future, now: date(3))
        XCTAssertEqual(journal.regimens.count, 2)
        XCTAssertEqual(journal.activeRegimens.count, 2)
    }

    // MARK: Weekly recap

    func testWeeklyRecap() {
        var journal = Journal()
        let regimen = daily()
        journal.save(regimen)
        for day in [1, 2, 3] { journal.save(dose(day)) }  // Sunday 1st (last week), Mon, Tue
        journal.save(WeightEntry(date: date(1), kilograms: 90))
        journal.save(WeightEntry(date: date(3), kilograms: d("89.4")))
        journal.save(SideEffectEntry(date: date(3), symptom: .nausea, severity: 2))
        journal.save(SideEffectEntry(date: date(1), symptom: .nausea, severity: 2))

        // Wednesday 4th 09:00: Mon and Tue taken, Wed 08:00 still within its window.
        let recap = WeeklyRecap.make(journal, now: date(4, 9), calendar: calendar)
        XCTAssertEqual(recap, WeeklyRecap(taken: 2, due: 2, weightChangeKg: d("-0.6"), sideEffects: 1, streak: 3))
        XCTAssertFalse(recap.isEmpty)
        XCTAssertTrue(WeeklyRecap.make(Journal(), now: date(4), calendar: calendar).isEmpty)
        XCTAssertTrue(WeeklyRecap().isEmpty)
    }

    // MARK: Review moments

    func testReviewMoments() {
        XCTAssertNil(ReviewMoment.due(loggedDoses: 2, streak: 2, alreadyAsked: []))
        XCTAssertEqual(ReviewMoment.due(loggedDoses: 3, streak: 3, alreadyAsked: []), .thirdDose)
        XCTAssertNil(ReviewMoment.due(loggedDoses: 5, streak: 5, alreadyAsked: ["thirdDose"]))
        XCTAssertEqual(ReviewMoment.due(loggedDoses: 8, streak: 7, alreadyAsked: ["thirdDose"]), .sevenStreak)
        XCTAssertNil(ReviewMoment.due(loggedDoses: 9, streak: 8, alreadyAsked: ["thirdDose", "sevenStreak"]))
    }
}
