import Foundation

/// The calculator's inputs as typed, and what they compute to. A result only
/// exists when every field reads one way (see `decimalValue`).
@MainActor
final class CalculatorModel: ObservableObject {
    @Published var vialText = ""
    /// mg, or IU for vials labelled in IU (needs the IU factor).
    @Published var vialUnit: DoseUnit = .mg
    @Published var waterText = ""
    @Published var doseText = ""
    @Published var doseUnit: DoseUnit = .mcg
    @Published var iuPerMgText = ""
    @Published var syringe: SyringeModel = .ml05

    @Published private var loadedVial: Vial?

    /// The saved vial on screen, only while the inputs still match it: once
    /// the powder, water or syringe change, it is a new vial to save.
    var loadedVialID: Vial.ID? {
        guard let loadedVial, reconstitution == loadedVial.reconstitution, syringe == loadedVial.syringe else { return nil }
        return loadedVial.id
    }

    var needsIUFactor: Bool { vialUnit == .iu || doseUnit == .iu }

    var iuConversion: IUConversion? {
        guard let factor = decimalValue(iuPerMgText) else { return nil }
        let conversion = IUConversion(iuPerMg: factor)
        return conversion.isValid ? conversion : nil
    }

    var reconstitution: Reconstitution? {
        guard let vial = decimalValue(vialText),
              let mass = DoseAmount(value: vial, unit: vialUnit).mass(iuConversion),
              let water = decimalValue(waterText)
        else { return nil }
        return try? Reconstitution(vial: mass, waterMl: water)
    }

    var dose: Mass? {
        guard let value = decimalValue(doseText) else { return nil }
        return DoseAmount(value: value, unit: doseUnit).mass(iuConversion)
    }

    var draw: Draw? {
        guard let reconstitution, let dose else { return nil }
        return try? reconstitution.draw(dose, with: syringe)
    }

    func load(_ vial: Vial, compound: Compound?, regimenDose: DoseAmount?) {
        loadedVial = vial
        vialUnit = .mg
        vialText = Fmt.plain(vial.reconstitution.vial.value(in: .mg))
        waterText = Fmt.plain(vial.reconstitution.waterMl)
        syringe = vial.syringe
        iuPerMgText = compound?.iuConversion.map { Fmt.plain($0.iuPerMg) } ?? ""
        if let regimenDose {
            doseText = Fmt.plain(regimenDose.value)
            doseUnit = regimenDose.unit
        }
    }

    func clear() {
        loadedVial = nil
        vialText = ""
        waterText = ""
        doseText = ""
        iuPerMgText = ""
    }
}
