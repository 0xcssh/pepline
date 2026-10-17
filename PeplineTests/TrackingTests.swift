import XCTest
@testable import Pepline

final class TrackingTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ day: Int, _ hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: day, hour: hour))!
    }

    private let sema = Compound(name: "Semaglutide", halfLifeHours: 168)

    private func dose(_ day: Int, _ hour: Int = 8, mg: Decimal = 1, site: InjectionSite? = nil,
                      side: BodySide? = nil, compound: Compound? = nil) -> DoseEntry {
        DoseEntry(date: date(day, hour), compoundID: (compound ?? sema).id, amount: DoseAmount(value: mg, unit: .mg),
                  site: site, side: side)
    }

    private func dailyRegimen(_ compound: Compound? = nil) -> Regimen {
        Regimen(compoundID: (compound ?? sema).id, dose: DoseAmount(value: 1, unit: .mg),
                schedule: DoseSchedule(pattern: .everyNDays(1), start: date(1), end: nil, times: [TimeOfDay(hour: 8, minute: 0)]))
    }

    // MARK: Journal collections

    func testSaveAndDeleteEveryNewKind() {
        var journal = Journal()
        let skip = SkippedDose(regimenID: UUID(), scheduledAt: date(1))
        let effect = SideEffectEntry(date: date(1), symptom: .nausea, severity: 3)
        let food = FoodEntry(date: date(1), item: FoodItem(name: "Eggs", kcal: 140, protein: 12))
        let water = WaterEntry(date: date(1), milliliters: 250)
        let photo = ProgressPhoto(date: date(1), fileName: "a.jpg")
        journal.save(skip); journal.save(effect); journal.save(food); journal.save(water); journal.save(photo)
        XCTAssertEqual(journal.skippedDoses.count + journal.sideEffects.count + journal.foods.count
                       + journal.water.count + journal.photos.count, 5)
        journal.deleteSkipped(skip.id); journal.deleteSideEffect(effect.id); journal.deleteFood(food.id)
        journal.deleteWater(water.id); journal.deletePhoto(photo.id)
        XCTAssertEqual(journal, Journal())
    }

    func testToggleFavorite() {
        var journal = Journal()
        let item = FoodItem(name: "Greek yogurt", kcal: 100, protein: 17)
        journal.toggleFavorite(item)
        XCTAssertEqual(journal.favoriteFoods, [item])
        journal.toggleFavorite(item)
        XCTAssertTrue(journal.favoriteFoods.isEmpty)
    }

    func testOldFilesDecodeWithEmptyNewCollections() throws {
        let json = #"{"compounds":[],"vials":[],"doses":[],"regimens":[],"weights":[]}"#
        let journal = try JSONDecoder().decode(Journal.self, from: Data(json.utf8))
        XCTAssertEqual(journal, Journal())
        // Even an empty object loads as an empty journal.
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: Data("{}".utf8)), Journal())
    }

    func testFullRoundTrip() throws {
        var journal = Journal()
        journal.save(sema)
        journal.save(dailyRegimen())
        journal.save(dose(1, site: .thigh, side: .left))
        journal.save(SkippedDose(regimenID: journal.regimens[0].id, scheduledAt: date(2)))
        journal.save(SideEffectEntry(date: date(1), symptom: .other, customName: "Dizzy", severity: 2, notes: "after lunch"))
        journal.save(FoodEntry(date: date(1), item: FoodItem(name: "Bar", protein: 20, source: .barcode, barcode: "123"), servings: 2))
        journal.toggleFavorite(FoodItem(name: "Bar"))
        journal.save(WaterEntry(date: date(1), milliliters: 500))
        journal.save(ProgressPhoto(date: date(1), fileName: "p.jpg"))
        journal.nutritionGoals = NutritionGoals(kcal: 1800, protein: 120, fiber: 25, waterMl: 2000)
        journal.goalWeightKg = 80
        journal.preferredSyringe = .ml05
        let data = try JSONEncoder().encode(journal)
        XCTAssertEqual(try JSONDecoder().decode(Journal.self, from: data), journal)
    }

    // MARK: Side effects and nutrition

    func testSeverityIsClamped() {
        var entry = SideEffectEntry(date: date(1), symptom: .fatigue, severity: 9)
        XCTAssertEqual(entry.severity, 5)
        entry.severity = 0
        XCTAssertEqual(entry.severity, 1)
        XCTAssertEqual(SideEffectEntry(date: date(1), symptom: .headache, severity: -3).severity, 1)
    }

    func testDailyNutritionTotals() {
        var journal = Journal()
        journal.save(FoodEntry(date: date(1, 8), item: FoodItem(name: "Shake", kcal: 160, protein: 30, carbs: 5, fat: 3, fiber: 1), servings: 2))
        journal.save(FoodEntry(date: date(1, 12), item: FoodItem(name: "Salad", kcal: 200, protein: 10, carbs: 20, fat: 8, fiber: 6)))
        journal.save(FoodEntry(date: date(2, 12), item: FoodItem(name: "Other day", kcal: 999)))
        journal.save(WaterEntry(date: date(1, 9), milliliters: 250))
        journal.save(WaterEntry(date: date(1, 15), milliliters: 500))
        let totals = journal.nutrition(on: date(1, 20), calendar: calendar)
        XCTAssertEqual(totals, NutritionTotals(kcal: 520, protein: 70, carbs: 30, fat: 14, fiber: 8, waterMl: 750))
        XCTAssertEqual(journal.foods(on: date(1), calendar: calendar).map(\.item.name), ["Shake", "Salad"])
    }

    func testRecentFoodsAreDistinctNewestFirst() {
        var journal = Journal()
        for (index, name) in ["Eggs", "eggs", "Rice", "Tuna"].enumerated() {
            journal.save(FoodEntry(date: date(1, 8 + index), item: FoodItem(name: name)))
        }
        XCTAssertEqual(journal.recentFoods().map(\.name), ["Tuna", "Rice", "eggs"])
        XCTAssertEqual(journal.recentFoods(limit: 1).map(\.name), ["Tuna"])
    }

    func testSideEffectsAndPhotosOrdering() {
        var journal = Journal()
        journal.save(SideEffectEntry(date: date(1, 18), symptom: .reflux, severity: 2))
        journal.save(SideEffectEntry(date: date(1, 9), symptom: .nausea, severity: 3))
        journal.save(SideEffectEntry(date: date(2, 9), symptom: .fatigue, severity: 1))
        XCTAssertEqual(journal.sideEffects(on: date(1), calendar: calendar).map(\.symptom), [.nausea, .reflux])
        journal.save(ProgressPhoto(date: date(5), fileName: "b"))
        journal.save(ProgressPhoto(date: date(1), fileName: "a"))
        XCTAssertEqual(journal.photoSeries.map(\.fileName), ["a", "b"])
    }

    // MARK: Adherence

    func testTakenSkippedMissedUpcoming() {
        var journal = Journal()
        let regimen = dailyRegimen()
        journal.save(regimen)
        journal.save(dose(1, 9))                    // day 1: taken (1 h late)
        journal.save(SkippedDose(regimenID: regimen.id, scheduledAt: date(2)))  // day 2: skipped
        // day 3: nothing → missed; day 4 08:00 is after now → upcoming
        let doses = Adherence.doses(of: regimen, in: journal, from: date(1, 0), through: date(4, 23),
                                    now: date(4, 6), calendar: calendar)
        XCTAssertEqual(doses.map(\.date), [date(1), date(2), date(3), date(4)])
        guard case .taken = doses[0].status, case .skipped = doses[1].status else { return XCTFail("\(doses)") }
        XCTAssertEqual(doses[2].status, .missed)
        XCTAssertEqual(doses[3].status, .upcoming)

        let summary = Adherence.summary(doses)
        XCTAssertEqual(summary, AdherenceSummary(taken: 1, skipped: 1, missed: 1))
        XCTAssertEqual(summary.rate!, 1.0 / 3, accuracy: 0.0001)
        XCTAssertNil(AdherenceSummary().rate)
    }

    func testUpcomingSkipsLoggedAndSkippedDoses() {
        var journal = Journal()
        let regimen = dailyRegimen()
        journal.save(regimen)
        // Day 4 08:00 is an hour overdue but still within the tolerance.
        XCTAssertEqual(Adherence.upcoming(in: journal, now: date(4, 9), calendar: calendar, limit: 3).map(\.date),
                       [date(4), date(5), date(6)])
        journal.save(dose(4, 9))
        journal.save(SkippedDose(regimenID: regimen.id, scheduledAt: date(5)))
        XCTAssertEqual(Adherence.upcoming(in: journal, now: date(4, 10), calendar: calendar, limit: 2).map(\.date),
                       [date(6), date(7)])
        XCTAssertTrue(Adherence.upcoming(in: Journal(), now: date(4), calendar: calendar).isEmpty)
    }

    func testOneLoggedDoseAnswersOneScheduledDose() {
        var journal = Journal()
        let twice = Regimen(compoundID: sema.id, dose: DoseAmount(value: 1, unit: .mg),
                            schedule: DoseSchedule(pattern: .everyNDays(1), start: date(1), end: nil,
                                                   times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 14, minute: 0)]))
        journal.save(twice)
        journal.save(dose(1, 13))  // nearest to 14:00, also within 12 h of 08:00
        let doses = Adherence.doses(of: twice, in: journal, from: date(1, 0), through: date(1, 23),
                                    now: date(2, 12), calendar: calendar)
        XCTAssertEqual(doses[0].status, .missed)
        guard case .taken = doses[1].status else { return XCTFail("\(doses)") }

        // A second dose aimed at an already-answered slot does not count twice.
        journal.save(dose(1, 15))
        let again = Adherence.doses(of: twice, in: journal, from: date(1, 0), through: date(1, 23),
                                    now: date(2, 12), calendar: calendar)
        XCTAssertEqual(again[0].status, .missed)
    }

    func testAllRegimensAndStreak() {
        var journal = Journal()
        let other = Compound(name: "BPC-157")
        journal.save(dailyRegimen())
        journal.save(dailyRegimen(other))
        for day in 1...3 { journal.save(dose(day)) }
        journal.save(dose(3, compound: other))
        let doses = Adherence.doses(in: journal, from: date(1, 0), through: date(4, 23), now: date(4, 6), calendar: calendar)
        XCTAssertEqual(doses.count, 8)
        XCTAssertEqual(doses.map(\.date), doses.map(\.date).sorted())
        let semaDoses = doses.filter { $0.regimenID == journal.regimens[0].id }
        XCTAssertEqual(Adherence.streak(semaDoses), 3, "upcoming day 4 does not break it")
        let otherDoses = doses.filter { $0.regimenID == journal.regimens[1].id }
        XCTAssertEqual(Adherence.streak(otherDoses), 1, "a missed dose stops the count")
    }

    // MARK: Estimated levels

    func testFirstOrderDecay() {
        let doses = [(date: date(1), mg: 1.0)]
        XCTAssertEqual(MedicationLevel.amount(at: date(1), doses: doses, halfLifeHours: 168), 1, accuracy: 1e-9)
        XCTAssertEqual(MedicationLevel.amount(at: date(8), doses: doses, halfLifeHours: 168), 0.5, accuracy: 1e-9)
        XCTAssertEqual(MedicationLevel.amount(at: date(15), doses: doses, halfLifeHours: 168), 0.25, accuracy: 1e-9)
        XCTAssertEqual(MedicationLevel.amount(at: date(1, 7), doses: doses, halfLifeHours: 168), 0, "before the dose")
        XCTAssertEqual(MedicationLevel.amount(at: date(8), doses: doses, halfLifeHours: 0), 0)
        // Two weekly doses: 0.5 left from the first + 1 from the second.
        let weekly = [(date: date(1), mg: 1.0), (date: date(8), mg: 1.0)]
        XCTAssertEqual(MedicationLevel.amount(at: date(8), doses: weekly, halfLifeHours: 168), 1.5, accuracy: 1e-9)
    }

    func testSeries() {
        let doses = [(date: date(1), mg: 2.0)]
        let series = MedicationLevel.series(doses: doses, halfLifeHours: 168, from: date(1), through: date(15), points: 3)
        XCTAssertEqual(series.map(\.date), [date(1), date(8), date(15)])
        XCTAssertEqual(series.map(\.mg)[2], 0.5, accuracy: 1e-9)
        XCTAssertTrue(MedicationLevel.series(doses: doses, halfLifeHours: 168, from: date(2), through: date(1)).isEmpty)
        XCTAssertTrue(MedicationLevel.series(doses: doses, halfLifeHours: 168, from: date(1), through: date(2), points: 1).isEmpty)
    }

    func testLevelDosesInMilligrams() {
        var journal = Journal()
        let hgh = Compound(name: "Somatropin", iuConversion: .somatropin)
        let unknown = Compound(name: "Unknown")
        journal.save(sema); journal.save(hgh); journal.save(unknown)
        journal.save(DoseEntry(date: date(2), compoundID: sema.id, amount: DoseAmount(value: 500, unit: .mcg)))
        journal.save(dose(1))
        journal.save(DoseEntry(date: date(1), compoundID: hgh.id, amount: DoseAmount(value: 3, unit: .iu)))
        journal.save(DoseEntry(date: date(1), compoundID: unknown.id, amount: DoseAmount(value: 3, unit: .iu)))
        XCTAssertEqual(journal.levelDoses(of: sema.id).map(\.mg), [1, 0.5])
        XCTAssertEqual(journal.levelDoses(of: hgh.id).map(\.mg), [1])
        XCTAssertTrue(journal.levelDoses(of: unknown.id).isEmpty)
    }

    // MARK: Site rotation

    func testLastUseAndLeastRecent() {
        var journal = Journal()
        let other = Compound(name: "BPC-157")
        journal.save(dose(3, site: .abdomen, side: .left))
        journal.save(dose(1, site: .abdomen, side: .left))   // older use of the same zone
        journal.save(dose(2, site: .thigh, side: .right))
        journal.save(dose(4, site: .arm, side: nil))          // no side: not a zone
        journal.save(dose(5, site: .glute, side: .left, compound: other))
        let all = SiteRotation.lastUse(in: journal)
        XCTAssertEqual(all[SiteZone(site: .abdomen, side: .left)], date(3))
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(SiteRotation.lastUse(in: journal, compoundID: sema.id).count, 2)
        XCTAssertEqual(SiteRotation.daysSince(SiteZone(site: .thigh, side: .right), lastUse: all, now: date(6), calendar: calendar), 4)
        XCTAssertNil(SiteRotation.daysSince(SiteZone(site: .arm, side: .left), lastUse: all, now: date(6), calendar: calendar))
        XCTAssertEqual(SiteRotation.leastRecent(lastUse: all), SiteZone(site: .abdomen, side: .right), "first unused zone")

        var used: [SiteZone: Date] = [:]
        for (index, zone) in SiteZone.allCases.enumerated() { used[zone] = date(10 - index) }
        XCTAssertEqual(SiteRotation.leastRecent(lastUse: used), SiteZone.allCases.last)
        XCTAssertEqual(SiteZone.allCases.count, 8)
    }

    // MARK: Weight stats

    func testWeightStats() {
        let weights = [WeightEntry(date: date(15), kilograms: 98), WeightEntry(date: date(1), kilograms: 100)]
        let stats = WeightStats.compute(weights, goalKg: 90)!
        XCTAssertEqual(stats.startKg, 100)
        XCTAssertEqual(stats.latestKg, 98)
        XCTAssertEqual(stats.changeKg, -2)
        XCTAssertEqual(stats.changePercent, -2)
        XCTAssertEqual(stats.toGoalKg, 8)
        XCTAssertEqual(stats.weeklyChangeKg, -1)
        let single = WeightStats.compute([WeightEntry(date: date(1), kilograms: 80)], goalKg: nil)!
        XCTAssertNil(single.toGoalKg)
        XCTAssertNil(single.weeklyChangeKg)
        XCTAssertNil(WeightStats.compute([], goalKg: nil))
        XCTAssertNil(WeightStats.compute([WeightEntry(date: date(1), kilograms: 0)], goalKg: nil))
    }

    func testActiveDose() {
        var journal = Journal()
        journal.save(dose(1, mg: d("0.25")))
        journal.save(dose(10, mg: d("0.5")))
        XCTAssertNil(WeightStats.activeDose(at: date(1, 7), compoundID: sema.id, in: journal))
        XCTAssertEqual(WeightStats.activeDose(at: date(5), compoundID: sema.id, in: journal)?.value, d("0.25"))
        XCTAssertEqual(WeightStats.activeDose(at: date(12), compoundID: sema.id, in: journal)?.value, d("0.5"))
    }

    func testPresetsCarryLabelHalfLives() {
        XCTAssertEqual(CompoundPreset.named("Semaglutide")?.halfLifeHours, 168)
        XCTAssertEqual(CompoundPreset.named("Tirzepatide")?.halfLifeHours, 120)
        XCTAssertEqual(CompoundPreset.named("Liraglutide")?.halfLifeHours, 13)
        XCTAssertNil(CompoundPreset.named("BPC-157")?.halfLifeHours)
        var journal = Journal()
        var answers = OnboardingAnswers()
        answers.compounds = ["Tirzepatide"]
        answers.seed(into: &journal, now: date(1))
        XCTAssertEqual(journal.compounds.first?.halfLifeHours, 120)
    }
}
