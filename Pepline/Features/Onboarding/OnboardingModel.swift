import Foundation

/// Drives the onboarding: the answers, the current step (pure order in
/// Core/Onboarding.swift), the live calculator of the "your vial" screen and
/// the reminder set up at the end.
@MainActor
final class OnboardingModel: ObservableObject {
    @Published var answers = OnboardingAnswers()
    @Published private(set) var step = OnboardingStep.welcome
    /// Screen 16 reuses the app's calculator model as is.
    let calculator = CalculatorModel()
    @Published var vialCompound = ""
    @Published var reminderRhythm = ReminderRhythm.daily
    @Published var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    @Published var remindersOn = false

    init() {
        trackStep()
    }

    var progress: Double { step.progress(for: answers) }
    var canGoBack: Bool { step.previous(for: answers) != nil }

    /// Whether the main button is enabled on the current screen.
    var canContinue: Bool {
        switch step {
        case .goals: return !answers.goals.isEmpty
        default: return true
        }
    }

    func advance() {
        if step == .firstVial { answers.syringe = calculator.syringe }
        if step == .compounds, vialCompound.isEmpty { vialCompound = answers.compounds.first ?? "" }
        guard let next = step.next(for: answers) else { return }
        step = next
        trackStep()
    }

    func goBack() {
        guard let previous = step.previous(for: answers) else { return }
        step = previous
    }

    /// A schedule can only be created when the vial screen gave a dose.
    var reminderDose: DoseAmount? {
        guard let value = decimalValue(calculator.doseText), value > 0 else { return nil }
        return DoseAmount(value: value, unit: calculator.doseUnit)
    }

    private func trackStep() {
        let index = OnboardingStep.steps(for: answers).firstIndex(of: step) ?? 0
        Analytics.track(.onboardingStep, ["index": String(format: "%02d", index), "step": step.rawValue])
    }

    /// Writes everything into the journal: compounds, syringe, weight, the
    /// vial typed on screen 16 and, if asked for, its schedule.
    func finish(into store: DataStore) {
        let answers = answers
        let reconstitution = calculator.reconstitution
        let syringe = calculator.syringe
        let factor = calculator.iuConversion
        let typed = vialCompound.trimmingCharacters(in: .whitespacesAndNewlines)
        // A vial typed without picking a compound is kept under a neutral
        // name the user can rename in Settings, never thrown away.
        let compoundName = typed.isEmpty && (reconstitution != nil || reminderDose != nil)
            ? String(localized: "My compound") : typed
        let dose = reminderDose
        let rhythm = reminderRhythm
        let time = reminderTime
        let remindersOn = remindersOn

        store.update { journal in
            var seeded = answers
            if !compoundName.isEmpty { seeded.compounds.append(compoundName) }
            seeded.seed(into: &journal, now: Date())
            guard let compound = journal.compounds.first(where: {
                $0.name.caseInsensitiveCompare(compoundName) == .orderedSame
            }) else { return }
            if let factor, compound.iuConversion == nil {
                var updated = compound
                updated.iuConversion = factor
                journal.save(updated)
            }
            if let reconstitution {
                journal.save(Vial(compoundID: compound.id, reconstitution: reconstitution,
                                  syringe: syringe, mixedAt: Date()))
            }
            if let dose {
                let calendar = Calendar.current
                journal.save(Regimen(
                    compoundID: compound.id,
                    dose: dose,
                    schedule: DoseSchedule(pattern: rhythm.pattern, start: Date(), end: nil,
                                           times: [TimeOfDay(hour: calendar.component(.hour, from: time),
                                                             minute: calendar.component(.minute, from: time))]),
                    remindersOn: remindersOn
                ))
            }
        }
        Analytics.track(.onboardingCompleted, [
            "goals": answers.goals.map(\.rawValue).sorted().joined(separator: ","),
            "vial": String(reconstitution != nil),
            "reminders": String(remindersOn),
        ])
    }
}

/// The three rhythms offered during onboarding; every other pattern is in
/// the full schedule editor.
enum ReminderRhythm: CaseIterable {
    case daily, everyOtherDay, weekly

    var pattern: DoseSchedule.Pattern {
        switch self {
        case .daily: return .everyNDays(1)
        case .everyOtherDay: return .everyNDays(2)
        case .weekly: return .everyNDays(7)
        }
    }
}
