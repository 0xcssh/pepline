import SwiftUI

/// A number field that accepts "0,25" and "0.25" alike and, when the text has
/// two readings ("1,250"), asks which one instead of guessing.
struct DecimalField: View {
    let title: LocalizedStringKey
    @Binding var text: String
    var unit: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                TextField(text: $text, prompt: Text(verbatim: "0")) { Text(title) }
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
                if let unit {
                    Text(verbatim: unit).foregroundStyle(.secondary)
                }
            }
            if let parsed = DecimalInput.parse(text), let alternative = parsed.alternative {
                HStack(spacing: 8) {
                    Image(systemName: "questionmark.circle.fill").foregroundStyle(.orange)
                    Text("Did you mean")
                        .font(.footnote)
                    choice(parsed.value)
                    choice(alternative)
                }
            }
        }
    }

    private func choice(_ value: Decimal) -> some View {
        Button(Fmt.plain(value)) { text = Fmt.plain(value) }
            .buttonStyle(.bordered)
            .font(.footnote.bold())
    }
}

/// The value of a number field, or nil while empty, invalid or ambiguous.
func decimalValue(_ text: String) -> Decimal? {
    guard let parsed = DecimalInput.parse(text), parsed.alternative == nil else { return nil }
    return parsed.value
}
