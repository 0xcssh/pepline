import SwiftUI

/// Edits one food before it is logged: name, macros per serving, servings
/// eaten and time. Found, scanned and estimated values are always editable.
/// With `onDone` the edited entry is handed back instead of saved.
struct FoodEditor: View {
    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    let original: FoodEntry
    var isNew: Bool
    var onDone: ((FoodEntry) -> Void)?

    @State private var name: String
    @State private var kcal: String
    @State private var protein: String
    @State private var carbs: String
    @State private var fat: String
    @State private var fiber: String
    @State private var servings: String
    @State private var date: Date

    init(entry: FoodEntry, isNew: Bool, onDone: ((FoodEntry) -> Void)? = nil) {
        original = entry
        self.isNew = isNew
        self.onDone = onDone
        _name = State(initialValue: entry.item.name)
        _kcal = State(initialValue: Fmt.plain(entry.item.kcal))
        _protein = State(initialValue: Fmt.plain(entry.item.protein))
        _carbs = State(initialValue: Fmt.plain(entry.item.carbs))
        _fat = State(initialValue: Fmt.plain(entry.item.fat))
        _fiber = State(initialValue: Fmt.plain(entry.item.fiber))
        _servings = State(initialValue: Fmt.plain(entry.servings))
        _date = State(initialValue: entry.date)
    }

    private var edited: FoodEntry? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let servingsValue = decimalValue(servings), servingsValue > 0 else { return nil }
        var item = original.item
        item.name = trimmed
        let fields: [(WritableKeyPath<FoodItem, Decimal>, String)] =
            [(\.kcal, kcal), (\.protein, protein), (\.carbs, carbs), (\.fat, fat), (\.fiber, fiber)]
        for (keyPath, text) in fields {
            if text.trimmingCharacters(in: .whitespaces).isEmpty {
                item[keyPath: keyPath] = 0
            } else if let value = decimalValue(text), value >= 0 {
                item[keyPath: keyPath] = value
            } else {
                return nil
            }
        }
        var entry = original
        entry.item = item
        entry.servings = servingsValue
        entry.date = date
        return entry
    }

    private var isFavorite: Bool { store.journal.favoriteFoods.contains { $0.name == original.item.name } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food", text: $name)
                    if original.item.source == .photo {
                        Label { Text("AI estimate: check the values before saving.") } icon: {
                            Image(systemName: "sparkles")
                        }
                        .font(.footnote)
                        .foregroundStyle(PLColor.warning)
                    }
                }
                Section {
                    DecimalField(title: "Calories", text: $kcal, unit: "kcal")
                    DecimalField(title: "Protein", text: $protein, unit: "g")
                    DecimalField(title: "Carbs", text: $carbs, unit: "g")
                    DecimalField(title: "Fat", text: $fat, unit: "g")
                    DecimalField(title: "Fiber", text: $fiber, unit: "g")
                } header: {
                    Text("Per serving")
                }
                Section {
                    DecimalField(title: "Servings", text: $servings)
                    DatePicker("When", selection: $date)
                }
                if onDone == nil {
                    Section {
                        Button {
                            store.update { $0.toggleFavorite(original.item) }
                        } label: {
                            isFavorite
                                ? Label { Text("Remove from favorites") } icon: { Image(systemName: "star.slash") }
                                : Label { Text("Add to favorites") } icon: { Image(systemName: "star") }
                        }
                        if !isNew {
                            Button(role: .destructive) {
                                store.update { $0.deleteFood(original.id) }
                                dismiss()
                            } label: {
                                Label { Text("Delete") } icon: { Image(systemName: "trash") }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PLBackground())
            .navigationTitle(isNew ? Text("Add food") : Text("Edit food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(edited == nil)
                }
            }
        }
    }

    private func save() {
        guard let entry = edited else { return }
        if let onDone {
            onDone(entry)
        } else {
            store.update { $0.save(entry) }
            if isNew { Analytics.track(.foodLogged, ["source": entry.item.source.rawValue]) }
        }
        dismiss()
    }
}
