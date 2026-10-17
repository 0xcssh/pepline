import Foundation
import WidgetKit

/// Keeps the next-dose widget in step with the journal: writes the upcoming
/// doses to the App Group and asks WidgetKit to reload when they changed.
enum WidgetBridge {
    static func publish(_ journal: Journal, now: Date = Date()) {
        let doses = Adherence.upcoming(in: journal, now: now, calendar: .current).compactMap { scheduled -> WidgetSnapshot.Dose? in
            guard let regimen = journal.regimens.first(where: { $0.id == scheduled.regimenID }) else { return nil }
            let units = NotificationScheduler.unitsToDraw(regimen, in: journal).map { Fmt.number($0, digits: 1) }
            return WidgetSnapshot.Dose(date: scheduled.date,
                                       compound: journal.compound(regimen.compoundID)?.name ?? "",
                                       dose: Fmt.dose(regimen.dose),
                                       units: units)
        }
        let snapshot = WidgetSnapshot(doses: doses)
        guard snapshot != WidgetSnapshot.read() else { return }
        snapshot.write()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
