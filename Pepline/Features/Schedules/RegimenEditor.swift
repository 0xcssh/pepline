import SwiftUI

/// The schedule the user's prescriber set. Pepline stores it and reminds;
/// it never proposes a dose or a schedule.
struct RegimenEditor: View {
    struct Draft: Identifiable {
        let id: Regimen.ID
        let isNew: Bool
        var compound = CompoundChoice()
        var amountText = ""
        var unit = DoseUnit.mg
        var kind = PatternKind.daily
        var everyN = 3
        var weekdays: Set<Int> = []
        var onDays = 5
        var offDays = 2
        var start = Date()
        var times: [Date] = [Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!]
        var remindersOn = true
        var reorderOn = true
        var reorderLeadDays = 7

        init() {
            id = UUID()
            isNew = true
        }

        init(_ regimen: Regimen) {
            id = regimen.id
            isNew = false
            compound = CompoundChoice(existingID: regimen.compoundID)
            amountText = Fmt.plain(regimen.dose.value)
            unit = regimen.dose.unit
            kind = PatternKind(regimen.schedule.pattern)
            switch regimen.schedule.pattern {
            case .everyNDays(let n): everyN = max(n, 3)
            case .weekdays(let days): weekdays = days
            case .cycle(let on, let off):
                onDays = on
                offDays = off
            }
            start = regimen.schedule.start
            times = regimen.schedule.times.sorted().compactMap {
                Calendar.current.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: Date())
            }
            remindersOn = regimen.remindersOn
            reorderOn = regimen.reorderLeadDays != nil
            reorderLeadDays = regimen.reorderLeadDays ?? 7
        }

        var pattern: DoseSchedule.Pattern {
            switch kind {
            case .daily: return .everyNDays(1)
            case .everyOtherDay: return .everyNDays(2)
            case .everyNDays: return .everyNDays(everyN)
            case .weekdays: return .weekdays(weekdays)
            case .cycle: return .cycle(onDays: onDays, offDays: offDays)
            }
        }

        var schedule: DoseSchedule {
            let calendar = Calendar.current
            let timesOfDay = Set(times.map {
                TimeOfDay(hour: calendar.component(.hour, from: $0), minute: calendar.component(.minute, from: $0))
            })
            return DoseSchedule(pattern: pattern, start: start, end: nil, times: timesOfDay.sorted())
        }
    }

    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft

    private var canSave: Bool {
        draft.compound.isValid && (decimalValue(draft.amountText) ?? 0) > 0 && draft.schedule.isValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CompoundField(choice: $draft.compound)
                    DoseAmountField(text: $draft.amountText, unit: $draft.unit)
                }

                Section("Repeat") {
                    Picker("Repeat", selection: $draft.kind) {
                        ForEach(PatternKind.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
                    }
                    switch draft.kind {
                    case .everyNDays:
                        Stepper(value: $draft.everyN, in: 3...60) {
                            Text("Every \(String(draft.everyN)) days")
                        }
                    case .weekdays:
                        WeekdayPicker(selection: $draft.weekdays)
                    case .cycle:
                        Stepper(value: $draft.onDays, in: 1...90) { Text("\(String(draft.onDays)) days on") }
                        Stepper(value: $draft.offDays, in: 0...90) { Text("\(String(draft.offDays)) days off") }
                    case .daily, .everyOtherDay:
                        EmptyView()
                    }
                    DatePicker("Starts", selection: $draft.start, displayedComponents: .date)
                }

                Section("Times") {
                    ForEach(draft.times.indices, id: \.self) { index in
                        // Bounds-checked binding: a row being deleted can
                        // still be read once with its old index.
                        DatePicker("Time", selection: Binding(
                            get: { draft.times.indices.contains(index) ? draft.times[index] : Date() },
                            set: { if draft.times.indices.contains(index) { draft.times[index] = $0 } }
                        ), displayedComponents: .hourAndMinute)
                    }
                    .onDelete { offsets in
                        if draft.times.count > offsets.count { draft.times.remove(atOffsets: offsets) }
                    }
                    Button("Add a time") {
                        draft.times.append(draft.times.last ?? Date())
                    }
                }

                Section {
                    Toggle("Dose reminders", isOn: $draft.remindersOn)
                    Toggle("Reorder reminder", isOn: $draft.reorderOn)
                    if draft.reorderOn {
                        Stepper(value: $draft.reorderLeadDays, in: 1...30) {
                            Text("\(String(draft.reorderLeadDays)) days before the vial runs out")
                        }
                    }
                } footer: {
                    Text("Pepline reminds you of the schedule you enter. It does not recommend doses or schedules.")
                }

                if !draft.isNew {
                    Section {
                        Button("Delete this schedule", role: .destructive) {
                            store.update { $0.deleteRegimen(draft.id) }
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(draft.isNew ? Text("New schedule") : Text("Edit schedule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave) }
            }
        }
    }

    private func save() {
        guard let value = decimalValue(draft.amountText) else { return }
        let draft = draft
        store.update { journal in
            let compoundID = draft.compound.resolve(in: &journal)
            journal.save(Regimen(id: draft.id, compoundID: compoundID,
                                 dose: DoseAmount(value: value, unit: draft.unit),
                                 schedule: draft.schedule, remindersOn: draft.remindersOn,
                                 reorderLeadDays: draft.reorderOn ? draft.reorderLeadDays : nil))
        }
        Analytics.track(.regimenSaved, [
            "pattern": String(describing: draft.kind),
            "times": String(draft.times.count),
            "reminders": String(draft.remindersOn),
            "reorder": String(draft.reorderOn),
        ])
        if draft.remindersOn || draft.reorderOn {
            Task {
                let granted = await NotificationScheduler.shared.requestPermission()
                Analytics.track(.notificationPermission, ["result": granted ? "granted" : "denied"])
                if granted { NotificationScheduler.shared.replan(store.journal) }
            }
        }
        dismiss()
    }
}

/// Seven round toggles in the user's week order and language.
private struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        let calendar = Calendar.current
        let ordered = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        HStack {
            ForEach(ordered, id: \.self) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(verbatim: calendar.veryShortWeekdaySymbols[day - 1])
                        .font(.subheadline.bold())
                        .frame(width: 36, height: 36)
                        .background(isOn ? PLColor.navy : Color.secondary.opacity(0.12), in: Circle())
                        .foregroundStyle(isOn ? .white : .primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: calendar.weekdaySymbols[day - 1]))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}
