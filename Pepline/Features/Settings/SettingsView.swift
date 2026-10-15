import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var deleting: Compound?

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight unit") {
                    Picker("Weight unit", selection: $unitSetting) {
                        Text(verbatim: UnitMass.kilograms.symbol).tag("kg")
                        Text(verbatim: UnitMass.pounds.symbol).tag("lb")
                    }
                    .pickerStyle(.segmented)
                }

                if !store.journal.compounds.isEmpty {
                    Section {
                        ForEach(store.journal.compounds.sorted { $0.name < $1.name }) { compound in
                            NavigationLink {
                                CompoundEditor(compound: compound)
                            } label: {
                                Text(verbatim: compound.name)
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { deleting = compound }
                            }
                        }
                    } header: {
                        Text("Compounds")
                    }
                }

                Section {
                    ShareLink(item: exportFile("pepline-doses.csv", CSVExport.doses(store.journal, timeZone: .current))) {
                        Label("Export doses (CSV)", systemImage: "square.and.arrow.up")
                    }
                    ShareLink(item: exportFile("pepline-weight.csv", CSVExport.weights(store.journal, timeZone: .current))) {
                        Label("Export weight (CSV)", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Export")
                }

                Section {
                    Link(destination: URL(string: "mailto:awdianthony@gmail.com?subject=Pepline")!) {
                        Label("Contact support", systemImage: "envelope")
                    }
                } footer: {
                    Text("Your data stays on this iPhone. No account, no cloud.")
                }

                Section {
                    DisclaimerText()
                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        Text(verbatim: "Pepline \(version)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog(
                Text("Delete \(deletingName)?"),
                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete it with its doses, vials and schedules", role: .destructive) {
                    if let id = deleting?.id { store.update { $0.deleteCompound(id) } }
                    deleting = nil
                }
            }
        }
    }

    private var deletingName: String { deleting?.name ?? "" }

    /// The CSV written to a temporary file so the share sheet sends a real
    /// .csv attachment (Mail, Files, Numbers).
    private func exportFile(_ name: String, _ contents: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

private struct CompoundEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var compound: Compound
    @State private var iuText: String

    init(compound: Compound) {
        _compound = State(initialValue: compound)
        _iuText = State(initialValue: compound.iuConversion.map { Fmt.plain($0.iuPerMg) } ?? "")
    }

    var body: some View {
        Form {
            TextField("Compound name", text: $compound.name)
            Section {
                DecimalField(title: "IU per mg (from the label)", text: $iuText)
            } footer: {
                Text("Only for compounds dosed in IU. Leave empty otherwise.")
            }
        }
        .navigationTitle(Text(verbatim: compound.name))
        .toolbar {
            Button("Save") {
                var edited = compound
                edited.name = edited.name.trimmingCharacters(in: .whitespaces)
                edited.iuConversion = decimalValue(iuText).map(IUConversion.init(iuPerMg:)).flatMap { $0.isValid ? $0 : nil }
                store.update { $0.save(edited) }
                dismiss()
            }
            .disabled(compound.name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
