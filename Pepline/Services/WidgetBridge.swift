import Foundation
import WidgetKit

/// Keeps the next-dose widget in step with the journal: writes the upcoming
/// doses to the shared keychain group and asks WidgetKit to reload when
/// they changed.
enum WidgetBridge {
    static func publish(_ journal: Journal, now: Date = Date()) {
        // About a month of doses, so the widget keeps going when the app is
        // not opened for days.
        let doses = Adherence.upcoming(in: journal, now: now, calendar: .current, limit: 60).compactMap { scheduled -> WidgetSnapshot.Dose? in
            guard let regimen = journal.regimens.first(where: { $0.id == scheduled.regimenID }) else { return nil }
            let units = NotificationScheduler.unitsToDraw(regimen, in: journal).map(Fmt.units)
            return WidgetSnapshot.Dose(date: scheduled.date,
                                       compound: journal.compound(regimen.compoundID)?.name ?? "",
                                       dose: Fmt.dose(regimen.dose),
                                       units: units)
        }
        let snapshot = WidgetSnapshot(doses: doses, hasSchedules: !journal.activeRegimens.isEmpty)
        guard snapshot != WidgetSnapshot.read() else { return }
        snapshot.write()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
