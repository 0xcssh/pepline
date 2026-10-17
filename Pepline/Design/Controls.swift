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

/// A titled card for the V2 editors (dose, schedule, weight).
struct FormCard<Content: View>: View {
    var title: Text?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                title.font(.subheadline.weight(.semibold)).foregroundStyle(PLColor.muted)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .plCard()
    }
}

/// The compound as chips: the user's compounds, plus "New" for a typed one.
struct CompoundChips: View {
    @EnvironmentObject private var store: DataStore
    @Binding var choice: CompoundChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(store.journal.compounds.sorted { $0.name < $1.name }) { compound in
                    Button { choice = CompoundChoice(existingID: compound.id) } label: { Text(verbatim: compound.name) }
                        .buttonStyle(ChipStyle(selected: choice.existingID == compound.id))
                }
                Button { choice = CompoundChoice() } label: {
                    Label { Text("New") } icon: { Image(systemName: "plus") }
                }
                .buttonStyle(ChipStyle(selected: choice.existingID == nil))
            }
            if choice.existingID == nil {
                TextField("Compound name", text: $choice.newName)
                    .textInputAutocapitalization(.words)
                    .font(.headline)
                    .padding(12)
                    .background(PLColor.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .sensoryFeedback(.selection, trigger: choice)
    }
}

/// Dose in big numerals with its unit chips.
struct DoseAmountCard: View {
    @Binding var text: String
    @Binding var unit: DoseUnit

    var body: some View {
        FormCard(title: Text("Dose")) {
            NumberEntry(title: Text("Dose"), text: $text)
            ChipPicker(selection: $unit, options: DoseUnit.allCases.map { ($0, Fmt.symbol($0)) })
        }
    }
}
