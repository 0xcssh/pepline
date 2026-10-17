import Foundation

/// Estimated amount still in the body from the logged doses, assuming each
/// dose is absorbed at once and eliminated with first-order kinetics:
///   amount(t) = Σ doseᵢ · 0.5^((t − tᵢ) / t½)   for every dose taken before t.
/// It is the same kind of "estimated level" curve Shotsy, PeptidePal and
/// Peptide Tracker show, and is labelled as an estimate, never a measurement
/// (App Review 1.4.1 asks to disclose the method: docs/SOURCES.md).
enum MedicationLevel {
    /// mg on board at `date`.
    static func amount(at date: Date, doses: [(date: Date, mg: Double)], halfLifeHours: Double) -> Double {
        guard halfLifeHours > 0 else { return 0 }
        return doses.reduce(0) { total, dose in
            let hours = date.timeIntervalSince(dose.date) / 3600
            guard hours >= 0 else { return total }
            return total + dose.mg * pow(0.5, hours / halfLifeHours)
        }
    }

    /// `points` evenly spaced samples over `from...through`, for a chart.
    static func series(doses: [(date: Date, mg: Double)], halfLifeHours: Double,
                       from: Date, through: Date, points: Int = 120) -> [(date: Date, mg: Double)] {
        guard points > 1, through > from else { return [] }
        let step = through.timeIntervalSince(from) / Double(points - 1)
        return (0..<points).map { index in
            let date = from.addingTimeInterval(step * Double(index))
            return (date, amount(at: date, doses: doses, halfLifeHours: halfLifeHours))
        }
    }
}

extension Journal {
    /// The compound's logged doses in mg, for `MedicationLevel`; doses in IU
    /// without a factor are left out.
    func levelDoses(of compoundID: Compound.ID) -> [(date: Date, mg: Double)] {
        let conversion = compound(compoundID)?.iuConversion
        return doses
            .filter { $0.compoundID == compoundID }
            .compactMap { dose -> (date: Date, mg: Double)? in
                guard let mass = dose.amount.mass(conversion) else { return nil }
                return (date: dose.date, mg: NSDecimalNumber(decimal: mass.value(in: .mg)).doubleValue)
            }
            .sorted { $0.date < $1.date }
    }
}
