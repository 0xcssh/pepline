import SwiftUI

/// Pepline design system (shared with RepLock) — light UI with the navy + orange→pink gradient brand
/// pulled from the App Store template artwork. Rules of use:
/// - Navy: structure (primary buttons, headers, big neutral numerals).
/// - Reward gradient: ONLY for reward moments (balance, "+X min earned",
///   streaks) so it keeps its celebratory meaning.
/// - Backgrounds are near-white; content sits on white cards.
enum PLColor {
    /// Deep navy from the App Store templates.
    static let navy = Color(red: 0x12 / 255.0, green: 0x39 / 255.0, blue: 0x5B / 255.0)
    /// Near-white screen background behind cards.
    static let background = Color(red: 0xF7 / 255.0, green: 0xF8 / 255.0, blue: 0xFA / 255.0)
    /// Soft drop shadow under white cards.
    static let cardShadow = Color.black.opacity(0.07)
    /// Gradient endpoints, exposed for custom drawing (charts, strokes).
    static let gradientStart = Color(red: 0xF5 / 255.0, green: 0xA3 / 255.0, blue: 0x53 / 255.0)
    static let gradientEnd = Color(red: 0xF0 / 255.0, green: 0x56 / 255.0, blue: 0x6A / 255.0)
}

enum PLGradient {
    /// The reward gradient (orange → pink) from the template headlines.
    static let reward = LinearGradient(
        colors: [PLColor.gradientStart, PLColor.gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

/// Full-width navy pill button — the CTA style of the App Store templates.
struct PrimaryPillButtonStyle: ButtonStyle {
    var fill: Color = PLColor.navy
    var textColor: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1), in: Capsule())
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == PrimaryPillButtonStyle {
    static var primaryPill: PrimaryPillButtonStyle { PrimaryPillButtonStyle() }
}

/// White rounded card with a soft shadow — the template testimonial-card look.
private struct PLCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: PLColor.cardShadow, radius: 12, y: 4)
    }
}

extension View {
    func plCard() -> some View { modifier(PLCardModifier()) }

    /// Big rounded numerals — the app's signature typography.
    func plNumeral(size: CGFloat) -> some View {
        font(.system(size: size, weight: .black, design: .rounded))
            .monospacedDigit()
    }
}
