import XCTest
@testable import Pepline

final class ReminderPlannerTests: XCTestCase {
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }()

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private let sema = Compound(name: "Semaglutide")
    private let bpc = Compound(name: "BPC-157")

    private func regimen(_ compound: Compound, _ pattern: DoseSchedule.Pattern, hour: Int = 8,
                         dose: DoseAmount = DoseAmount(value: d("0.25"), unit: .mg),
                         end: Date? = nil, reorderLeadDays: Int? = nil) -> Regimen {
        Regimen(compoundID: compound.id, dose: dose,
                schedule: DoseSchedule(pattern: pattern, start: date(1, 1), end: end,
                                       times: [TimeOfDay(hour: hour, minute: 0)]),
                reorderLeadDays: reorderLeadDays)
    }

    private func vial(_ compound: Compound, mg: Decimal, mixed: Date) throws -> Vial {
        Vial(compoundID: compound.id, reconstitution: try Reconstitution(vial: .mg(mg), waterMl: 2),
             syringe: .ml05, mixedAt: mixed)
    }

    func testMergesRegimensEarliestFirst() {
        var journal = Journal()
        let weekly = regimen(sema, .everyNDays(7), hour: 9)
        let daily = regimen(bpc, .everyNDays(1), hour: 20)
        journal.save(weekly)
        journal.save(daily)
        let plan = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar, limit: 4)
        XCTAssertEqual(plan.map(\.date), [date(1, 1, 9), date(1, 1, 20), date(1, 2, 20), date(1, 3, 20)])
        XCTAssertEqual(plan.map(\.kind), [.dose(weekly.id), .dose(daily.id), .dose(daily.id), .dose(daily.id)])
    }

    func testRespectsTheNotificationCap() {
        var journal = Journal()
        journal.save(regimen(sema, .everyNDays(1)))
        journal.save(regimen(bpc, .everyNDays(1), hour: 20))
        let plan = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar)
        XCTAssertEqual(plan.count, ReminderPlanner.maxPending)
        XCTAssertLessThan(ReminderPlanner.maxPending, 64)
        XCTAssertEqual(plan.map(\.date), plan.map(\.date).sorted())
    }

    func testIDsAreStableAndUnique() {
        var journal = Journal()
        journal.save(regimen(sema, .everyNDays(1)))
        let first = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar, limit: 5)
        let later = ReminderPlanner.plan(journal, now: date(1, 2), calendar: calendar, limit: 5)
        XCTAssertEqual(Set(first.map(\.id)).count, 5)
        XCTAssertEqual(Array(first.map(\.id).dropFirst()), Array(later.map(\.id).prefix(4)),
                       "a replan keeps the same IDs for the same doses")
    }

    func testNoReminderForADoseAlreadyLoggedOrSkipped() {
        var journal = Journal()
        let daily = regimen(sema, .everyNDays(1))
        journal.save(daily)
        journal.save(DoseEntry(date: date(1, 1, 7), compoundID: sema.id, amount: daily.dose))
        journal.save(SkippedDose(regimenID: daily.id, scheduledAt: date(1, 2, 8)))
        let plan = ReminderPlanner.plan(journal, now: date(1, 1, 7), calendar: calendar, limit: 2)
        XCTAssertEqual(plan.map(\.date), [date(1, 3, 8), date(1, 4, 8)])
    }

    func testIDsChangeWithTheDose() {
        var journal = Journal()
        var daily = regimen(sema, .everyNDays(1))
        journal.save(daily)
        let before = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar, limit: 1)
        daily.dose = DoseAmount(value: d("0.5"), unit: .mg)
        journal.save(daily)
        let after = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar, limit: 1)
        XCTAssertNotEqual(before.map(\.id), after.map(\.id), "pending reminders get the new text")
    }

    func testSkipsRegimensWithRemindersOffOrEnded() {
        var journal = Journal()
        var off = regimen(sema, .everyNDays(1))
        off.remindersOn = false
        journal.save(off)
        journal.save(regimen(bpc, .everyNDays(1), end: date(1, 2)))
        let plan = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar)
        XCTAssertEqual(plan.map(\.date), [date(1, 1, 8), date(1, 2, 8)])
    }

    func testReorderReminder() throws {
        var journal = Journal()
        journal.save(sema)
        // 5 mg at 0.25 mg daily from Jan 1: runs out Jan 21 08:00; 7 days before = Jan 14.
        let old = try vial(sema, mg: 5, mixed: date(1, 1))
        var archived = try vial(sema, mg: 100, mixed: date(1, 2))
        archived.isArchived = true
        journal.save(old)
        journal.save(archived)
        let daily = regimen(sema, .everyNDays(1), reorderLeadDays: 7)
        journal.save(daily)
        let plan = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar)
        let reorders = plan.filter { if case .reorder = $0.kind { return true } else { return false } }
        XCTAssertEqual(reorders, [PlannedReminder(id: "reorder.\(old.id.uuidString)", kind: .reorder(old.id),
                                                  date: date(1, 14, 8))])

        // The newest active vial is the one followed.
        let fresh = try vial(sema, mg: 10, mixed: date(1, 3))
        journal.save(fresh)
        let next = ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar)
        XCTAssertTrue(next.contains { $0.kind == .reorder(fresh.id) })
        XCTAssertFalse(next.contains { $0.kind == .reorder(old.id) })
    }

    func testNoReorderReminderWhenDueOffOrUnknown() throws {
        var journal = Journal()
        journal.save(sema)
        journal.save(try vial(sema, mg: 1, mixed: date(1, 1)))  // 4 doses: runs out Jan 5
        journal.save(regimen(sema, .everyNDays(1), reorderLeadDays: 7))
        XCTAssertFalse(ReminderPlanner.plan(journal, now: date(1, 1), calendar: calendar)
            .contains { if case .reorder = $0.kind { return true } else { return false } },
                       "reorder date already passed")

        var other = Journal()
        other.save(bpc)
        other.save(try vial(bpc, mg: 5, mixed: date(1, 1)))
        other.save(regimen(bpc, .everyNDays(1), reorderLeadDays: nil))
        other.save(regimen(bpc, .everyNDays(1), dose: DoseAmount(value: 2, unit: .iu), reorderLeadDays: 7))
        XCTAssertFalse(ReminderPlanner.plan(other, now: date(1, 1), calendar: calendar)
            .contains { if case .reorder = $0.kind { return true } else { return false } },
                       "lead days off, or IU without a factor")
    }

    func testEmptyJournalPlansNothing() {
        XCTAssertEqual(ReminderPlanner.plan(Journal(), now: date(1, 1), calendar: calendar), [])
    }
}
