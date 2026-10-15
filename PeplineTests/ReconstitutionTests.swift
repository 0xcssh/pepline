import XCTest
@testable import Pepline

/// Exact decimal from a literal — `Decimal(0.3)` goes through Double and is not exact.
func d(_ text: String) -> Decimal {
    Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
}

final class ReconstitutionTests: XCTestCase {
    // MARK: Mass and units

    func testMassStoresMicrograms() {
        XCTAssertEqual(Mass.mg(5).mcg, 5000)
        XCTAssertEqual(Mass.mcg(250).value(in: .mg), d("0.25"))
        XCTAssertEqual(Mass(d("0.3"), .mg), .mcg(300))
    }

    func testDecimalMassAddsExactly() {
        // The Double trap: 0.1 + 0.2 != 0.3.
        XCTAssertEqual(Mass.mg(d("0.1")) + .mg(d("0.2")), .mg(d("0.3")))
        XCTAssertEqual(Mass.mg(1) - .mcg(250), .mcg(750))
        XCTAssertEqual(Mass.mcg(250) * 4, .mg(1))
        XCTAssertTrue(Mass.mcg(999) < .mg(1))
        XCTAssertFalse(Mass.zero.isPositive)
    }

    func testIUConversion() {
        let hgh = IUConversion.somatropin
        XCTAssertTrue(hgh.isValid)
        XCTAssertEqual(hgh.mass(fromIU: 6), .mg(2))
        XCTAssertEqual(hgh.iu(of: .mg(4)), 12)
        XCTAssertEqual(hgh.iu(of: .mcg(500)), d("1.5"))
        XCTAssertFalse(IUConversion(iuPerMg: 0).isValid)
    }

    func testRounding() {
        XCTAssertEqual(d("2.5").rounded(), 3)
        XCTAssertEqual(d("2.49").rounded(), 2)
        XCTAssertEqual(d("16.67").rounded(0, .down), 16)
        XCTAssertEqual(d("1.01").rounded(0, .up), 2)
        XCTAssertEqual(d("3.14159").rounded(2), d("3.14"))
        XCTAssertEqual(d("16").intValue, 16)
    }

    // MARK: Syringes

    func testSyringeCapacities() {
        XCTAssertEqual(Syringe.ml03.capacityMl, d("0.3"))
        XCTAssertEqual(Syringe.ml03.capacityUnits, 30)
        XCTAssertEqual(Syringe.ml05.capacityUnits, 50)
        XCTAssertEqual(Syringe.ml10.capacityUnits, 100)
        XCTAssertEqual(Syringe.ml03.tickUnits, 1)
        XCTAssertEqual(Syringe.ml05.tickUnits, 1)
        XCTAssertEqual(Syringe.ml10.tickUnits, 2)
    }

    // MARK: Concentration

    func testConcentration() throws {
        let vial = try Reconstitution(vial: .mg(5), waterMl: 2)
        XCTAssertEqual(vial.mcgPerMl, 2500)
        XCTAssertEqual(vial.mcgPerUnit, 25)
    }

    func testInvalidInputsThrow() {
        XCTAssertThrowsError(try Reconstitution(vial: .zero, waterMl: 2)) {
            XCTAssertEqual($0 as? ReconstitutionError, .vialNotPositive)
        }
        XCTAssertThrowsError(try Reconstitution(vial: .mg(-1), waterMl: 2)) {
            XCTAssertEqual($0 as? ReconstitutionError, .vialNotPositive)
        }
        XCTAssertThrowsError(try Reconstitution(vial: .mg(5), waterMl: 0)) {
            XCTAssertEqual($0 as? ReconstitutionError, .waterNotPositive)
        }
        XCTAssertThrowsError(try Reconstitution(vial: .mg(5), waterMl: 2).draw(.zero, with: .ml10)) {
            XCTAssertEqual($0 as? ReconstitutionError, .doseNotPositive)
        }
    }

    // MARK: Draws (worked examples checked by hand)

    func testClassicFiveMgTwoMl() throws {
        // 5 mg + 2 ml = 2.5 mg/ml; 250 mcg = 0.1 ml = 10 units; 20 doses.
        let draw = try Reconstitution(vial: .mg(5), waterMl: 2).draw(.mcg(250), with: .ml10)
        XCTAssertEqual(draw.volumeMl, d("0.1"))
        XCTAssertEqual(draw.units, 10)
        XCTAssertEqual(draw.nearestMarkUnits, 10)
        XCTAssertEqual(draw.fullDosesPerVial, 20)
        XCTAssertEqual(draw.warnings, [])
    }

