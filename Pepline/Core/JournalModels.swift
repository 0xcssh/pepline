import Foundation

/// The unit a dose was typed in. Kept as typed (not normalized to mcg) so the
/// journal and the export show exactly what the user entered.
enum DoseUnit: String, Codable, CaseIterable {
    case mcg
    case mg
    case iu
}

struct DoseAmount: Codable, Hashable {
    var value: Decimal
    var unit: DoseUnit

    /// The mass, or nil for IU without a conversion factor.
    func mass(_ conversion: IUConversion?) -> Mass? {
        switch unit {
        case .mcg: return .mcg(value)
        case .mg: return .mg(value)
        case .iu:
            guard let conversion, conversion.isValid else { return nil }
            return conversion.mass(fromIU: value)
        }
    }
}

struct Compound: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    /// Only for compounds dosed in IU; factor from the user's label.
    var iuConversion: IUConversion?
}

/// A reconstituted vial, saved with the syringe it is drawn with.
struct Vial: Codable, Hashable, Identifiable {
    var id = UUID()
    var compoundID: Compound.ID
    var reconstitution: Reconstitution
    var syringe: SyringeModel
    var mixedAt: Date
    var isArchived = false
}

enum InjectionSite: String, Codable, CaseIterable {
    case abdomen
    case thigh
    case glute
    case arm
}

enum BodySide: String, Codable, CaseIterable {
    case left
    case right
}

struct DoseEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var compoundID: Compound.ID
    /// The vial it was drawn from, so the vial's remaining amount follows.
    var vialID: Vial.ID?
    var amount: DoseAmount
    var site: InjectionSite?
    var side: BodySide?
    var notes = ""
}

/// A compound's schedule as the user's prescriber set it. Pepline stores and
/// reminds; it never suggests the dose or the schedule.
struct Regimen: Codable, Hashable, Identifiable {
    var id = UUID()
    var compoundID: Compound.ID
    var dose: DoseAmount
    var schedule: DoseSchedule
    var remindersOn = true
    /// Days before the vial runs out to remind about reordering; nil = off.
    var reorderLeadDays: Int? = 7
}

struct WeightEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    /// Stored in kilograms; displayed in the user's unit by the UI.
    var kilograms: Decimal
}
