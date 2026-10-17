import Foundation

/// The one-tap "I injected" of the Today screen: the scheduled dose as the
/// user's prescriber set it, from their newest vial, at the least recently
/// used zone. Everything stays editable afterwards; Pepline suggests a site
/// for rotation, never a dose.
enum QuickLog {
    /// When a scheduled dose is logged: now if it is around its time,
    /// otherwise the slot itself, so a late "Log" still answers that slot.
    static func date(forSlot scheduled: Date, now: Date) -> Date {
        abs(now.timeIntervalSince(scheduled)) <= Adherence.tolerance ? now : scheduled
    }

    static func dose(for regimen: Regimen, in journal: Journal, at date: Date) -> DoseEntry {
        let vial = journal.vials
            .filter { $0.compoundID == regimen.compoundID && !$0.isArchived }
            .max { $0.mixedAt < $1.mixedAt }
        let zone = SiteRotation.leastRecent(lastUse: SiteRotation.lastUse(in: journal))
        return DoseEntry(date: date, compoundID: regimen.compoundID, vialID: vial?.id, amount: regimen.dose,
                         site: zone.site, side: zone.side)
    }
}

/// This week so far, for the recap card on Today (retention through the
/// product, SOSA 2026 p116): doses taken against those due, weight change
/// since the week began, side effects, and the current streak.
struct WeeklyRecap: Equatable {
    var taken = 0
    /// Scheduled doses already due this week (taken, skipped or missed).
    var due = 0
    /// Latest weigh-in this week minus the last one before it; nil without both.
    var weightChangeKg: Decimal?
    var sideEffects = 0
    var streak = 0

    var isEmpty: Bool { due == 0 && taken == 0 && weightChangeKg == nil && sideEffects == 0 }

    static func make(_ journal: Journal, now: Date, calendar: Calendar) -> WeeklyRecap {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let summary = Adherence.summary(Adherence.doses(in: journal, from: start, through: now, now: now, calendar: calendar))
        let history = Adherence.doses(in: journal, from: calendar.date(byAdding: .day, value: -90, to: now)!,
                                      through: now, now: now, calendar: calendar)
        let weights = journal.weightSeries
        let before = weights.last { $0.date < start }
        let latest = weights.last { $0.date >= start && $0.date <= now }
        return WeeklyRecap(
            taken: summary.taken,
            due: summary.taken + summary.skipped + summary.missed,
            weightChangeKg: before.flatMap { before in latest.map { $0.kilograms - before.kilograms } },
            sideEffects: journal.sideEffects.filter { $0.date >= start && $0.date <= now }.count,
            streak: Adherence.streak(history)
        )
    }
}

/// When to ask for an App Store rating with Apple's own prompt (guideline
/// 5.6.1: only the system API, no custom pre-prompt): right after a moment
/// of value — the 3rd logged dose, then a 7-dose streak — once each.
enum ReviewMoment: String, CaseIterable {
    case thirdDose, sevenStreak

    static func due(loggedDoses: Int, streak: Int, alreadyAsked: Set<String>) -> ReviewMoment? {
        if loggedDoses >= 3, !alreadyAsked.contains(thirdDose.rawValue) { return .thirdDose }
        if streak >= 7, !alreadyAsked.contains(sevenStreak.rawValue) { return .sevenStreak }
        return nil
    }
}

/// Why someone leaves, asked once when they open Apple's subscription page
/// from Pepline or when auto-renew is found off. Sent as an enum only.
enum CancelReason: String, CaseIterable, Codable {
    case tooExpensive, stoppedTreatment, missingFeature, hardToUse, otherApp, other
}
