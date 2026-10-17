import SwiftUI

/// Progress bar + back chevron, on every screen. The bar fills fast at the
/// end (goal-gradient: people speed up when the finish is in sight).
struct OnboardingChrome: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        HStack(spacing: 14) {
            Button(action: model.goBack) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 32, height: 32)
            }
            .opacity(model.canGoBack ? 1 : 0)
            .disabled(!model.canGoBack)
            .accessibilityLabel(Text("Back"))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PLColor.accent.opacity(0.15))
                    Capsule().fill(PLColor.accent)
                        .frame(width: proxy.size.width * model.progress)
                        .shadow(color: PLColor.accent.opacity(0.6), radius: 6)
                }
            }
            .frame(height: 6)
            .animation(.spring(duration: 0.6), value: model.progress)
        }
        .foregroundStyle(PLColor.text)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// Living background for the whole onboarding: three soft mint glows that
/// drift slowly, and fine particles. Still when Reduce Motion is on.
struct OnboardingBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let glows: [(CGFloat, CGFloat, CGFloat, Double)] = [(0.2, 0.18, 0.55, 0.20), (0.85, 0.42, 0.45, 0.12), (0.4, 0.92, 0.6, 0.10)]
                for (index, glow) in glows.enumerated() {
                    let phase = t / (9 + Double(index) * 3)
                    let center = CGPoint(x: size.width * (glow.0 + 0.08 * CGFloat(sin(phase))),
                                         y: size.height * (glow.1 + 0.05 * CGFloat(cos(phase * 1.3))))
                    let radius = size.width * glow.2
                    context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                        width: radius * 2, height: radius * 2)),
                                 with: .radialGradient(Gradient(colors: [PLColor.accent.opacity(glow.3), .clear]),
                                                       center: center, startRadius: 0, endRadius: radius))
                }
                // Particles rising slowly.
                for index in 0..<36 {
                    let seed = Double(index) * 12.9898
                    let x = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                    let speed = 0.012 + 0.01 * abs(cos(seed))
                    let y = 1 - (t * speed + abs(sin(seed * 3))).truncatingRemainder(dividingBy: 1)
                    let point = CGPoint(x: size.width * CGFloat(abs(x)), y: size.height * CGFloat(y))
                    let r = 0.8 + 1.2 * abs(sin(seed * 7))
                    context.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)),
                                 with: .color(PLColor.accent.opacity(0.18 + 0.25 * abs(sin(t * 0.8 + seed)))))
                }
            }
        }
        .background(PLColor.background)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Concentric rings that pulse out of a glowing symbol: the hero of the
/// statement screens.
struct PulseRings: View {
    let symbol: String
    var size: CGFloat = 190
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(0..<3) { ring in
                Circle()
                    .stroke(PLColor.accent.opacity(0.35 - Double(ring) * 0.1), lineWidth: 1.5)
                    .scaleEffect(pulse ? 1 + CGFloat(ring) * 0.22 : 0.7 + CGFloat(ring) * 0.15)
                    .opacity(pulse ? 0.25 : 0.9)
            }
            Circle()
                .fill(RadialGradient(colors: [PLColor.accent.opacity(0.35), PLColor.accent.opacity(0.04)],
                                     center: .center, startRadius: 4, endRadius: size * 0.32))
                .frame(width: size * 0.56, height: size * 0.56)
            Image(systemName: symbol)
                .font(.system(size: size * 0.24, weight: .semibold))
                .foregroundStyle(PLColor.accent)
                .plGlow()
                .symbolEffect(.pulse, isActive: !reduceMotion)
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityHidden(true)
    }
}

/// The app's mark, glowing, slowly breathing.
struct LogoHero: View {
    var size: CGFloat = 120
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .fill(PLColor.accent.opacity(0.18))
                .frame(width: size * 1.7, height: size * 1.7)
                .blur(radius: 30)
                .scaleEffect(breathe ? 1.08 : 0.92)
            Image("Logo")
                .resizable()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
                .shadow(color: PLColor.accent.opacity(0.4), radius: 20)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityHidden(true)
    }
}

/// Fades and slides an element in after `index` × 70 ms, so lists build up
/// in front of the user instead of appearing all at once.
struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
            .onAppear {
                withAnimation(.spring(duration: 0.5).delay(Double(index) * 0.07)) { shown = true }
            }
    }
}

extension View {
    func staggered(_ index: Int) -> some View { modifier(StaggeredAppear(index: index)) }
}

