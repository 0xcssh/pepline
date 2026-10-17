import Charts
import SwiftUI

/// Weight in the unit chosen in Settings; stored in kilograms.
enum WeightUnitSetting {
    static let key = "weightUnit"
    /// Default from the user's region: pounds where the US system is used.
    static var defaultValue: String { Locale.current.measurementSystem == .us ? "lb" : "kg" }

    static func unit(_ value: String) -> UnitMass { value == "lb" ? .pounds : .kilograms }
}

struct WeightView: View {
    @EnvironmentObject private var store: DataStore
    @AppStorage(WeightUnitSetting.key) private var unitSetting = WeightUnitSetting.defaultValue
    @State private var editing: WeightEditor.Draft?

    private var unit: UnitMass { WeightUnitSetting.unit(unitSetting) }

    var body: some View {
        List {
            let series = store.journal.weightSeries
            if series.count >= 2 {
                Section {
                    Chart(series) { entry in
                        let value = NSDecimalNumber(decimal: Fmt.weightValue(entry.kilograms, in: unit)).doubleValue
                        LineMark(x: .value("Date", entry.date), y: .value("Weight", value))
                            .foregroundStyle(PLColor.text)
                        PointMark(x: .value("Date", entry.date), y: .value("Weight", value))
                            .foregroundStyle(PLColor.text)
                        if let goal = store.journal.goalWeightKg {
                            RuleMark(y: .value("Goal", NSDecimalNumber(decimal: Fmt.weightValue(goal, in: unit)).doubleValue))
                                .foregroundStyle(PLColor.accent.opacity(0.4))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                        }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 220)
                    .padding(.vertical, 8)
                }
            }
            if series.isEmpty {
                Text("No weight logged yet. Tap + to add one.")
                    .foregroundStyle(.secondary)
            }
            ForEach(series.reversed()) { entry in
                Button { editing = WeightEditor.Draft(entry, unit: unit) } label: {
                    HStack {
                        Text(verbatim: entry.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(verbatim: Fmt.weight(entry.kilograms, in: unit)).monospacedDigit()
                    }
                }
                .tint(.primary)
                .swipeActions {
                    Button("Delete", role: .destructive) {
                        store.update { $0.deleteWeight(entry.id) }
                        HealthService.shared.delete(entryID: entry.id)
                    }
                }
            }
        }
        .plScreen()
        .navigationTitle("Weight")
        .toolbar {
            Button { editing = WeightEditor.Draft() } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Log weight"))
        }
        .sheet(item: $editing) { WeightEditor(draft: $0, unit: unit) }
    }
}

struct WeightEditor: View {
    struct Draft: Identifiable {
        let id: WeightEntry.ID
        let isNew: Bool
        var valueText = ""
        var date = Date()

        init() {
            id = UUID()
            isNew = true
        }

        init(_ entry: WeightEntry, unit: UnitMass) {
            id = entry.id
            isNew = false
            valueText = Fmt.plain(Fmt.weightValue(entry.kilograms, in: unit))
            date = entry.date
        }
    }

    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft
    let unit: UnitMass

    var body: some View {
        NavigationStack {
            Form {
                DecimalField(title: "Weight", text: $draft.valueText, unit: unit.symbol)
                DatePicker("Date", selection: $draft.date, displayedComponents: .date)
            }
            .plScreen()
            .navigationTitle(draft.isNew ? Text("Log weight") : Text("Edit weight"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled((decimalValue(draft.valueText) ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let value = decimalValue(draft.valueText) else { return }
        let entry = WeightEntry(id: draft.id, date: draft.date, kilograms: Fmt.kilograms(value, from: unit))
        store.update { $0.save(entry) }
        HealthService.shared.write(entry)
        Analytics.track(.weightLogged)
        dismiss()
    }
}