    func testSemaglutideStartingDose() throws {
        // 5 mg + 2 ml, 0.25 mg dose typed in mg.
        let draw = try Reconstitution(vial: .mg(5), waterMl: 2).draw(.mg(d("0.25")), with: .ml05)
        XCTAssertEqual(draw.units, 10)
        XCTAssertEqual(draw.fullDosesPerVial, 20)
    }

    func testThirdsStayExact() throws {
        // 5 mg + 3 ml = 1.666… mg/ml; 500 mcg must be exactly 0.3 ml / 30 units.
        let draw = try Reconstitution(vial: .mg(5), waterMl: 3).draw(.mcg(500), with: .ml03)
        XCTAssertEqual(draw.volumeMl, d("0.3"))
        XCTAssertEqual(draw.units, 30)
        XCTAssertEqual(draw.warnings, [], "exactly full is not over capacity")
    }

    func testDecimalWaterAndDose() throws {
        // 2 mg + 1 ml, 0.3 mg → 0.15 ml = 15 units; 6 full doses (6.67).
        let draw = try Reconstitution(vial: .mg(2), waterMl: 1).draw(.mg(d("0.3")), with: .ml03)
        XCTAssertEqual(draw.volumeMl, d("0.15"))
        XCTAssertEqual(draw.units, 15)
        XCTAssertEqual(draw.fullDosesPerVial, 6)

        // 10 mg + 2.5 ml = 4 mg/ml; 1.2 mg → 0.3 ml = 30 units.
        let other = try Reconstitution(vial: .mg(10), waterMl: d("2.5")).draw(.mg(d("1.2")), with: .ml05)
        XCTAssertEqual(other.units, 30)
        XCTAssertEqual(other.fullDosesPerVial, 8)
    }

    func testNearestMarkDependsOnBarrel() throws {
        // 10 mg + 1 ml, 250 mcg → 2.5 units: 3 on a 1-unit barrel, 2 on a 2-unit barrel.
        let vial = try Reconstitution(vial: .mg(10), waterMl: 1)
        let fine = try vial.draw(.mcg(250), with: .ml03)
        XCTAssertEqual(fine.units, d("2.5"))
        XCTAssertEqual(fine.nearestMarkUnits, 3)
        XCTAssertEqual(try vial.draw(.mcg(250), with: .ml10).nearestMarkUnits, 2)
        XCTAssertEqual(try vial.draw(.mcg(330), with: .ml10).nearestMarkUnits, 4)
    }

    func testOverCapacityNeedsSeveralDraws() throws {
        // Tirzepatide-like: 10 mg + 2 ml, 2.5 mg → 0.5 ml = 50 units.
        let vial = try Reconstitution(vial: .mg(10), waterMl: 2)
        XCTAssertEqual(try vial.draw(.mg(d("2.5")), with: .ml03).warnings, [.exceedsSyringe(draws: 2)])
        XCTAssertEqual(try vial.draw(.mg(d("2.5")), with: .ml05).warnings, [])
        XCTAssertEqual(try vial.draw(.mg(7), with: .ml10).warnings, [.exceedsSyringe(draws: 2)])
    }

    func testBelowSmallestMark() throws {
        // 10 mg + 1 ml, 50 mcg → 0.5 unit.
        let vial = try Reconstitution(vial: .mg(10), waterMl: 1)
        XCTAssertEqual(try vial.draw(.mcg(50), with: .ml05).warnings, [.belowSmallestMark])
        // 1.5 units: fine on a 1-unit barrel, below the 2-unit mark.
        XCTAssertEqual(try vial.draw(.mcg(150), with: .ml05).warnings, [])
        XCTAssertEqual(try vial.draw(.mcg(150), with: .ml10).warnings, [.belowSmallestMark])
    }

    func testDoseLargerThanVial() throws {
        let draw = try Reconstitution(vial: .mg(2), waterMl: 1).draw(.mg(3), with: .ml10)
        XCTAssertEqual(draw.fullDosesPerVial, 0)
        XCTAssertEqual(draw.units, 150)
        XCTAssertEqual(draw.warnings, [.doseExceedsVial, .exceedsSyringe(draws: 2)])
    }

    func testDoseEqualToVialIsOneDose() throws {
        let draw = try Reconstitution(vial: .mg(2), waterMl: 1).draw(.mg(2), with: .ml10)
        XCTAssertEqual(draw.fullDosesPerVial, 1)
        XCTAssertEqual(draw.warnings, [])
    }

    func testCodableRoundTrip() throws {
        let vial = try Reconstitution(vial: .mg(d("7.5")), waterMl: d("1.5"))
        let data = try JSONEncoder().encode(vial)
        XCTAssertEqual(try JSONDecoder().decode(Reconstitution.self, from: data), vial)
    }
}
