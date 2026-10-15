import SwiftUI

@main
struct PeplineApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Register the notification delegate before any tap can arrive.
        NotificationScheduler.shared.setup()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(DataStore.shared)
                .tint(PLColor.navy)
                // Light-only in v1, like RepLock: the navy palette is not
                // designed for dark mode yet.
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) {
            // The reminder window rolls forward: refill it on every return.
            if scenePhase == .active {
                NotificationScheduler.shared.replan(DataStore.shared.journal)
            }
        }
    }
}
