import Foundation

/// A U-100 insulin syringe as printed on the box: barrel size and smallest
/// graduation. The graduation depends on the product, not only on the size
/// (a 0.3 ml barrel comes in 1-unit and half-unit versions), so it is chosen
/// by the user and saved with each vial.
struct SyringeModel: Codable, Hashable {
    /// U-100: 100 units per ml, 1 unit = 0.01 ml.
    /// Source: docs/SOURCES.md § Syringe math (ISO 8537, FDA 2024 alert).
    static let unitsPerMl: Decimal = 100

    var capacityMl: Decimal
    /// Smallest graduation printed on the barrel, in units.
    var tickUnits: Decimal

    var capacityUnits: Decimal { capacityMl * SyringeModel.unitsPerMl }

    // Graduations sold for each barrel (ISO 8537 legacy increments).
    // Source: docs/SOURCES.md § Syringe math.
    static let ml03HalfUnit = SyringeModel(capacityMl: Decimal(3) / 10, tickUnits: Decimal(5) / 10)
    static let ml03 = SyringeModel(capacityMl: Decimal(3) / 10, tickUnits: 1)
    static let ml05 = SyringeModel(capacityMl: Decimal(5) / 10, tickUnits: 1)
    static let ml10 = SyringeModel(capacityMl: 1, tickUnits: 1)
    static let ml10TwoUnit = SyringeModel(capacityMl: 1, tickUnits: 2)

    static let presets: [SyringeModel] = [.ml03HalfUnit, .ml03, .ml05, .ml10, .ml10TwoUnit]
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
    /// The volume is under a tenth of the barrel: easy to misread by a factor
    /// of ten (FDA 2024: 5 units drawn as 50 on a 1 ml syringe).
    /// Source: docs/SOURCES.md § Why exact math and unit clarity matter.
    case smallFractionOfBarrel
    /// The dose is more than the whole vial.
    case doseExceedsVial
}

/// A vial of powder mixed with bacteriostatic water. Saved per vial.
struct Reconstitution: Codable, Hashable {
    private(set) var vial: Mass
    private(set) var waterMl: Decimal

    init(vial: Mass, waterMl: Decimal) throws {
        guard vial.isPositive else { throw ReconstitutionError.vialNotPositive }
        guard waterMl > 0 else { throw ReconstitutionError.waterNotPositive }
        self.vial = vial
        self.waterMl = waterMl
    }

    private enum CodingKeys: String, CodingKey { case vial, waterMl }

    /// Decoding goes through the same checks: a corrupt file must not give a
    /// zero-water vial and a division by zero.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(vial: container.decode(Mass.self, forKey: .vial),
                      waterMl: container.decode(Decimal.self, forKey: .waterMl))
    }

    /// Concentration in micrograms per ml.
    var mcgPerMl: Decimal { vial.mcg / waterMl }

    /// Micrograms in one syringe unit (0.01 ml).
    var mcgPerUnit: Decimal { mcgPerMl / SyringeModel.unitsPerMl }

    func draw(_ dose: Mass, with syringe: SyringeModel) throws -> Draw {
        guard dose.isPositive else { throw ReconstitutionError.doseNotPositive }
        // dose × water ÷ vial, multiplied before dividing so that a 5 mg / 3 ml
        // vial gives exactly 0.3 ml for 500 mcg (no 1.666… intermediate).
        let volumeMl = dose.mcg * waterMl / vial.mcg
        let units = volumeMl * SyringeModel.unitsPerMl
        let nearestMark = (units / syringe.tickUnits).rounded() * syringe.tickUnits

        var warnings: Set<DrawWarning> = []
        if units > syringe.capacityUnits {
            let draws = (units / syringe.capacityUnits).rounded(0, .up).intValue
            warnings.insert(.exceedsSyringe(draws: draws))
        }
        if units < syringe.tickUnits {
            warnings.insert(.belowSmallestMark)
        }
        if units * 10 < syringe.capacityUnits {
            warnings.insert(.smallFractionOfBarrel)
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
