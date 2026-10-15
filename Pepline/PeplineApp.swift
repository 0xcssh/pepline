import SwiftUI

@main
struct PeplineApp: App {
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
    }
}
