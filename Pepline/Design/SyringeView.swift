import SwiftUI

/// A U-100 syringe drawn to scale with its graduations and filled up to the
/// dose. Needle on the left, plunger on the right, like reading a ruler.
struct SyringeView: View {
    let syringe: SyringeModel
    /// Units drawn; clamped to the barrel.
    let units: Decimal

    private var capacity: Double { NSDecimalNumber(decimal: syringe.capacityUnits).doubleValue }
    private var tick: Double { NSDecimalNumber(decimal: syringe.tickUnits).doubleValue }
    private var fill: Double { min(max(NSDecimalNumber(decimal: units).doubleValue / capacity, 0), 1) }
    /// Numbered every 5 units on a 0.3 ml barrel, every 10 otherwise.
    private var labelEvery: Double { capacity <= 30 ? 5 : 10 }

    var body: some View {
        Canvas { context, size in
            let needle: CGFloat = size.width * 0.12
            let plunger: CGFloat = size.width * 0.10
            let barrel = CGRect(x: needle, y: size.height * 0.18,
                                width: size.width - needle - plunger, height: size.height * 0.42)
            let navy = PLColor.navy

            // Needle and hub.
            var needlePath = Path()
            needlePath.move(to: CGPoint(x: 0, y: barrel.midY))
            needlePath.addLine(to: CGPoint(x: needle * 0.7, y: barrel.midY))
            context.stroke(needlePath, with: .color(navy.opacity(0.6)), lineWidth: 1.5)
            context.fill(Path(roundedRect: CGRect(x: needle * 0.7, y: barrel.midY - barrel.height * 0.18,
                                                  width: needle * 0.3, height: barrel.height * 0.36),
                              cornerRadius: 2), with: .color(navy.opacity(0.6)))

            // Liquid up to the dose.
            let liquid = CGRect(x: barrel.minX, y: barrel.minY, width: barrel.width * fill, height: barrel.height)
            context.fill(Path(roundedRect: liquid, cornerRadius: 4), with: .color(navy.opacity(0.22)))

            // Stopper at the dose, plunger rod behind it.
            let stopperX = barrel.minX + barrel.width * fill
            context.fill(Path(roundedRect: CGRect(x: stopperX, y: barrel.minY + 2, width: 6, height: barrel.height - 4),
                              cornerRadius: 2), with: .color(navy))
            // Rod drawn outside the barrel only, so nothing crosses the
            // graduations the user has to read.
            var rod = Path()
            rod.move(to: CGPoint(x: barrel.maxX, y: barrel.midY))
            rod.addLine(to: CGPoint(x: size.width - 4, y: barrel.midY))
            context.stroke(rod, with: .color(navy.opacity(0.5)), lineWidth: 3)
            context.fill(Path(roundedRect: CGRect(x: size.width - 8, y: barrel.minY - 4, width: 8, height: barrel.height + 8),
                              cornerRadius: 3), with: .color(navy.opacity(0.5)))

            // Barrel outline.
            context.stroke(Path(roundedRect: barrel, cornerRadius: 4), with: .color(navy), lineWidth: 2)

            // Graduations: every tick, longer and numbered at each label step.
            // Integer steps: adding 0.5 repeatedly would drift.
            for step in 0...Int((capacity / tick).rounded()) {
                let value = Double(step) * tick
                let x = barrel.minX + barrel.width * value / capacity
                let isLabelled = isMultiple(value, of: labelEvery)
                let isMid = isMultiple(value, of: labelEvery / 2)
                let length = barrel.height * (isLabelled ? 0.55 : isMid ? 0.4 : 0.25)
                var mark = Path()
                mark.move(to: CGPoint(x: x, y: barrel.maxY))
                mark.addLine(to: CGPoint(x: x, y: barrel.maxY - length))
                context.stroke(mark, with: .color(navy), lineWidth: isLabelled ? 1.5 : 0.8)
                if isLabelled {
                    context.draw(Text(verbatim: "\(Int(value))").font(.caption2).foregroundStyle(navy),
                                 at: CGPoint(x: x, y: barrel.maxY + 10))
                }
            }
        }
        .frame(height: 80)
        .accessibilityElement()
        .accessibilityLabel(Text("Syringe filled to \(Fmt.number(units)) units"))
    }

    private func isMultiple(_ value: Double, of step: Double) -> Bool {
        let ratio = value / step
        return abs(ratio - ratio.rounded()) < 0.0001
    }
}
