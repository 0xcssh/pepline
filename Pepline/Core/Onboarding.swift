import Foundation

/// What the onboarding asks. Every answer configures the app (compounds,
/// default syringe, weight log, goal line) or picks the wording of the next
/// screen — nothing is asked "to personalize" and then thrown away.
struct OnboardingAnswers: Codable, Equatable {
    enum Goal: String, Codable, CaseIterable {
        case weightLoss, buildRecover, heal, skinHair, sleep, longevity, other
    }

    var name = ""
    var goals: Set<Goal> = []
    /// Picked presets and typed names, in the order chosen.
    var compounds: [String] = []
    var syringe: SyringeModel = .ml05
    var weightKg: Decimal?
    var goalWeightKg: Decimal?

    /// The weight screen only makes sense for a weight-loss goal.
    var asksWeight: Bool { goals.contains(.weightLoss) }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Writes the answers into the journal: one compound per name (no
    /// duplicates, IU factor for presets that have one), the default syringe,
    /// the starting weight and the goal weight.
    func seed(into journal: inout Journal, now: Date) {
        for raw in compounds {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty,
                  !journal.compounds.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
            else { continue }
            let preset = CompoundPreset.named(name)
            journal.save(Compound(name: name, iuConversion: preset?.iuConversion, halfLifeHours: preset?.halfLifeHours))
        }
        journal.preferredSyringe = syringe
        guard asksWeight else { return }
        if let weightKg, weightKg > 0 {
            journal.save(WeightEntry(date: now, kilograms: weightKg))
        }
        if let goalWeightKg, goalWeightKg > 0 {
            journal.goalWeightKg = goalWeightKg
        }
    }
}

/// Compounds offered as one-tap choices. Generic names only (no brand
/// names: App Review 5.2.1). An IU factor only where a pharmacopoeia sets one.
struct CompoundPreset: Equatable {
    var name: String
    var iuConversion: IUConversion?
    /// Elimination half-life from the product label (docs/SOURCES.md
    /// § Half-lives); nil when no label states one.
    var halfLifeHours: Decimal?

    static let all: [CompoundPreset] = [
        // Ozempic label §12.3: "approximately 1 week".
        CompoundPreset(name: "Semaglutide", halfLifeHours: 168),
        // Mounjaro label (via Lilly Medical): approximately 5 days.
        CompoundPreset(name: "Tirzepatide", halfLifeHours: 120),
        // Saxenda label: approximately 13 hours.
        CompoundPreset(name: "Liraglutide", halfLifeHours: 13),
        CompoundPreset(name: "Retatrutide"),
        CompoundPreset(name: "BPC-157"),
        CompoundPreset(name: "TB-500"),
        CompoundPreset(name: "Ipamorelin"),
        CompoundPreset(name: "CJC-1295"),
        CompoundPreset(name: "GHK-Cu"),
        CompoundPreset(name: "NAD+"),
        CompoundPreset(name: "Somatropin", iuConversion: .somatropin),
    ]

    static func named(_ name: String) -> CompoundPreset? {
        all.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
}

/// Short on purpose (decision 2026-10-17): the "aha" — the user's own vial
/// drawn on their syringe — comes third (SOSA 2026 p17, p67: day 0 decides,
/// show value fast; p27: app onboarding rushes to the aha). Features are
/// taught in context inside the app, not toured here (p116). Every remaining
/// question configures the app.
enum OnboardingStep: String, CaseIterable {
    case welcome, compounds, firstVial, name, goals, weight
    /// `building` shows the real setup being written (compounds, syringe,
    /// reminders) before the personalised summary and the paywall.
    case reminders, account, disclaimer, building, ahead

    /// The screens for these answers, in order.
    static func steps(for answers: OnboardingAnswers) -> [OnboardingStep] {
        allCases.filter { $0 != .weight || answers.asksWeight }
    }

    func next(for answers: OnboardingAnswers) -> OnboardingStep? {
        let steps = OnboardingStep.steps(for: answers)
        guard let index = steps.firstIndex(of: self), index + 1 < steps.count else { return nil }
        return steps[index + 1]
    }

    func previous(for answers: OnboardingAnswers) -> OnboardingStep? {
        let steps = OnboardingStep.steps(for: answers)
        guard let index = steps.firstIndex(of: self), index > 0 else { return nil }
        return steps[index - 1]
    }

    /// 0…1 for the progress bar.
    func progress(for answers: OnboardingAnswers) -> Double {
        let steps = OnboardingStep.steps(for: answers)
        guard let index = steps.firstIndex(of: self) else { return 0 }
        return Double(index + 1) / Double(steps.count)
    }
}
