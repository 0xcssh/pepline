import Foundation

/// Insulin syringes sold for peptides. All are U-100: 100 units per ml.
enum Syringe: String, Codable, CaseIterable {
    case ml03
    case ml05
    case ml10

    static let unitsPerMl: Decimal = 100

    var capacityMl: Decimal {
        switch self {
        case .ml03: return Decimal(3) / 10
        case .ml05: return Decimal(5) / 10
        case .ml10: return 1
        }
    }

    var capacityUnits: Decimal { capacityMl * Syringe.unitsPerMl }

    /// Smallest graduation printed on the barrel, in units: 1 on the 0.3 and
    /// 0.5 ml barrels, 2 on the 1 ml barrel.
    var tickUnits: Decimal { self == .ml10 ? 2 : 1 }
}

enum ReconstitutionError: Error, Equatable {
    case vialNotPositive
    case waterNotPositive
    case doseNotPositive
}

/// Things the user must see next to the result. Facts about the math and the
/// syringe — never a judgement on the dose itself (no dosing advice).
enum DrawWarning: Hashable {
    /// The volume does not fit in one syringe; `draws` fills are needed.
    case exceedsSyringe(draws: Int)
    /// The volume is under the smallest graduation and cannot be measured.
    case belowSmallestMark
    /// The dose is more than the whole vial.
    case doseExceedsVial
}

/// A vial of powder mixed with bacteriostatic water. Saved per vial.
struct Reconstitution: Codable, Hashable {
    var vial: Mass
    var waterMl: Decimal

    init(vial: Mass, waterMl: Decimal) throws {
        guard vial.isPositive else { throw ReconstitutionError.vialNotPositive }
        guard waterMl > 0 else { throw ReconstitutionError.waterNotPositive }
        self.vial = vial
        self.waterMl = waterMl
    }

    /// Concentration in micrograms per ml.
    var mcgPerMl: Decimal { vial.mcg / waterMl }

    /// Micrograms in one syringe unit (0.01 ml).
    var mcgPerUnit: Decimal { mcgPerMl / Syringe.unitsPerMl }

    func draw(_ dose: Mass, with syringe: Syringe) throws -> Draw {
        guard dose.isPositive else { throw ReconstitutionError.doseNotPositive }
        // dose × water ÷ vial, multiplied before dividing so that a 5 mg / 3 ml
        // vial gives exactly 0.3 ml for 500 mcg (no 1.666… intermediate).
        let volumeMl = dose.mcg * waterMl / vial.mcg
        let units = volumeMl * Syringe.unitsPerMl
        let nearestMark = (units / syringe.tickUnits).rounded() * syringe.tickUnits

        var warnings: Set<DrawWarning> = []
        if units > syringe.capacityUnits {
            let draws = (units / syringe.capacityUnits).rounded(0, .up).intValue
            warnings.insert(.exceedsSyringe(draws: draws))
        }
        if units < syringe.tickUnits {
            warnings.insert(.belowSmallestMark)
        }
        if dose > vial {
            warnings.insert(.doseExceedsVial)
        }

        return Draw(
            volumeMl: volumeMl,
            units: units,
            nearestMarkUnits: nearestMark,
            fullDosesPerVial: (vial.mcg / dose.mcg).rounded(0, .down).intValue,
            warnings: warnings
        )
    }
}

/// What to pull into the syringe for one dose.
struct Draw: Hashable {
    var volumeMl: Decimal
    /// Exact units; the UI rounds for display.
    var units: Decimal
    /// Closest graduation on the chosen barrel.
    var nearestMarkUnits: Decimal
    var fullDosesPerVial: Int
    var warnings: Set<DrawWarning>
}
