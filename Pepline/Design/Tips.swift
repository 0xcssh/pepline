import SwiftUI
import TipKit

// Features taught in the moment, where they are used, instead of a tour in
// the onboarding (SOSA 2026 p116: users adopt features far more when coached
// during the action). TipKit shows each one once and never again.

struct InjectTip: Tip {
    var title: Text { Text("Log in one tap") }
    var message: Text? { Text("Right after your injection, tap I injected: Pepline saves the dose, the vial and a rested site. You can edit it afterwards.") }
    var image: Image? { Image(systemName: "hand.tap.fill") }
}

struct CalendarTip: Tip {
    var title: Text { Text("Your days at a glance") }
    var message: Text? { Text("Tap a day to see, edit or add its doses and side effects.") }
    var image: Image? { Image(systemName: "calendar") }
}

struct SaveVialTip: Tip {
    var title: Text { Text("Save this vial") }
    var message: Text? { Text("Today will then show the units to draw for every dose, and warn you before it runs out.") }
    var image: Image? { Image(systemName: "tray.and.arrow.down.fill") }
}

struct NutritionTip: Tip {
    var title: Text { Text("Protein and water first") }
    var message: Text? { Text("On a GLP-1, these are the two to watch. Tap + to add a meal by search, barcode or photo.") }
    var image: Image? { Image(systemName: "drop.fill") }
}
