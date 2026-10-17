import Foundation

/// The figures above the weight chart (Shotsy's "Results" header).
struct WeightStats: Equatable {
    var startKg: Decimal
    var latestKg: Decimal
    /// latest − start (negative when weight went down).
    var changeKg: Decimal
    /// change ÷ start × 100.
    var changePercent: Decimal
    /// latest − goal; nil without a goal.
    var toGoalKg: Decimal?
    /// change per week over the logged span; nil under one day of data.
    var weeklyChangeKg: Decimal?

    static func compute(_ weights: [WeightEntry], goalKg: Decimal?) -> WeightStats? {
        let sorted = weights.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, first.kilograms > 0 else { return nil }
        let change = last.kilograms - first.kilograms
        let days = last.date.timeIntervalSince(first.date) / 86_400
        return WeightStats(
            startKg: first.kilograms,
            latestKg: last.kilograms,
            changeKg: change,
            changePercent: (change / first.kilograms * 100).rounded(1),
            toGoalKg: goalKg.map { last.kilograms - $0 },
            weeklyChangeKg: days >= 1 ? (change / Decimal(days) * 7).rounded(2) : nil
        )
    }

    /// The dose of `compoundID` in force at `date`: the last one logged at or
    /// before it. Used to colour the weight line by dose, like Shotsy.
    static func activeDose(at date: Date, compoundID: Compound.ID, in journal: Journal) -> DoseAmount? {
        journal.doses
            .filter { $0.compoundID == compoundID && $0.date <= date }
            .max { $0.date < $1.date }?
            .amount
    }
}
