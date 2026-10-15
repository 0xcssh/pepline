import Foundation
import UserNotifications

/// Keeps the pending local notifications equal to `ReminderPlanner`'s plan.
/// Called on launch, on foreground and after every journal edit.
final class NotificationScheduler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationScheduler()

    private override init() {
        super.init()
    }

    /// Call once at app launch so taps are delivered even on cold start.
    func setup() {
        UNUserNotificationCenter.current().delegate = self
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
            let name = journal.regimens.first { $0.id == regimenID }
                .flatMap { journal.compound($0.compoundID)?.name } ?? ""
            content.body = String(localized: "Scheduled dose: \(name)")
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
}