/// A screen with an optional hero illustration, a question or message, its
/// content and the main button. Fills the whole screen.
struct QuestionScreen<Content: View>: View {
    @ObservedObject var model: OnboardingModel
    let title: Text
    var subtitle: Text?
    var buttonTitle: Text = Text("Continue")
    var secondary: (title: Text, action: () -> Void)?
    var onContinue: (() -> Void)?
    var hero: AnyView?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(model: model)
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let hero {
                            hero
                                .frame(maxWidth: .infinity)
                                .padding(.top, 8)
                                .staggered(0)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            title
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(PLColor.text)
                                .fixedSize(horizontal: false, vertical: true)
                            if let subtitle {
                                subtitle
                                    .font(.body)
                                    .foregroundStyle(PLColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .staggered(1)
                        content
                        Spacer(minLength: 0)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height, alignment: .topLeading)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            VStack(spacing: 10) {
                Button {
                    (onContinue ?? model.advance)()
                } label: {
                    buttonTitle
                }
                .buttonStyle(.primaryPill)
                .disabled(!model.canContinue)
                .opacity(model.canContinue ? 1 : 0.4)
                .sensoryFeedback(.impact(weight: .light), trigger: model.step)
                if let secondary {
                    Button(action: secondary.action) { secondary.title }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PLColor.muted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(OnboardingBackdrop())
    }
}

/// One sentence, typed out under a pulsing symbol; continues by itself or on tap.
struct StatementScreen: View {
    @ObservedObject var model: OnboardingModel
    let text: String
    var symbol = "sparkles"
    var autoAdvanceAfter: Double = 2.4
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(model: model)
            Spacer()
            PulseRings(symbol: symbol, size: 220)
            Text(verbatim: String(text.prefix(shown)))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(PLColor.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .accessibilityLabel(Text(verbatim: text))
            Spacer()
            Text("Tap to continue")
                .font(.footnote)
                .foregroundStyle(PLColor.muted)
                .padding(.bottom, 24)
        }
        .background(OnboardingBackdrop())
        .contentShape(Rectangle())
        .onTapGesture { model.advance() }
        .task(id: text) {
            shown = 0
            // Typewriter: about 30 characters a second.
            for count in 0...text.count {
                shown = count
                try? await Task.sleep(nanoseconds: 33_000_000)
            }
            try? await Task.sleep(nanoseconds: UInt64(autoAdvanceAfter * 1_000_000_000))
            if !Task.isCancelled { model.advance() }
        }
    }
}

/// A selectable card for single and multiple choice questions.
struct ChoiceCard: View {
    let symbol: String?
    let title: Text
    var detail: Text?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(selected ? PLColor.onAccent : PLColor.accent)
                        .frame(width: 44, height: 44)
                        .background(selected ? PLColor.accent : PLColor.accent.opacity(0.12), in: Circle())
                }
                VStack(alignment: .leading, spacing: 2) {
                    title.font(.headline).foregroundStyle(PLColor.text)
                    if let detail {
                        detail.font(.subheadline).foregroundStyle(PLColor.muted)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(selected ? PLColor.accent : PLColor.muted.opacity(0.5))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .background(selected ? PLColor.accent.opacity(0.1) : PLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(selected ? PLColor.accent : PLColor.line, lineWidth: selected ? 1.5 : 1))
            .scaleEffect(selected ? 1.01 : 1)
            .animation(.spring(duration: 0.3), value: selected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Big square tile for grid choices (goals).
struct ChoiceTile: View {
    let symbol: String
    let title: Text
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(selected ? PLColor.onAccent : PLColor.accent)
                    .frame(width: 64, height: 64)
                    .background(selected ? PLColor.accent : PLColor.accent.opacity(0.12), in: Circle())
                    .shadow(color: selected ? PLColor.accent.opacity(0.5) : .clear, radius: 12)
                title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PLColor.text)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 140)
            .padding(10)
            .background(selected ? PLColor.accent.opacity(0.1) : PLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(selected ? PLColor.accent : PLColor.line, lineWidth: selected ? 1.5 : 1))
            .scaleEffect(selected ? 1.02 : 1)
            .animation(.spring(duration: 0.3), value: selected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Row of a "what you get" list: symbol in a bubble + text.
struct FeatureLine: View {
    let symbol: String
    let text: Text

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(PLColor.accent)
                .frame(width: 40, height: 40)
                .background(PLColor.accent.opacity(0.12), in: Circle())
            text.foregroundStyle(PLColor.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
