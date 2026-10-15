import Foundation

/// Mass units a vial or a dose can be typed in. IU is not a mass: it needs a
/// compound-specific factor, see `IUConversion`.
enum MassUnit: String, Codable, CaseIterable {
    case mg
    case mcg

    /// Micrograms in one of this unit.
    var mcgFactor: Decimal { self == .mg ? 1000 : 1 }
}

/// An amount of compound, stored in micrograms as a `Decimal` so that typed
/// values like 0.3 mg stay exact (Double would turn 0.1 + 0.2 into
/// 0.30000000000000004 — the kind of wrong result competitors ship).
struct Mass: Codable, Hashable, Comparable {
    private(set) var mcg: Decimal

    init(_ value: Decimal, _ unit: MassUnit) {
        mcg = value * unit.mcgFactor
    }

    static func mg(_ value: Decimal) -> Mass { Mass(value, .mg) }
    static func mcg(_ value: Decimal) -> Mass { Mass(value, .mcg) }
    static let zero = Mass(0, .mcg)

    func value(in unit: MassUnit) -> Decimal { mcg / unit.mcgFactor }

    var isPositive: Bool { mcg > 0 }

    static func < (lhs: Mass, rhs: Mass) -> Bool { lhs.mcg < rhs.mcg }
    static func + (lhs: Mass, rhs: Mass) -> Mass { .mcg(lhs.mcg + rhs.mcg) }
    static func - (lhs: Mass, rhs: Mass) -> Mass { .mcg(lhs.mcg - rhs.mcg) }
    static func * (lhs: Mass, rhs: Decimal) -> Mass { .mcg(lhs.mcg * rhs) }
}

/// IU ↔ mass for compounds dosed in International Units. The factor is
/// compound-specific and comes from the user's label; we only ship presets
/// that are a published standard, never a guess.
struct IUConversion: Codable, Hashable {
    /// International Units in one milligram.
    var iuPerMg: Decimal

    /// Somatropin (HGH): 1 mg anhydrous = 3.0 IU (Ph. Eur., USP).
    /// Source: docs/SOURCES.md § IU conversion.
    static let somatropin = IUConversion(iuPerMg: 3)

    var isValid: Bool { iuPerMg > 0 }

    func mass(fromIU iu: Decimal) -> Mass { .mg(iu / iuPerMg) }
    func iu(of mass: Mass) -> Decimal { mass.value(in: .mg) * iuPerMg }
}

extension Decimal {
    /// `scale` digits after the decimal point; `.plain` rounds half up.
    func rounded(_ scale: Int = 0, _ mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, scale, mode)
        return result
    }

    var intValue: Int { NSDecimalNumber(decimal: self).intValue }
}
