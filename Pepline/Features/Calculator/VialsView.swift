import SwiftUI

/// Every saved vial: archive or bring back, delete (its doses stay logged,
/// without the vial link), see what is left.
struct VialsView: View {
    @EnvironmentObject private var store: DataStore
    @State private var deleting: Vial?

    private var active: [Vial] { store.journal.vials.filter { !$0.isArchived }.sorted { $0.mixedAt > $1.mixedAt } }
    private var archived: [Vial] { store.journal.vials.filter(\.isArchived).sorted { $0.mixedAt > $1.mixedAt } }

    var body: some View {
        List {
            if store.journal.vials.isEmpty {
                Text("No saved vial yet. Save one from the calculator.")
                    .foregroundStyle(PLColor.muted)
            }
            if !active.isEmpty {
                Section { ForEach(active, content: row) } header: { Text("In use") }
            }
            if !archived.isEmpty {
                Section { ForEach(archived, content: row) } header: { Text("Archived") }
            }
        }
        .plScreen()
        .navigationTitle(Text("Saved vials"))
        .confirmationDialog(Text("Delete this vial?"),
                            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deleting?.id { store.update { $0.deleteVial(id) } }
                deleting = nil
            }
        } message: {
            Text("The doses drawn from it stay in your journal.")
        }
    }

    private func row(_ vial: Vial) -> some View {
        let journal = store.journal
        return VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: journal.compound(vial.compoundID)?.name ?? "—").font(.headline)
            Text(verbatim: "\(Fmt.mass(vial.reconstitution.vial)) + \(Fmt.ml(vial.reconstitution.waterMl)) · \(vial.syringe.label)")
                .font(.subheadline)
                .foregroundStyle(PLColor.muted)
            HStack {
                Text("\(Fmt.mass(journal.remaining(in: vial))) left")
                Spacer()
                Text(vial.mixedAt, format: .dateTime.day().month(.abbreviated).year())
                    .foregroundStyle(PLColor.muted)
            }
            .font(.footnote)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { deleting = vial } label: {
                Label { Text("Delete") } icon: { Image(systemName: "trash") }
            }
            Button { toggleArchive(vial) } label: {
                vial.isArchived
                    ? Label { Text("Restore") } icon: { Image(systemName: "arrow.uturn.backward") }
                    : Label { Text("Archive") } icon: { Image(systemName: "archivebox") }
            }
            .tint(PLColor.accent)
        }
    }

    private func toggleArchive(_ vial: Vial) {
        store.update { journal in
            var updated = vial
            updated.isArchived.toggle()
            journal.save(updated)
        }
    }
}
