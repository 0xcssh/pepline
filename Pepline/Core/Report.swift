import Foundation

/// The facts of a doctor report over a period, from the journal only: what
/// was logged, scheduled doses taken or not, weight change, side effects.
/// No interpretation; the PDF lays these out (Features/Report).
struct ReportData {
    struct RegimenLine {
        var regimen: Regimen
        var compoundName: String
        var adherence: AdherenceSummary
    }

    struct SymptomLine: Equatable {
        var symptom: SideEffectEntry.Symptom
        var count: Int
        /// Mean severity 1…5, one decimal.
        var averageSeverity: Decimal
    }

    var from: Date
    var through: Date
    var regimens: [RegimenLine]
    /// Logged doses in the period, oldest first.
    var doses: [DoseEntry]
    var weights: [WeightEntry]
    /// Last minus first weight of the period; nil under two weigh-ins.
    var weightChangeKg: Decimal?
    var symptoms: [SymptomLine]
    /// Every side effect in the period, oldest first.
    var sideEffects: [SideEffectEntry]

    static func make(_ journal: Journal, from: Date, through: Date, now: Date, calendar: Calendar) -> ReportData {
        let inPeriod = { (date: Date) in date >= from && date <= through }
        let regimens = journal.regimens.map { regimen in
            RegimenLine(regimen: regimen,
                        compoundName: journal.compound(regimen.compoundID)?.name ?? "",
                        adherence: Adherence.summary(Adherence.doses(of: regimen, in: journal, from: from, through: through,
                                                                     now: now, calendar: calendar)))
        }
        let weights = journal.weightSeries.filter { inPeriod($0.date) }
        let effects = journal.sideEffects.filter { inPeriod($0.date) }.sorted { $0.date < $1.date }
        let symptoms = Dictionary(grouping: effects, by: \.symptom)
            .map { symptom, entries in
                SymptomLine(symptom: symptom, count: entries.count,
                            averageSeverity: (Decimal(entries.map(\.severity).reduce(0, +)) / Decimal(entries.count)).rounded(1))
            }
            .sorted { ($0.count, $1.symptom.rawValue) > ($1.count, $0.symptom.rawValue) }
        return ReportData(
            from: from, through: through, regimens: regimens,
            doses: journal.doses.filter { inPeriod($0.date) }.sorted { $0.date < $1.date },
            weights: weights,
            weightChangeKg: weights.count >= 2 ? weights[weights.count - 1].kilograms - weights[0].kilograms : nil,
            symptoms: symptoms,
            sideEffects: effects
        )
    }
}
