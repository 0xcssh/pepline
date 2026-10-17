import Foundation
import UserNotifications

/// Keeps the pending local notifications equal to `ReminderPlanner`'s plan.
/// Called on launch, on foreground and after every journal edit.
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private override init() {
        super.init()
    }

    static let doseCategory = "DOSE"
    static let logAction = "LOG"
    static let skipAction = "SKIP"

    /// Call once at app launch so taps are delivered even on cold start.
    /// Dose reminders carry two actions, so a dose can be logged or skipped
    /// from the notification without opening the app.
    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let log = UNNotificationAction(identifier: Self.logAction, title: String(localized: "Log dose"),
                                       options: [], icon: UNNotificationActionIcon(systemImageName: "checkmark.circle"))
        let skip = UNNotificationAction(identifier: Self.skipAction, title: String(localized: "Skip"),
                                        options: [], icon: UNNotificationActionIcon(systemImageName: "forward"))
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.doseCategory, actions: [log, skip], intentIdentifiers: []),
        ])
    }

    func requestPermission() async -> Bool {
        let granted = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    func replan(_ journal: Journal) {
        let plan = ReminderPlanner.plan(journal, now: Date(), calendar: .current)
        let center = UNUserNotificationCenter.current()
        Task {
            let pending = await center.pendingNotificationRequests().map(\.identifier)
            let wanted = Set(plan.map(\.id))
            center.removePendingNotificationRequests(withIdentifiers: pending.filter {
                !wanted.contains($0) && $0 != Self.trialReminderID
            })
            for reminder in plan where !pending.contains(reminder.id) {
                try? await center.add(request(for: reminder, in: journal))
            }
        }
    }

    /// Two days before a free trial ends (the paywall's timeline promises it).
    /// Its ID is outside ReminderPlanner's, so replans leave it alone.
    func scheduleTrialReminder(trialDays: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Pepline"
        content.body = String(localized: "Your free trial ends in 2 days. Cancel anytime in your App Store settings if Pepline is not for you.")
        content.sound = .default
        let delay = TimeInterval(max(trialDays - 2, 1)) * 86_400
        UNUserNotificationCenter.current().add(UNNotificationRequest(
            identifier: Self.trialReminderID,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        ))
    }

    static let trialReminderID = "trialEnds"

    private func request(for reminder: PlannedReminder, in journal: Journal) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "Pepline"
        content.sound = .default
        switch reminder.kind {
        case .dose(let regimenID):
            let regimen = journal.regimens.first { $0.id == regimenID }
            let name = regimen.flatMap { journal.compound($0.compoundID)?.name } ?? ""
            // "Scheduled dose: Semaglutide · 0.25 mg · draw to 10 units"
            var body = String(localized: "Scheduled dose: \(name)")
            if let regimen {
                body += " · " + Fmt.dose(regimen.dose)
                if let units = Self.unitsToDraw(regimen, in: journal) {
                    body += " · " + String(localized: "Draw to \(Fmt.number(units)) units")
                }
            }
            content.body = body
            content.categoryIdentifier = Self.doseCategory
            content.userInfo = ["regimenID": regimenID.uuidString, "scheduledAt": reminder.date.timeIntervalSince1970]
        case .reorder(let vialID):
            let name = journal.vials.first { $0.id == vialID }
                .flatMap { journal.compound($0.compoundID)?.name } ?? ""
            content.body = String(localized: "Your \(name) vial is running low — time to reorder.")
        }
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date)
        return UNNotificationRequest(
            identifier: reminder.id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    /// "Log dose" writes the regimen's dose now (from its newest vial);
    /// "Skip" records the scheduled dose as skipped.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let idString = info["regimenID"] as? String, let regimenID = UUID(uuidString: idString),
              let scheduledAt = (info["scheduledAt"] as? TimeInterval).map(Date.init(timeIntervalSince1970:))
        else { return }
        let action = response.actionIdentifier
        guard action == Self.logAction || action == Self.skipAction else { return }
        await MainActor.run {
            let store = DataStore.shared
            guard let regimen = store.journal.regimens.first(where: { $0.id == regimenID }) else { return }
            if action == Self.logAction {
                let vialID = store.journal.vials
                    .filter { $0.compoundID == regimen.compoundID && !$0.isArchived }
                    .max { $0.mixedAt < $1.mixedAt }?.id
                store.update {
                    $0.save(DoseEntry(date: Date(), compoundID: regimen.compoundID, vialID: vialID, amount: regimen.dose))
                }
                Analytics.track(.doseLogged, ["isNew": "true", "hasSite": "false", "from": "notification"])
            } else {
                store.update { $0.save(SkippedDose(regimenID: regimenID, scheduledAt: scheduledAt)) }
                Analytics.track(.doseSkipped, ["from": "notification"])
            }
        }
    }

    /// Units to draw for the regimen's dose from its newest active vial.
    static func unitsToDraw(_ regimen: Regimen, in journal: Journal) -> Decimal? {
        guard let vial = journal.vials.filter({ $0.compoundID == regimen.compoundID && !$0.isArchived })
                .max(by: { $0.mixedAt < $1.mixedAt }),
              let dose = regimen.dose.mass(journal.compound(regimen.compoundID)?.iuConversion),
              let draw = try? vial.reconstitution.draw(dose, with: vial.syringe)
        else { return nil }
        return draw.units
    }
}
