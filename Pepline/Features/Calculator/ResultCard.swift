import SwiftUI

/// The answer: units to draw, drawn on the syringe, with ml and mg next to
/// it — the FDA's dosing errors came from mixing those three up.
struct ResultCard: View {
    let draw: Draw
    let syringe: SyringeModel
    let reconstitution: Reconstitution
    let dose: Mass

    /// Share of the barrel the dose fills, for the dial.
    private var fill: Double {
        let ratio = NSDecimalNumber(decimal: draw.units / syringe.capacityUnits).doubleValue
        return min(max(ratio, 0), 1)
    }

    var body: some View {
        VStack(spacing: 16) {
            // The one glowing value of the screen: the units to draw.
            ZStack {
                Circle()
                    .stroke(PLColor.accent.opacity(0.12), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: max(fill, 0.012))
                    .stroke(PLColor.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .plGlow()
                VStack(spacing: 0) {
                    Text("Draw to")
                        .font(.subheadline)
                        .foregroundStyle(PLColor.muted)
                    Text(verbatim: Fmt.number(draw.units))
                        .plNumeral(size: 64)
                        .foregroundStyle(PLColor.accent)
                        .plGlow()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("units")
                        .font(.headline)
                        .foregroundStyle(PLColor.text)
                }
                .padding(.horizontal, 24)
            }
            .frame(width: 210, height: 210)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .animation(.spring(duration: 0.5), value: fill)
            .sensoryFeedback(.success, trigger: draw.units)

            if draw.nearestMarkUnits != draw.units {
                Text("Closest mark on this syringe: \(Fmt.number(draw.nearestMarkUnits, digits: 1))")
                    .font(.footnote)
                    .foregroundStyle(PLColor.muted)
            }

            SyringeView(syringe: syringe, units: draw.units)

            HStack(spacing: 8) {
                pill(Fmt.ml(draw.volumeMl))
                pill("\(Fmt.mass(.mcg(reconstitution.mcgPerMl))) / ml")
                pill(Fmt.mass(dose))
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                row("Per unit", Fmt.mass(.mcg(reconstitution.mcgPerUnit)))
                row("Full doses in the vial", "\(draw.fullDosesPerVial)")
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(warnings, id: \.self) { warning in
                Label { Text(verbatim: warning) } icon: {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(PLColor.warning)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
    }

    private func pill(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(PLColor.card, in: Capsule())
            .overlay(Capsule().strokeBorder(PLColor.line))
    }

    private func row(_ title: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(title).foregroundStyle(PLColor.muted)
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
