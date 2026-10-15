import Foundation
import TelemetryDeck

/// Product analytics through TelemetryDeck: anonymous counts only, no user
/// identifier, no ATT prompt, nothing that could be linked to a person.
/// Every event goes through this wrapper so the SDK is referenced in exactly
/// one file and the event vocabulary lives in one place.
///
/// Health data never leaves the device: no compound names, doses, dates,
/// sites or weights in any parameter — only counts and app-defined enums.
/// App Store privacy answers: "Product Interaction", not linked to identity,
/// not used for tracking (mirrored in PrivacyInfo.xcprivacy).
enum Analytics {
    /// TelemetryDeck App ID. Like the RevenueCat public key, it ships in the
    /// binary by design: it only allows sending.
    static let appID = "CAA9F19C-A911-46FE-B97A-AB0EB9E70748"

    /// Call once, as early as possible in the app's life.
    static func configure() {
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
    }

    static func track(_ event: Event, _ parameters: [String: String] = [:]) {
        TelemetryDeck.signal(event.rawValue, parameters: parameters)
    }

    /// The whole event vocabulary. Dotted names group in the dashboard.
    enum Event: String {
        // Lifecycle
        case appLaunched = "App.launched"
        case appForegrounded = "App.foregrounded"   // doses, vials, regimens (counts)

        // Core loop
        case calculatorResult = "Calculator.result"  // syringe, doseUnit, warnings (count)
        case ambiguousInputResolved = "Calculator.ambiguousResolved"
        case vialSaved = "Vial.saved"
        case doseLogged = "Dose.logged"              // isNew, fromSchedule, hasSite
        case doseDeleted = "Dose.deleted"
        case regimenSaved = "Regimen.saved"          // pattern, times (count), reminders, reorder
        case weightLogged = "Weight.logged"
        case exported = "Export.done"                // kind: doses|weight
        case notificationPermission = "Permission.notifications" // result: granted|denied

        // Onboarding funnel: one signal per step shown, then completion.
        case onboardingStep = "Onboarding.step"      // index (zero-padded), step
        case onboardingCompleted = "Onboarding.completed" // goals, experience (enum names only)
        case reviewRequested = "Review.requested"    // where

        // Monetization
        case paywallShown = "Paywall.shown"          // kind: main|exitOffer
        case purchaseStarted = "Purchase.started"    // plan
        case purchaseResult = "Purchase.result"      // plan, result: success|cancelled|failed|noProduct|notEntitled
        case restoreResult = "Purchase.restore"      // result
        case exitOfferDismissed = "ExitOffer.dismissed"

        // Account
        case appleSignIn = "Account.signIn"          // result: success|cancelled|failed
        case accountDeleted = "Account.deleted"      // result, erasedJournal
    }
}
