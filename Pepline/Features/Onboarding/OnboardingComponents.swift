import SwiftUI

/// Progress bar + back chevron, on every screen.
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
                }
            }
            .frame(height: 6)
            .animation(.easeInOut, value: model.progress)
        }
        .foregroundStyle(PLColor.text)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// A light screen with a question or a message, content, and the main button.
struct QuestionScreen<Content: View>: View {
    @ObservedObject var model: OnboardingModel
    let title: Text
    var subtitle: Text?
    var buttonTitle: Text = Text("Continue")
    var secondary: (title: Text, action: () -> Void)?
    var onContinue: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(model: model)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    title
                        .font(.title.bold())
                        .foregroundStyle(PLColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        subtitle
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    content
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: 10) {
                Button {
                    (onContinue ?? model.advance)()
                } label: {
                    buttonTitle
                }
                .buttonStyle(.primaryPill)
                .disabled(!model.canContinue)
                .opacity(model.canContinue ? 1 : 0.4)
                if let secondary {
                    Button(action: secondary.action) { secondary.title }
                        .font(.subheadline)
                        .foregroundStyle(PLColor.text)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(PLBackground())
    }
}

/// Navy screen with one sentence, typed out; continues by itself or on tap.
struct StatementScreen: View {
    @ObservedObject var model: OnboardingModel
    let text: String
    var autoAdvanceAfter: Double = 2.4
    @State private var shown = 0

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(model: model)
            Spacer()
            Text(verbatim: String(text.prefix(shown)))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(PLColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(28)
                .accessibilityLabel(Text(verbatim: text))
            Spacer()
            Text("Tap to continue")
                .font(.footnote)
                .foregroundStyle(PLColor.muted)
                .padding(.bottom, 24)
        }
        .background(PLBackground())
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
                        .font(.title3)
                        .frame(width: 28)
                        .foregroundStyle(PLColor.text)
                }
                VStack(alignment: .leading, spacing: 2) {
                    title.font(.headline).foregroundStyle(PLColor.text)
                    if let detail {
                        detail.font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? PLColor.accent : Color.secondary.opacity(0.35))
            }
            .padding(16)
            .background(selected ? PLColor.accent.opacity(0.08) : PLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? PLColor.accent : PLColor.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Row of a "what you get" list: symbol + text.
struct FeatureLine: View {
    let symbol: String
    let text: Text

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(PLColor.text)
                .frame(width: 26)
            text.foregroundStyle(PLColor.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
