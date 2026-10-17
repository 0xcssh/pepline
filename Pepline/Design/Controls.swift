import SwiftUI

// The input language of the V2 screens (calculator, first vial): big
// rounded numerals, unit chips, numbered step cards.

/// A big rounded number field. Accepts "0,25" and "0.25" alike and, when
/// the text has two readings ("1,250"), asks which one instead of guessing.
struct NumberEntry: View {
    let title: Text
    @Binding var text: String
    var unit: String?
    var size: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField(text: $text, prompt: Text(verbatim: "0")) { title }
                    .keyboardType(.decimalPad)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(PLColor.text)
                if let unit {
                    Text(verbatim: unit).font(.title3.weight(.semibold)).foregroundStyle(PLColor.muted)
                }
            }
            if let parsed = DecimalInput.parse(text), let alternative = parsed.alternative {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(PLColor.warning)
                    Text("Did you mean").font(.footnote).foregroundStyle(PLColor.text)
                    choice(parsed.value)
                    choice(alternative)
                }
            }
        }
    }

    private func choice(_ value: Decimal) -> some View {
        Button {
            text = Fmt.plain(value)
            Analytics.track(.ambiguousInputResolved)
        } label: {
            Text(verbatim: Fmt.plain(value))
        }
        .buttonStyle(ChipStyle(selected: false))
    }
}

/// One numbered step: badge (a check once filled), title, content.
struct StepCard<Content: View>: View {
    let number: Int
    let title: Text
    let done: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(done ? PLColor.accent : PLColor.accent.opacity(0.12))
                    if done {
                        Image(systemName: "checkmark").font(.caption.weight(.heavy)).foregroundStyle(PLColor.onAccent)
                    } else {
                        Text(verbatim: String(number)).font(.caption.weight(.heavy)).foregroundStyle(PLColor.accent)
                    }
                }
                .frame(width: 26, height: 26)
                .animation(.spring(duration: 0.35), value: done)
                title.font(.headline).foregroundStyle(PLColor.text)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
    }
}

/// Unit choice as capsules.
struct ChipPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(Value, String)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options.indices, id: \.self) { index in
                Button { selection = options[index].0 } label: { Text(verbatim: options[index].1) }
                    .buttonStyle(ChipStyle(selected: selection == options[index].0))
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct ChipStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? PLColor.onAccent : PLColor.text)
            .background(selected ? PLColor.accent : PLColor.accent.opacity(0.08), in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? PLColor.accent : PLColor.line))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.25), value: selected)
    }
}
