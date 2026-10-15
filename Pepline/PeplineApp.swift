import SwiftUI

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
                    PLColor.background.ignoresSafeArea()
                } else {
                    // Hard paywall; the 7-day free trial is the way in.
                    PaywallView()
                }
            }
            .environmentObject(DataStore.shared)
            .tint(PLColor.navy)
            // Light-only in v1, like RepLock: the navy palette is not
            // designed for dark mode yet.
            .preferredColorScheme(.light)
            .task { await AppleAccount.shared.checkCredentialState() }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                let journal = DataStore.shared.journal
                // Counts only: never names, doses or dates.
                Analytics.track(.appForegrounded, [
                    "doses": String(journal.doses.count),
                    "vials": String(journal.vials.count),
                    "regimens": String(journal.regimens.count),
                    "pro": String(subscription.isPro),
                ])
                // The reminder window rolls forward: refill it on every return.
                NotificationScheduler.shared.replan(journal)
                // Re-read the entitlement: the user may have cancelled or
                // resubscribed in Apple's settings.
                Task { await subscription.refresh() }
            }
        }
    }
}
