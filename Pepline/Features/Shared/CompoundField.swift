import SwiftUI

/// Pick a saved compound or type a new name. The caller resolves the result
/// with `resolve(in:)` when saving.
struct CompoundChoice: Equatable {
    var existingID: Compound.ID?
    var newName = ""

    var isValid: Bool { existingID != nil || !newName.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The chosen compound, creating it in the journal when it is new.
    func resolve(in journal: inout Journal) -> Compound.ID {
        if let existingID { return existingID }
        let compound = Compound(name: newName.trimmingCharacters(in: .whitespaces))
        journal.save(compound)
        return compound.id
    }
}

struct CompoundField: View {
    @EnvironmentObject private var store: DataStore
    @Binding var choice: CompoundChoice

    var body: some View {
        if !store.journal.compounds.isEmpty {
            Picker("Compound", selection: $choice.existingID) {
                ForEach(store.journal.compounds.sorted { $0.name < $1.name }) { compound in
                    Text(verbatim: compound.name).tag(Optional(compound.id))
                }
                Text("New compound…").tag(Compound.ID?.none)
            }
        }
        if choice.existingID == nil {
            TextField("Compound name", text: $choice.newName)
                .textInputAutocapitalization(.words)
        }
    }
}

/// Amount + unit, used by the dose and schedule editors.
struct DoseAmountField: View {
    @Binding var text: String
    @Binding var unit: DoseUnit

    var body: some View {
        DecimalField(title: "Dose", text: $text)
        Picker("Unit", selection: $unit) {
            ForEach(DoseUnit.allCases, id: \.self) { Text(verbatim: Fmt.symbol($0)).tag($0) }
        }
        .pickerStyle(.segmented)
    }
}
