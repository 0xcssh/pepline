import SwiftUI

/// Front and back silhouettes with the 8 injection zones (abdomen and thighs
/// on the front, glutes and the back of the arms on the back). Each zone
/// shows how recently it was used; the least recent one pulses. Tapping a
/// zone selects it. Pepline shows rotation, it does not prescribe a site.
struct BodyMapView: View {
    @Binding var selection: SiteZone?
    let lastUse: [SiteZone: Date]
    var now = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var suggestion: SiteZone { SiteRotation.leastRecent(lastUse: lastUse) }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                figure(front: true)
                figure(front: false)
            }
            .frame(height: 260)
            .padding(.bottom, 16)
            HStack(spacing: 14) {
                legend(color: PLColor.warning, Text("Used recently"))
                legend(color: PLColor.accent, Text("Rested"))
                legend(color: PLColor.muted.opacity(0.4), Text("Never used"))
            }
            .font(.caption)
            if let selection {
                Text(verbatim: Fmt.site(selection.site, selection.side))
                    .font(.headline)
                    .foregroundStyle(PLColor.text)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { pulse = true }
        }
    }

    /// Zone centres in a 100 × 220 figure space. Left/right are the
    /// person's own sides: on the front view their left is on our right.
    private func center(_ zone: SiteZone, front: Bool) -> CGPoint? {
        let mirror: CGFloat = zone.side == .left ? 1 : -1
        switch (zone.site, front) {
        case (.abdomen, true): return CGPoint(x: 50 + 12 * mirror, y: 76)
        case (.thigh, true): return CGPoint(x: 50 + 11 * mirror, y: 140)
        case (.glute, false): return CGPoint(x: 50 - 11 * mirror, y: 98)
        case (.arm, false): return CGPoint(x: 50 - 33 * mirror, y: 70)
        default: return nil
        }
    }

    private func figure(front: Bool) -> some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 100, proxy.size.height / 220)
            let origin = CGPoint(x: (proxy.size.width - 100 * scale) / 2, y: (proxy.size.height - 220 * scale) / 2)
            ZStack(alignment: .topLeading) {
                Silhouette()
                    .fill(PLColor.card)
                    .overlay(Silhouette().stroke(PLColor.line, lineWidth: 1.5))
                    .frame(width: 100 * scale, height: 220 * scale)
                    .offset(x: origin.x, y: origin.y)
                ForEach(SiteZone.allCases, id: \.self) { zone in
                    if let point = center(zone, front: front) {
                        zoneButton(zone, size: 17 * scale)
                            .position(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            (front ? Text("Front") : Text("Back"))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(PLColor.muted)
                .offset(y: 14)
        }
    }

    private func color(for zone: SiteZone) -> Color {
        guard let days = SiteRotation.daysSince(zone, lastUse: lastUse, now: now, calendar: .current) else {
            return PLColor.muted.opacity(0.4)
        }
        return days < 3 ? PLColor.warning : PLColor.accent
    }

    private func zoneButton(_ zone: SiteZone, size: CGFloat) -> some View {
        let selected = selection == zone
        let suggested = zone == suggestion
        return Button {
            selection = selected ? nil : zone
        } label: {
            ZStack {
                if suggested && !selected {
                    Circle()
                        .stroke(PLColor.accent, lineWidth: 2)
                        .frame(width: size * 1.6, height: size * 1.6)
                        .scaleEffect(pulse ? 1.15 : 0.9)
                        .opacity(pulse ? 0.3 : 0.9)
                }
                Circle()
                    .fill(selected ? PLColor.accent : color(for: zone).opacity(0.35))
                    .overlay(Circle().strokeBorder(selected ? PLColor.text : color(for: zone), lineWidth: selected ? 2.5 : 1.5))
                    .frame(width: size, height: size)
                    .shadow(color: selected ? PLColor.accent.opacity(0.7) : .clear, radius: 8)
            }
            .frame(width: max(size * 1.8, 44), height: max(size * 1.8, 44))
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityLabel(Text(verbatim: Fmt.site(zone.site, zone.side)))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func legend(color: Color, _ text: Text) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 9, height: 9)
            text.foregroundStyle(PLColor.muted)
        }
    }
}

/// A simple, neutral human outline in a 100 × 220 box: head, neck, torso,
/// arms and legs as rounded shapes (no anatomy, works for front and back).
private struct Silhouette: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 100, sy = rect.height / 220
        func r(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * sx, y: rect.minY + y * sy, width: w * sx, height: h * sy)
        }
        var path = Path()
        path.addEllipse(in: r(38, 0, 24, 26))                                   // head
        path.addRoundedRect(in: r(45, 24, 10, 8), cornerSize: CGSize(width: 3 * sx, height: 3 * sy))  // neck
        path.addRoundedRect(in: r(28, 30, 44, 76), cornerSize: CGSize(width: 16 * sx, height: 16 * sy)) // torso
        path.addRoundedRect(in: r(12, 34, 14, 62), cornerSize: CGSize(width: 7 * sx, height: 7 * sy))   // arm
        path.addRoundedRect(in: r(74, 34, 14, 62), cornerSize: CGSize(width: 7 * sx, height: 7 * sy))   // arm
        path.addRoundedRect(in: r(30, 100, 18, 116), cornerSize: CGSize(width: 9 * sx, height: 9 * sy)) // leg
        path.addRoundedRect(in: r(52, 100, 18, 116), cornerSize: CGSize(width: 9 * sx, height: 9 * sy)) // leg
        return path
    }
}
