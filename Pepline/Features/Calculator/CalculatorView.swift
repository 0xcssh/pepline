import SwiftUI

struct CalculatorView: View {
    @EnvironmentObject private var store: DataStore
    @StateObject private var model = CalculatorModel()
    @State private var savingVial = false

    var body: some View {
        Form {
            Section("Vial") {
                DecimalField(title: "Powder in the vial", text: $model.vialText)
                Picker("Vial unit", selection: $model.vialUnit) {
                    Text(verbatim: "mg").tag(DoseUnit.mg)
                    Text(verbatim: Fmt.symbol(.iu)).tag(DoseUnit.iu)
                }
                .pickerStyle(.segmented)
                DecimalField(title: "Bacteriostatic water", text: $model.waterText, unit: "ml")
            }

            Section("Dose") {
                DecimalField(title: "Dose", text: $model.doseText)
                Picker("Unit", selection: $model.doseUnit) {
                    ForEach(DoseUnit.allCases, id: \.self) { Text(verbatim: Fmt.symbol($0)).tag($0) }
                }
                .pickerStyle(.segmented)
                if model.needsIUFactor {
                    DecimalField(title: "IU per mg (from the label)", text: $model.iuPerMgText)
                }
            }

            Section("Syringe") {
                Picker("Syringe", selection: $model.syringe) {
                    ForEach(SyringeModel.presets, id: \.self) { Text(verbatim: $0.label).tag($0) }
                }
            }

            if let draw = model.draw, let reconstitution = model.reconstitution, let dose = model.dose {
                Section {
                    ResultCard(draw: draw, syringe: model.syringe, reconstitution: reconstitution, dose: dose)
                    if model.loadedVialID == nil {
                        Button("Save this vial") { savingVial = true }
                    }
                }
            }

            SavedVialsSection(model: model)

            Section {
                DisclaimerText()
            }
        }
        .navigationTitle("Calculator")
        .toolbar {
            if model.loadedVialID != nil || !model.vialText.isEmpty {
                Button("Clear") { model.clear() }
            }
        }
        .sheet(isPresented: $savingVial) {
            SaveVialSheet(model: model)
        }
        .onAppear {
            if model.loadedVialID == nil, model.vialText.isEmpty, let preferred = store.journal.preferredSyringe {
                model.syringe = preferred
            }
        }
        .onChange(of: model.draw != nil) { _, hasResult in
            guard hasResult, let draw = model.draw else { return }
            Analytics.track(.calculatorResult, [
                "syringe": "\(model.syringe.capacityMl)ml-\(model.syringe.tickUnits)u",
                "doseUnit": model.doseUnit.rawValue,
                "warnings": String(draw.warnings.count),
            ])
        }
    }
}

/// Shown under the calculator, the schedules and in Settings (App Review
/// 1.4.1 / 1.4.2 — see docs/SOURCES.md).
struct DisclaimerText: View {
    var body: some View {
        Text("Unit conversion only. Pepline does not recommend doses. Follow your prescriber and check with your doctor.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

private struct SavedVialsSection: View {
    @EnvironmentObject private var store: DataStore
    @ObservedObject var model: CalculatorModel

    private var vials: [Vial] {
        store.journal.vials.filter { !$0.isArchived }.sorted { $0.mixedAt > $1.mixedAt }
    }

    var body: some View {
        if !vials.isEmpty {
            Section("Saved vials") {
                ForEach(vials) { vial in
                    Button { load(vial) } label: { row(vial) }
                        .tint(.primary)
                        .swipeActions {
                            Button("Archive") {
                                store.update { journal in
                                    var archived = vial
                                    archived.isArchived = true
                                    journal.save(archived)
                                }
                            }
                            .tint(PLColor.navy)
                        }
                }
            }
        }
    }

    private func regimen(for vial: Vial) -> Regimen? {
        store.journal.regimens.first { $0.compoundID == vial.compoundID }
    }

    private func load(_ vial: Vial) {
        model.load(vial, compound: store.journal.compound(vial.compoundID), regimenDose: regimen(for: vial)?.dose)
    }

    private func row(_ vial: Vial) -> some View {
        let journal = store.journal
        let compound = journal.compound(vial.compoundID)
        let remaining = journal.remaining(in: vial)
        let mixed = "\(Fmt.mass(vial.reconstitution.vial)) + \(Fmt.ml(vial.reconstitution.waterMl))"
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: compound?.name ?? "—").font(.headline)
                if model.loadedVialID == vial.id {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(PLColor.navy)
                }
            }
            Text(verbatim: mixed).font(.subheadline).foregroundStyle(.secondary)
            Text("\(Fmt.mass(remaining)) left").font(.subheadline)
            if let regimen = regimen(for: vial),
               let dose = regimen.dose.mass(compound?.iuConversion),
               let runOut = VialForecast.runOutDate(remaining: remaining, dose: dose, schedule: regimen.schedule,
                                                    after: Date(), calendar: .current) {
                Text("Runs out on \(runOut.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SaveVialSheet: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: CalculatorModel
    @State private var choice = CompoundChoice()
    @State private var mixedAt = Date()

    var body: some View {
        NavigationStack {
            Form {
                CompoundField(choice: $choice)
                DatePicker("Mixed on", selection: $mixedAt, displayedComponents: .date)
            }
            .navigationTitle("Save vial")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!choice.isValid || model.reconstitution == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let reconstitution = model.reconstitution else { return }
        let factor = model.iuConversion
        store.update { journal in
            let compoundID = choice.resolve(in: &journal)
            if let factor, var compound = journal.compound(compoundID), compound.iuConversion == nil {
                compound.iuConversion = factor
                journal.save(compound)
            }
            let vial = Vial(compoundID: compoundID, reconstitution: reconstitution,
                            syringe: model.syringe, mixedAt: mixedAt)
            journal.save(vial)
            model.load(vial, compound: journal.compound(compoundID), regimenDose: nil)
        }
        Analytics.track(.vialSaved)
        dismiss()
    }
}
