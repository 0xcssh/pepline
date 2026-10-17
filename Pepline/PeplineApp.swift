import SwiftUI
import TipKit

@main
struct PeplineApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboardingDone") private var onboardingDone = false
    @ObservedObject private var subscription = SubscriptionManager.shared

    init() {
        Analytics.configure()
        Analytics.track(.appLaunched)
        // Register the notification delegate before any tap can arrive.
        NotificationScheduler.shared.setup()
        // In-context tips (Design/Tips.swift), each shown once.
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !onboardingDone {
                    OnboardingView()
                } else if subscription.isPro {
                    RootView()
                } else if !subscription.entitlementChecked {
                    // Cold start before the entitlement is read: a blank
                    // screen instead of flashing the paywall at a subscriber.
                    PLBackground()
                } else {
                    // Hard paywall; the 7-day free trial is the way in.
                    PaywallView()
                }
            }
            .environmentObject(DataStore.shared)
            .tint(PLColor.accent)
            // V2 design: rounded type everywhere; colors follow the system's
            // light or dark setting (Design/Theme.swift).
            .fontDesign(.rounded)
            .task { await AppleAccount.shared.checkCredentialState() }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                let journal = DataStore.shared.journal
                // Counts only: never names, doses or dates.
                Analytics.track(.appForegrounded, [
                    "doses": String(journal.doses.count),
                    "vials": String(journal.vials.count),
                    "regimens": String(journal.activeRegimens.count),
                    "pro": String(subscription.isPro),
                ])
                // The reminder window rolls forward: refill it on every return.
                NotificationScheduler.shared.replan(journal)
                // An overdue dose drops off the widget; the time zone may have changed.
                WidgetBridge.publish(journal)
                // Re-read the entitlement: the user may have cancelled or
                // resubscribed in Apple's settings.
                Task { await subscription.refresh() }
            }
        }
    }
}
