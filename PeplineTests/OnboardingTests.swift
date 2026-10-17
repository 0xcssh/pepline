import XCTest
@testable import Pepline

final class OnboardingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    // MARK: Flow

    func testWeightStepOnlyForWeightLoss() {
        var answers = OnboardingAnswers()
        XCTAssertFalse(OnboardingStep.steps(for: answers).contains(.weight))
        answers.goals = [.heal]
        XCTAssertFalse(OnboardingStep.steps(for: answers).contains(.weight))
        answers.goals = [.heal, .weightLoss]
        XCTAssertTrue(OnboardingStep.steps(for: answers).contains(.weight))
        XCTAssertEqual(OnboardingStep.steps(for: answers).count, OnboardingStep.allCases.count)
    }

    func testNavigation() {
        var answers = OnboardingAnswers()
        // The aha (the user's own vial) is the third screen.
        XCTAssertEqual(OnboardingStep.steps(for: answers).prefix(3), [.welcome, .compounds, .firstVial])
        XCTAssertNil(OnboardingStep.welcome.previous(for: answers))
        XCTAssertNil(OnboardingStep.ahead.next(for: answers))
        XCTAssertEqual(OnboardingStep.ahead.previous(for: answers), .building)
        XCTAssertEqual(OnboardingStep.building.previous(for: answers), .disclaimer)
        // Without a weight goal the goals screen goes straight to reminders.
        XCTAssertEqual(OnboardingStep.goals.next(for: answers), .reminders)
        XCTAssertEqual(OnboardingStep.reminders.previous(for: answers), .goals)
        answers.goals = [.weightLoss]
        XCTAssertEqual(OnboardingStep.goals.next(for: answers), .weight)
        XCTAssertEqual(OnboardingStep.reminders.previous(for: answers), .weight)
        // A step that is not in this flow has no neighbours and no progress.
        let noWeight = OnboardingAnswers()
        XCTAssertNil(OnboardingStep.weight.next(for: noWeight))
        XCTAssertNil(OnboardingStep.weight.previous(for: noWeight))
        XCTAssertEqual(OnboardingStep.weight.progress(for: noWeight), 0)
    }

    func testProgress() {
        let answers = OnboardingAnswers()
        let count = Double(OnboardingStep.steps(for: answers).count)
        XCTAssertEqual(OnboardingStep.welcome.progress(for: answers), 1 / count)
        XCTAssertEqual(OnboardingStep.ahead.progress(for: answers), 1)
    }

    // MARK: Answers

    func testTrimmedName() {
        var answers = OnboardingAnswers()
        answers.name = "  Sam \n"
        XCTAssertEqual(answers.trimmedName, "Sam")
    }

    func testPresets() {
        XCTAssertEqual(CompoundPreset.named("somatropin")?.iuConversion, .somatropin)
        XCTAssertNil(CompoundPreset.named("Semaglutide")?.iuConversion)
        XCTAssertNil(CompoundPreset.named("Unknown"))
        XCTAssertEqual(Set(CompoundPreset.all.map(\.name)).count, CompoundPreset.all.count, "no duplicates")
    }

    // MARK: Seeding the journal

    func testSeedCreatesCompoundsOnceWithIUFactor() {
        var journal = Journal()
        journal.save(Compound(name: "Semaglutide"))
        var answers = OnboardingAnswers()
        answers.compounds = ["semaglutide", "Somatropin", "  ", "My blend", "my blend"]
        answers.syringe = .ml03HalfUnit
        answers.seed(into: &journal, now: now)
        XCTAssertEqual(journal.compounds.map(\.name), ["Semaglutide", "Somatropin", "My blend"])
        XCTAssertEqual(journal.compounds[1].iuConversion, .somatropin)
        XCTAssertNil(journal.compounds[2].iuConversion)
        XCTAssertEqual(journal.preferredSyringe, .ml03HalfUnit)
        XCTAssertTrue(journal.weights.isEmpty, "no weight goal, no weight entry")
    }

    func testSeedWeightOnlyForWeightLoss() {
        var answers = OnboardingAnswers()
        answers.weightKg = 95
        answers.goalWeightKg = 80
        var journal = Journal()
        answers.seed(into: &journal, now: now)
        XCTAssertTrue(journal.weights.isEmpty)
        XCTAssertNil(journal.goalWeightKg)

        answers.goals = [.weightLoss]
        answers.seed(into: &journal, now: now)
        XCTAssertEqual(journal.weights, [WeightEntry(id: journal.weights[0].id, date: now, kilograms: 95)])
        XCTAssertEqual(journal.goalWeightKg, 80)
    }

    func testSeedIgnoresEmptyWeights() {
        var answers = OnboardingAnswers()
        answers.goals = [.weightLoss]
        answers.weightKg = 0
        var journal = Journal()
        answers.seed(into: &journal, now: now)
        XCTAssertTrue(journal.weights.isEmpty)
        XCTAssertNil(journal.goalWeightKg)
    }

    func testAnswersCodable() throws {
        var answers = OnboardingAnswers()
        answers.name = "Sam"
        answers.goals = [.weightLoss, .sleep]
        let data = try JSONEncoder().encode(answers)
        XCTAssertEqual(try JSONDecoder().decode(OnboardingAnswers.self, from: data), answers)
    }

    func testOldJournalFilesStillDecode() throws {
        // A file written before goalWeightKg / preferredSyringe existed.
        let json = #"{"version":1,"compounds":[],"vials":[],"doses":[],"regimens":[],"weights":[]}"#
        let journal = try JSONDecoder().decode(Journal.self, from: Data(json.utf8))
        XCTAssertNil(journal.goalWeightKg)
        XCTAssertNil(journal.preferredSyringe)
    }
}
