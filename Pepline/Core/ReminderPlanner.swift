import Foundation

struct PlannedReminder: Hashable {
    enum Kind: Hashable {
        case dose(Regimen.ID)
        case reorder(Vial.ID)
    }

    /// Stable across replans, so rescheduling replaces instead of duplicating.
    var id: String
    var kind: Kind
    var date: Date
}

/// Which local notifications to have pending right now. iOS keeps at most 64
/// pending requests per app and silently drops the rest, so this is a rolling
/// window: the soonest reminders, recomputed on launch, on foreground and
/// after every edit.
enum ReminderPlanner {
    /// Under the 64-request cap, with room to spare.
    static let maxPending = 60

    static func plan(_ journal: Journal, now: Date, calendar: Calendar,
                     limit: Int = ReminderPlanner.maxPending) -> [PlannedReminder] {
        var reminders: [PlannedReminder] = []

        for regimen in journal.regimens where regimen.remindersOn {
            for date in regimen.schedule.nextOccurrences(after: now, count: limit, calendar: calendar) {
                reminders.append(PlannedReminder(
                    id: "dose.\(regimen.id.uuidString).\(Int(date.timeIntervalSince1970))",
                    kind: .dose(regimen.id),
                    date: date
                ))
            }
            if let reorder = reorderReminder(for: regimen, in: journal, now: now, calendar: calendar) {
                reminders.append(reorder)
            }
        }

        return Array(reminders.sorted { ($0.date, $0.id) < ($1.date, $1.id) }.prefix(limit))
    }

    /// "Reorder" reminder for the compound's current vial: lead days before
    /// the first dose it can no longer cover. None if already due.
    private static func reorderReminder(for regimen: Regimen, in journal: Journal,
                                        now: Date, calendar: Calendar) -> PlannedReminder? {
        guard let leadDays = regimen.reorderLeadDays,
              let vial = journal.vials
                  .filter({ $0.compoundID == regimen.compoundID && !$0.isArchived })
                  .max(by: { $0.mixedAt < $1.mixedAt }),
              let dose = regimen.dose.mass(journal.compound(regimen.compoundID)?.iuConversion),
              let runOut = VialForecast.runOutDate(remaining: journal.remaining(in: vial), dose: dose,
                                                   schedule: regimen.schedule, after: now, calendar: calendar)
        else { return nil }

        let date = VialForecast.reorderDate(runOut: runOut, leadDays: leadDays, now: now, calendar: calendar)
        guard date > now else { return nil }
        return PlannedReminder(id: "reorder.\(vial.id.uuidString)", kind: .reorder(vial.id), date: date)
    }
}
