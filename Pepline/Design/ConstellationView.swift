import SwiftUI

/// One star per logged dose, linked in the order they were taken; the newest
/// one glows in the accent color. The reward moment after logging a dose
/// (inspired by the best-rated app in the category, research/design).
/// Positions are seeded, so the same history always draws the same sky.
struct ConstellationView: View {
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                draw(in: &context, size: size, time: time)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Constellation of your doses: \(String(count)) stars"))
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        var random = SeededRandom(seed: 7)
        // Faint dust behind the stars.
        for _ in 0..<60 {
            let point = CGPoint(x: random.next() * size.width, y: random.next() * size.height)
            let radius = random.next() * 1.1
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(PLColor.text.opacity(0.22)))
        }
        // The last 30 doses at most, so the sky stays readable.
        let shown = min(max(count, 1), 30)
        let inset: CGFloat = 24
        // A path that wanders left to right, one step per dose, so the lines
        // read as a journey instead of crossing each other.
        var stars: [(CGPoint, CGFloat, Double)] = []
        let step = (size.width - inset * 2) / CGFloat(max(shown - 1, 1))
        var y = size.height * 0.55
        for index in 0..<shown {
            y += (random.next() - 0.5) * size.height * 0.32
            y = min(max(y, inset), size.height - inset)
            let x = shown == 1 ? size.width / 2 : inset + step * CGFloat(index) + (random.next() - 0.5) * step * 0.4
            stars.append((CGPoint(x: x, y: y), 2.2 + random.next() * 2, random.next() * 6))
        }
        var path = Path()
        for (index, star) in stars.enumerated() {
            index == 0 ? path.move(to: star.0) : path.addLine(to: star.0)
        }
        context.stroke(path, with: .color(PLColor.accent.opacity(0.3)), lineWidth: 1.2)

        for (index, star) in stars.enumerated() {
            let isNewest = index == stars.count - 1
            let twinkle = 0.75 + 0.25 * sin(time * 1.4 + star.2)
            let radius = isNewest ? star.1 * 2.2 : star.1
            let rect = CGRect(x: star.0.x - radius, y: star.0.y - radius, width: radius * 2, height: radius * 2)
            var glow = context
            glow.addFilter(.shadow(color: PLColor.accent.opacity(0.9), radius: isNewest ? 14 : 6))
            glow.fill(Path(ellipseIn: rect),
                      with: .color(isNewest ? PLColor.accent : PLColor.text.opacity(0.85 * twinkle)))
        }
    }
}

/// Deterministic generator (same seed, same sky).
private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    /// 0…1
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(state >> 33) / CGFloat(UInt32.max >> 1)
    }
}

/// Shown in place of the dose editor right after a new dose is saved.
struct DoseLoggedView: View {
    let starCount: Int
    let summary: String
    let dosesLeft: Int?
    let next: Date?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ConstellationView(count: starCount)
                .frame(height: 280)
                .background(RadialGradient(colors: [PLColor.accent.opacity(0.16), .clear],
                                           center: .center, startRadius: 0, endRadius: 200))
            VStack(spacing: 6) {
                Text("Dose logged")
                    .font(.title.bold())
                    .foregroundStyle(PLColor.text)
                Text("Star number \(String(starCount)) lights up.")
                    .foregroundStyle(PLColor.muted)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(verbatim: summary).font(.headline).foregroundStyle(PLColor.text)
                if let dosesLeft {
                    Text("\(String(dosesLeft)) full doses left in this vial.").foregroundStyle(PLColor.muted)
                }
                if let next {
                    Text("Next: \(next.formatted(date: .abbreviated, time: .shortened))").foregroundStyle(PLColor.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .plCard()
            Spacer(minLength: 0)
            Button(action: onDone) { Text("Done") }
                .buttonStyle(.primaryPill)
        }
        .padding(20)
        .background(PLBackground())
        .sensoryFeedback(.success, trigger: starCount)
    }
}
