import XCTest
@testable import Pepline

final class ReportTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    func testReportCollectsThePeriodOnly() {
        var journal = Journal()
        let sema = Compound(name: "Semaglutide")
        journal.save(sema)
        let regimen = Regimen(compoundID: sema.id, dose: DoseAmount(value: 1, unit: .mg),
                              schedule: DoseSchedule(pattern: .everyNDays(1), start: date(1), end: nil,
                                                     times: [TimeOfDay(hour: 8, minute: 0)]))
        let orphan = Regimen(compoundID: UUID(), dose: DoseAmount(value: 5, unit: .mg),
                             schedule: DoseSchedule(pattern: .everyNDays(7), start: date(1), end: nil,
                                                    times: [TimeOfDay(hour: 8, minute: 0)]))
        journal.save(regimen)
        journal.save(orphan)
        for day in [1, 2, 4, 20] {
            journal.save(DoseEntry(date: date(day), compoundID: sema.id, amount: DoseAmount(value: 1, unit: .mg)))
        }
        journal.save(WeightEntry(date: date(1), kilograms: 100))
        journal.save(WeightEntry(date: date(5), kilograms: d("98.6")))
        journal.save(WeightEntry(date: date(25), kilograms: 90))
        journal.save(SideEffectEntry(date: date(2), symptom: .nausea, severity: 2))
        journal.save(SideEffectEntry(date: date(3), symptom: .nausea, severity: 3))
        journal.save(SideEffectEntry(date: date(3), symptom: .fatigue, severity: 1))
        journal.save(SideEffectEntry(date: date(4), symptom: .headache, severity: 4))
        journal.save(SideEffectEntry(date: date(21), symptom: .reflux, severity: 5))

        let report = ReportData.make(journal, from: date(1, 0), through: date(5, 23), now: date(6), calendar: calendar)

        XCTAssertEqual(report.doses.map(\.date), [date(1), date(2), date(4)])
        XCTAssertEqual(report.regimens.map(\.compoundName), ["Semaglutide", ""])
        XCTAssertEqual(report.regimens[0].adherence, AdherenceSummary(taken: 3, skipped: 0, missed: 2))
        XCTAssertEqual(report.weights.count, 2)
        XCTAssertEqual(report.weightChangeKg, d("-1.4"))
        XCTAssertEqual(report.sideEffects.count, 4)
        XCTAssertEqual(report.symptoms, [
            ReportData.SymptomLine(symptom: .nausea, count: 2, averageSeverity: d("2.5")),
            ReportData.SymptomLine(symptom: .fatigue, count: 1, averageSeverity: 1),
            ReportData.SymptomLine(symptom: .headache, count: 1, averageSeverity: 4),
        ])
    }

    func testEmptyPeriod() {
        let report = ReportData.make(Journal(), from: date(1), through: date(2), now: date(3), calendar: calendar)
        XCTAssertTrue(report.doses.isEmpty && report.regimens.isEmpty && report.symptoms.isEmpty)
        XCTAssertNil(report.weightChangeKg)
    }
}
