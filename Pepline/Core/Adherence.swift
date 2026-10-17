import Foundation

/// Taken / skipped / missed / upcoming for every scheduled dose, as the
/// calendars of PeptidePal and Peptide Tracker show it.
struct ScheduledDose: Hashable {
    enum Status: Hashable {
        case taken(DoseEntry.ID)
        case skipped(SkippedDose.ID)
        case missed
        case upcoming
    }

    var regimenID: Regimen.ID
    var date: Date
    var status: Status
}

struct AdherenceSummary: Equatable {
    var taken = 0
    var skipped = 0
    var missed = 0

    /// Taken among the doses that are due (skipped counts against, so a
    /// streak of skips is visible); nil when nothing was due yet.
    var rate: Double? {
        let due = taken + skipped + missed
        return due == 0 ? nil : Double(taken) / Double(due)
    }
}

enum Adherence {
    /// A logged dose counts for a scheduled one when it is this close.
    static let tolerance: TimeInterval = 12 * 3600

    /// Every scheduled dose of `regimen` in `from...through`, matched to the
    /// journal. Each logged dose answers at most one scheduled dose: the
    /// nearest one within the tolerance.
    static func doses(of regimen: Regimen, in journal: Journal, from: Date, through: Date,
                      now: Date, calendar: Calendar) -> [ScheduledDose] {
        // Nothing is due before the schedule existed: a schedule created at
        // 21:00 does not owe that morning's 08:00 dose.
        let scheduled = regimen.schedule.occurrences(from: from, through: through, calendar: calendar)
            .filter { $0 >= regimen.schedule.start }
        let skips = journal.skippedDoses.filter { $0.regimenID == regimen.id }

        // Each logged dose goes to its nearest scheduled dose (within the
        // tolerance); a scheduled dose keeps the first one assigned to it.
        var takenBy: [Date: DoseEntry.ID] = [:]
        for dose in journal.doses.filter({ $0.compoundID == regimen.compoundID }).sorted(by: { $0.date < $1.date }) {
            let nearest = scheduled
                .filter { abs(dose.date.timeIntervalSince($0)) <= tolerance }
                .min { abs(dose.date.timeIntervalSince($0)) < abs(dose.date.timeIntervalSince($1)) }
            if let nearest, takenBy[nearest] == nil { takenBy[nearest] = dose.id }
        }

        // A dose logged for a slot wins over a skip tapped by mistake.
        return scheduled.map { date in
            if let doseID = takenBy[date] {
                return ScheduledDose(regimenID: regimen.id, date: date, status: .taken(doseID))
            }
            if let skip = skips.first(where: { $0.scheduledAt == date }) {
                return ScheduledDose(regimenID: regimen.id, date: date, status: .skipped(skip.id))
            }
            return ScheduledDose(regimenID: regimen.id, date: date,
                                 status: date.addingTimeInterval(tolerance) < now ? .missed : .upcoming)
        }
    }

    /// Every regimen's scheduled doses in the range, in time order.
    static func doses(in journal: Journal, from: Date, through: Date, now: Date, calendar: Calendar) -> [ScheduledDose] {
        journal.regimens
            .flatMap { doses(of: $0, in: journal, from: from, through: through, now: now, calendar: calendar) }
            .sorted { $0.date < $1.date }
    }

    /// The next doses still to take (neither logged nor skipped), starting
    /// with one due up to `tolerance` ago, for the next-dose widget.
    static func upcoming(in journal: Journal, now: Date, calendar: Calendar,
                         horizonDays: Int = 35, limit: Int = 12) -> [ScheduledDose] {
        let through = calendar.date(byAdding: .day, value: horizonDays, to: now)!
        let all = doses(in: journal, from: now.addingTimeInterval(-tolerance), through: through, now: now, calendar: calendar)
        return Array(all.filter { $0.status == .upcoming }.prefix(limit))
    }

    /// Whether the slot at `scheduledAt` was already logged or skipped, so a
    /// late tap on its notification does not log it twice.
    static func isAnswered(_ regimen: Regimen, at scheduledAt: Date, in journal: Journal, calendar: Calendar) -> Bool {
        doses(of: regimen, in: journal, from: scheduledAt.addingTimeInterval(-tolerance),
              through: scheduledAt.addingTimeInterval(tolerance), now: scheduledAt, calendar: calendar)
            .contains { $0.date == scheduledAt && $0.status != .upcoming && $0.status != .missed }
    }

    static func summary(_ doses: [ScheduledDose]) -> AdherenceSummary {
        doses.reduce(into: AdherenceSummary()) { summary, dose in
            switch dose.status {
            case .taken: summary.taken += 1
            case .skipped: summary.skipped += 1
            case .missed: summary.missed += 1
            case .upcoming: break
            }
        }
    }

    /// Consecutive taken doses, counting back from the most recent due one.
    static func streak(_ doses: [ScheduledDose]) -> Int {
        var count = 0
        for dose in doses.sorted(by: { $0.date > $1.date }) {
            switch dose.status {
            case .upcoming: continue
            case .taken: count += 1
            case .skipped, .missed: return count
            }
        }
        return count
    }
}
