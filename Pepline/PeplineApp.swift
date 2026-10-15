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
            // Placeholder until the calculator UI lands (build plan step 3).
            Text(verbatim: "Pepline")
                .plNumeral(size: 44)
                .foregroundStyle(PLColor.navy)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(PLColor.background)
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
