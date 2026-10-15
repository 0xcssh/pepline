import SwiftUI

struct JournalView: View {
    private enum Grouping: Hashable { case day, compound }

    @EnvironmentObject private var store: DataStore
    @State private var grouping = Grouping.day
    @State private var editing: DoseEditor.Draft?

    var body: some View {
        List {
            Picker("Group by", selection: $grouping) {
                Text("By day").tag(Grouping.day)
                Text("By compound").tag(Grouping.compound)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            if store.journal.doses.isEmpty {
                Text("No doses logged yet. Tap + to log one.")
                    .foregroundStyle(.secondary)
            } else if grouping == .day {
                ForEach(store.journal.dosesByDay(calendar: .current), id: \.day) { day in
                    Section {
                        rows(day.doses)
                    } header: {
                        Text(day.day.formatted(date: .complete, time: .omitted))
                    }
                }
            } else {
                ForEach(store.journal.compounds.sorted { $0.name < $1.name }) { compound in
                    let doses = store.journal.doses(of: compound.id)
                    if !doses.isEmpty {
                        Section {
                            rows(doses, showDate: true)
                        } header: {
                            Text(verbatim: compound.name)
                        }
                    }
                }
            }
        }
        .plScreen()
        .navigationTitle("Journal")
        .toolbar {
            Button { editing = DoseEditor.Draft() } label: { Image(systemName: "plus") }
                .accessibilityLabel(Text("Log a dose"))
        }
        .sheet(item: $editing) { draft in
            DoseEditor(draft: draft)
        }
    }

    private func rows(_ doses: [DoseEntry], showDate: Bool = false) -> some View {
        ForEach(doses) { dose in
            Button { editing = DoseEditor.Draft(dose) } label: {
                DoseRow(dose: dose, showDate: showDate)
            }
            .tint(.primary)
            .swipeActions {
                Button("Delete", role: .destructive) {
                    store.update { $0.deleteDose(dose.id) }
                }
            }
        }
    }
}

struct DoseRow: View {
    @EnvironmentObject private var store: DataStore
    let dose: DoseEntry
    var showDate = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: store.journal.compound(dose.compoundID)?.name ?? "—").font(.headline)
                if let site = dose.site {
                    Text(verbatim: Fmt.site(site, dose.side))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !dose.notes.isEmpty {
                    Text(verbatim: dose.notes)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(verbatim: Fmt.dose(dose.amount)).font(.headline).monospacedDigit()
                Text(verbatim: showDate
                     ? dose.date.formatted(date: .abbreviated, time: .shortened)
                     : dose.date.formatted(date: .omitted, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
