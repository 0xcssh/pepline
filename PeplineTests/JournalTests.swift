import XCTest
@testable import Pepline

final class JournalTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private lazy var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int = 8, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour, minute: minute))!
    }

    private let sema = Compound(name: "Semaglutide")
    private let hgh = Compound(name: "Somatropin", iuConversion: .somatropin)

    private func vial(_ compound: Compound, mg: Decimal = 5, water: Decimal = 2) throws -> Vial {
        Vial(compoundID: compound.id, reconstitution: try Reconstitution(vial: .mg(mg), waterMl: water),
             syringe: .ml05, mixedAt: date(1))
    }

    private func dose(_ compound: Compound, _ value: Decimal, _ unit: DoseUnit, day: Int, hour: Int = 8,
                      vial: Vial? = nil, site: InjectionSite? = nil, side: BodySide? = nil) -> DoseEntry {
        DoseEntry(date: date(day, hour), compoundID: compound.id, vialID: vial?.id,
                  amount: DoseAmount(value: value, unit: unit), site: site, side: side)
    }

    // MARK: Amounts

    func testDoseAmountToMass() {
        XCTAssertEqual(DoseAmount(value: 250, unit: .mcg).mass(nil), .mcg(250))
        XCTAssertEqual(DoseAmount(value: d("0.25"), unit: .mg).mass(nil), .mcg(250))
        XCTAssertEqual(DoseAmount(value: 6, unit: .iu).mass(.somatropin), .mg(2))
        XCTAssertNil(DoseAmount(value: 6, unit: .iu).mass(nil))
        XCTAssertNil(DoseAmount(value: 6, unit: .iu).mass(IUConversion(iuPerMg: 0)))
    }

    // MARK: Edits

    func testSaveInsertsThenEdits() {
        var journal = Journal()
        var entry = dose(sema, d("0.25"), .mg, day: 1)
        journal.save(entry)
        entry.notes = "logged on the wrong day"
        entry.date = date(2)
        journal.save(entry)
        XCTAssertEqual(journal.doses, [entry])

        journal.save(sema)
        journal.save(Compound(id: sema.id, name: "Sema"))
        XCTAssertEqual(journal.compounds.map(\.name), ["Sema"])
    }

    func testDeleteEachKind() throws {
        var journal = Journal()
        let entry = dose(sema, 1, .mg, day: 1)
        let regimen = Regimen(compoundID: sema.id, dose: DoseAmount(value: 1, unit: .mg),
                              schedule: DoseSchedule(pattern: .everyNDays(7), start: date(1), times: [TimeOfDay(hour: 8, minute: 0)]))
        let weight = WeightEntry(date: date(1), kilograms: 90)
        journal.save(entry)
        journal.save(regimen)
        journal.save(weight)
        journal.deleteDose(entry.id)
        journal.deleteRegimen(regimen.id)
        journal.deleteWeight(weight.id)
        XCTAssertEqual(journal, Journal())
    }

    func testDeletingAVialKeepsItsDoses() throws {
        var journal = Journal()
        let v = try vial(sema)
        journal.save(v)
        journal.save(dose(sema, d("0.25"), .mg, day: 1, vial: v))
        journal.deleteVial(v.id)
        XCTAssertTrue(journal.vials.isEmpty)
        XCTAssertEqual(journal.doses.count, 1)
        XCTAssertNil(journal.doses[0].vialID)
    }

    func testDeletingACompoundCascades() throws {
        var journal = Journal()
        journal.save(sema)
        journal.save(hgh)
        journal.save(try vial(sema))
        journal.save(dose(sema, 1, .mg, day: 1))
        journal.save(dose(hgh, 2, .iu, day: 1))
        journal.save(Regimen(compoundID: sema.id, dose: DoseAmount(value: 1, unit: .mg),
                             schedule: DoseSchedule(pattern: .everyNDays(1), start: date(1), times: [TimeOfDay(hour: 8, minute: 0)])))
        journal.deleteCompound(sema.id)
        XCTAssertEqual(journal.compounds, [hgh])
        XCTAssertTrue(journal.vials.isEmpty)
        XCTAssertTrue(journal.regimens.isEmpty)
        XCTAssertEqual(journal.doses.map(\.compoundID), [hgh.id])
    }

    // MARK: Queries

    func testDosesByDayNewestFirst() {
        var journal = Journal()
        let late = dose(sema, 1, .mg, day: 2, hour: 20)
        let early = dose(hgh, 2, .iu, day: 2, hour: 7)
        let first = dose(sema, 1, .mg, day: 1)
        [late, first, early].forEach { journal.save($0) }
        let days = journal.dosesByDay(calendar: calendar)
        XCTAssertEqual(days.map(\.day), [date(2, 0), date(1, 0)])
        XCTAssertEqual(days[0].doses, [early, late])
        XCTAssertEqual(days[1].doses, [first])
    }

    func testDosesOfCompound() {
        var journal = Journal()
        let a = dose(sema, 1, .mg, day: 1)
        let b = dose(sema, 1, .mg, day: 3)
        journal.save(a)
        journal.save(dose(hgh, 2, .iu, day: 2))
        journal.save(b)
        XCTAssertEqual(journal.doses(of: sema.id), [b, a])
        XCTAssertEqual(journal.compound(hgh.id), nil, "compound not saved yet")
    }

    func testRemainingInVial() throws {
        var journal = Journal()
        journal.save(sema)
        let v = try vial(sema)
        journal.save(v)
        XCTAssertEqual(journal.remaining(in: v), .mg(5))
        journal.save(dose(sema, d("0.25"), .mg, day: 1, vial: v))
        journal.save(dose(sema, 500, .mcg, day: 8, vial: v))
        journal.save(dose(sema, 1, .mg, day: 9))  // not from this vial
        XCTAssertEqual(journal.remaining(in: v), .mg(d("4.25")))
        journal.save(dose(sema, 10, .mg, day: 15, vial: v))
        XCTAssertEqual(journal.remaining(in: v), .zero, "never below zero")
    }

    func testRemainingConvertsIU() throws {
        var journal = Journal()
        journal.save(hgh)
        let v = try vial(hgh, mg: 4, water: 1)  // 12 IU
        journal.save(v)
        journal.save(dose(hgh, 3, .iu, day: 1, vial: v))
        XCTAssertEqual(journal.remaining(in: v), .mg(3))

        // Without a factor the IU dose cannot be subtracted.
        let noFactor = Compound(name: "Unknown")
        journal.save(noFactor)
        let other = try vial(noFactor)
        journal.save(other)
        journal.save(dose(noFactor, 3, .iu, day: 1, vial: other))
        XCTAssertEqual(journal.remaining(in: other), .mg(5))
    }

    func testLastSite() {
        var journal = Journal()
        XCTAssertNil(journal.lastSite(of: sema.id))
        journal.save(dose(sema, 1, .mg, day: 1, site: .abdomen, side: .left))
        journal.save(dose(sema, 1, .mg, day: 2, site: .thigh, side: .right))
        journal.save(dose(sema, 1, .mg, day: 3))  // no site logged
        let last = journal.lastSite(of: sema.id)
        XCTAssertEqual(last?.site, .thigh)
        XCTAssertEqual(last?.side, .right)
    }

    func testWeightSeriesOldestFirst() {
        var journal = Journal()
        let b = WeightEntry(date: date(5), kilograms: d("89.4"))
        let a = WeightEntry(date: date(1), kilograms: 91)
        journal.save(b)
        journal.save(a)
        XCTAssertEqual(journal.weightSeries, [a, b])
    }

    func testCodableRoundTrip() throws {
        var journal = Journal()
        journal.save(hgh)
        let v = try vial(hgh)
        journal.save(v)
        journal.save(dose(hgh, d("1.5"), .iu, day: 1, vial: v, site: .glute, side: .left))
        journal.save(WeightEntry(date: date(1), kilograms: d("80.25")))
        let data = try JSONEncoder().encode(journal)
        let decoded = try JSONDecoder().decode(Journal.self, from: data)
        XCTAssertEqual(decoded, journal)
        XCTAssertEqual(decoded.version, Journal.currentVersion)
    }

    // MARK: CSV

    func testDosesCSV() {
        var journal = Journal()
        journal.save(sema)
        var entry = dose(sema, d("0.25"), .mg, day: 1, site: .abdomen, side: .left)
        entry.notes = "felt \"fine\", slept\nwell"
        journal.save(entry)
        journal.save(dose(Compound(name: "deleted"), 250, .mcg, day: 2))
        XCTAssertEqual(CSVExport.doses(journal, timeZone: utc),
                       "date,compound,amount,unit,site,side,notes\r\n"
                       + "2026-01-01T08:00:00Z,Semaglutide,0.25,mg,abdomen,left,\"felt \"\"fine\"\", slept\nwell\"\r\n"
                       + "2026-01-02T08:00:00Z,,250,mcg,,,\r\n")
    }

    func testDosesCSVUsesTheGivenTimeZone() {
        var journal = Journal()
        journal.save(sema)
        journal.save(dose(sema, 1, .mg, day: 1))
        let paris = CSVExport.doses(journal, timeZone: TimeZone(identifier: "Europe/Paris")!)
        XCTAssertTrue(paris.contains("2026-01-01T09:00:00+01:00"), paris)
    }

    func testWeightsCSV() {
        var journal = Journal()
        journal.save(WeightEntry(date: date(2), kilograms: d("89.5")))
        journal.save(WeightEntry(date: date(1), kilograms: 90))
        XCTAssertEqual(CSVExport.weights(journal, timeZone: utc),
                       "date,kg\r\n2026-01-01T08:00:00Z,90\r\n2026-01-02T08:00:00Z,89.5\r\n")
    }

    func testCSVFieldQuoting() {
        XCTAssertEqual(CSVExport.field("plain"), "plain")
        XCTAssertEqual(CSVExport.field("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVExport.field("say \"hi\""), "\"say \"\"hi\"\"\"")
        XCTAssertEqual(CSVExport.field("line\r\nbreak"), "\"line\r\nbreak\"")
    }
}
