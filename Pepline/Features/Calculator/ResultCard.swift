import SwiftUI

/// The answer: units to draw, drawn on the syringe, with ml and mg next to
/// it — the FDA's dosing errors came from mixing those three up.
struct ResultCard: View {
    let draw: Draw
    let syringe: SyringeModel
    let reconstitution: Reconstitution
    let dose: Mass

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Draw to")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: Fmt.number(draw.units))
                    .plNumeral(size: 56)
                    .foregroundStyle(PLColor.navy)
                Text("units")
                    .font(.title3.bold())
                    .foregroundStyle(PLColor.navy)
            }
            if draw.nearestMarkUnits != draw.units {
                Text("Closest mark on this syringe: \(Fmt.number(draw.nearestMarkUnits, digits: 1))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            SyringeView(syringe: syringe, units: draw.units)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                row("Volume", Fmt.ml(draw.volumeMl))
                row("Dose", Fmt.mass(dose))
                row("Concentration", "\(Fmt.mass(.mcg(reconstitution.mcgPerMl))) / ml")
                row("Per unit", Fmt.mass(.mcg(reconstitution.mcgPerUnit)))
                row("Full doses in the vial", "\(draw.fullDosesPerVial)")
            }
            .font(.subheadline)

            ForEach(warnings, id: \.self) { warning in
                Label { Text(verbatim: warning) } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                .font(.footnote)
            }
        }
        .padding(.vertical, 6)
    }

    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(.secondary)
            Text(verbatim: value).monospacedDigit()
        }
    }

    /// Stable order, most serious first.
    private var warnings: [String] {
        var texts: [String] = []
        if draw.warnings.contains(.doseExceedsVial) {
            texts.append(String(localized: "The dose is more than the whole vial."))
        }
        for case .exceedsSyringe(let draws) in draw.warnings {
            texts.append(String(localized: "This volume does not fit in one syringe: \(String(draws)) draws are needed."))
        }
        if draw.warnings.contains(.belowSmallestMark) {
            texts.append(String(localized: "This volume is below the smallest mark of this syringe and cannot be measured accurately."))
        }
        if draw.warnings.contains(.smallFractionOfBarrel) {
            texts.append(String(localized: "Less than a tenth of this syringe: read the scale carefully. A smaller syringe is easier to read."))
        }
        return texts
    }
}
