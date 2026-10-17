import SwiftUI
import UIKit

/// Pepline design system, V2 "calm futurism" (research/design/pepline-hud.html,
/// chosen 2026-10-15 for its fit with the audience: "easy/simple" is what
/// category reviews praise, GLP-1 users skew 50–64).
/// Rules of use:
/// - One glowing value per screen (the units to draw, the billed price):
///   `accent` + `.plGlow()`. Everything else stays quiet.
/// - Rounded type everywhere (`.fontDesign(.rounded)` at the root).
/// - Dark first, light supported: every color adapts to the system setting.
enum PLColor {
    /// Screen background.
    static let background = adaptive(dark: 0x0B1015, light: 0xF3F6F5)
    /// Glass card fill.
    static let card = adaptive(dark: 0xFFFFFF, darkAlpha: 0.055, light: 0xFFFFFF, lightAlpha: 1)
    /// Hairline borders and separators.
    static let line = adaptive(dark: 0xFFFFFF, darkAlpha: 0.08, light: 0x0E1714, lightAlpha: 0.07)
    /// Primary text.
    static let text = adaptive(dark: 0xE6EFEC, light: 0x0E1714)
    /// Secondary text.
    static let muted = adaptive(dark: 0x7D918B, light: 0x6B7A75)
    /// Mint accent: the value that matters, buttons, selection.
    static let accent = adaptive(dark: 0x6BF5C8, light: 0x0F9C75)
    /// Text on an accent fill.
    static let onAccent = adaptive(dark: 0x052018, light: 0xFFFFFF)
    /// Warnings (a fact about the syringe, never a judgement on the dose).
    static let warning = adaptive(dark: 0xFFB547, light: 0xC77800)
    /// Water intake rings and drops.
    static let water = adaptive(dark: 0x5CC8FF, light: 0x0A7FC2)

    private static func adaptive(dark: UInt32, darkAlpha: CGFloat = 1, light: UInt32, lightAlpha: CGFloat = 1) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: dark, alpha: darkAlpha)
                : UIColor(hex: light, alpha: lightAlpha)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}

/// Screen background: the base color with a soft mint glow near the top.
struct PLBackground: View {
    var body: some View {
        ZStack {
            PLColor.background
            RadialGradient(colors: [PLColor.accent.opacity(0.14), .clear], center: UnitPoint(x: 0.5, y: 0.22),
                           startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

/// Full-width accent button.
struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(PLColor.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(PLColor.accent.opacity(configuration.isPressed ? 0.8 : 1),
                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: PLColor.accent.opacity(0.25), radius: 14, y: 6)
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == PrimaryPillButtonStyle {
    static var primaryPill: PrimaryPillButtonStyle { PrimaryPillButtonStyle() }
}

/// Glass card: translucent fill, hairline border, generous radius.
private struct PLCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(PLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(PLColor.line))
    }
}

extension View {
    func plCard() -> some View { modifier(PLCardModifier()) }

    /// Big rounded numerals — the app's signature typography.
    func plNumeral(size: CGFloat) -> some View {
        font(.system(size: size, weight: .heavy, design: .rounded))
            .monospacedDigit()
    }

    /// The one glowing value of a screen.
    func plGlow() -> some View {
        shadow(color: PLColor.accent.opacity(0.45), radius: 14)
    }

    /// Lists and forms on the app background instead of grouped grey.
    func plScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(PLBackground())
    }
}
