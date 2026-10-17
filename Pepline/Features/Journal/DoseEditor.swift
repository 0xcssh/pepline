import SwiftUI

/// Add or edit a logged dose. Everything can be changed afterwards — logging
/// on the wrong date and not being able to fix it is a top complaint against
/// the category leaders.
struct DoseEditor: View {
    struct Draft: Identifiable {
        let id: DoseEntry.ID
        let isNew: Bool
        var compound = CompoundChoice()
        var amountText = ""
        var unit = DoseUnit.mg
        var vialID: Vial.ID?
        var date = Date()
        var site: InjectionSite?
        var side: BodySide?
        var notes = ""

        init() {
            id = UUID()
            isNew = true
        }

        init(_ dose: DoseEntry) {
            id = dose.id
            isNew = false
            compound = CompoundChoice(existingID: dose.compoundID)
            amountText = Fmt.plain(dose.amount.value)
            unit = dose.amount.unit
            vialID = dose.vialID
            date = dose.date
            site = dose.site
            side = dose.side
            notes = dose.notes
        }

        /// Pre-filled from a schedule: compound, dose and its newest vial.
        /// `date` is the slot for a late log, so it answers that slot.
        init(regimen: Regimen, journal: Journal, date: Date = Date()) {
            self.init()
            self.date = date
            compound = CompoundChoice(existingID: regimen.compoundID)
            amountText = Fmt.plain(regimen.dose.value)
            unit = regimen.dose.unit
            vialID = journal.vials
                .filter { $0.compoundID == regimen.compoundID && !$0.isArchived }
                .max { $0.mixedAt < $1.mixedAt }?.id
        }
    }

    @EnvironmentObject private var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State var draft: Draft

    private var vials: [Vial] {
        guard let compoundID = draft.compound.existingID else { return [] }
        return store.journal.vials.filter { $0.compoundID == compoundID && !$0.isArchived }
    }

    /// Set after a NEW dose is saved: the editor turns into the reward screen.
    @State private var logged: DoseReward?

    private var canSave: Bool { draft.compound.isValid && (decimalValue(draft.amountText) ?? 0) > 0 }

    var body: some View {
        if let logged {
            DoseLoggedView(starCount: logged.stars, summary: logged.summary, dosesLeft: logged.dosesLeft,
                           next: logged.next) { dismiss() }
        } else {
            editor
        }
    }

    private var editor: some View {
        NavigationStack {
            Form {
                Section {
                    CompoundField(choice: $draft.compound)
                    DoseAmountField(text: $draft.amountText, unit: $draft.unit)
                    DatePicker("Date", selection: $draft.date)
                }

                if !vials.isEmpty {
                    Section {
                        Picker("Drawn from", selection: $draft.vialID) {
                            Text("No vial").tag(Vial.ID?.none)
                            ForEach(vials) { vial in
                                Text(verbatim: "\(Fmt.mass(vial.reconstitution.vial)) · \(vial.mixedAt.formatted(date: .abbreviated, time: .omitted))")
                                    .tag(Optional(vial.id))
                            }
                        }
                    }
                }

                Section {
                    // Body map: tap the zone; the least recently used one pulses.
                    BodyMapView(selection: Binding(
                        get: { draft.site.flatMap { site in draft.side.map { SiteZone(site: site, side: $0) } } },
                        set: { zone in
                            draft.site = zone?.site
                            draft.side = zone?.side
                        }
                    ), lastUse: SiteRotation.lastUse(in: store.journal, compoundID: draft.compound.existingID))
                    .padding(.vertical, 8)
                } header: {
                    Text("Injection site")
                } footer: {
                    if let compoundID = draft.compound.existingID,
                       let last = store.journal.lastSite(of: compoundID) {
                        Text("Last site: \(Fmt.site(last.site, last.side))")
                    }
                }

                Section("Notes") {
                    TextField("Notes", text: $draft.notes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if !draft.isNew {
                    Section {
                        Button("Delete this dose", role: .destructive) {
                            store.update { $0.deleteDose(draft.id) }
                            Analytics.track(.doseDeleted)
                            dismiss()
                        }
                    }
                }
            }
            .plScreen()
            .navigationTitle(draft.isNew ? Text("Log a dose") : Text("Edit dose"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave) }
            }
            .onChange(of: draft.compound) {
                if !vials.contains(where: { $0.id == draft.vialID }) { draft.vialID = nil }
            }
        }
    }

    private func save() {
        guard let value = decimalValue(draft.amountText) else { return }
        let draft = draft
        store.update { journal in
            let compoundID = draft.compound.resolve(in: &journal)
            journal.save(DoseEntry(id: draft.id, date: draft.date, compoundID: compoundID, vialID: draft.vialID,
                                   amount: DoseAmount(value: value, unit: draft.unit),
                                   site: draft.site, side: draft.site == nil ? nil : draft.side,
                                   notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        Analytics.track(.doseLogged, ["isNew": String(draft.isNew), "hasSite": String(draft.site != nil)])
        guard draft.isNew else { return dismiss() }

        guard let reward = DoseReward(after: draft.id, in: store.journal) else { return dismiss() }
        logged = reward
    }
}

/// What the reward screen says after a new dose: one star per dose of the
/// compound, full doses left in its vial, and the next dose still to take.
struct DoseReward: Identifiable {
    let id = UUID()
    var stars: Int
    var summary: String
    var dosesLeft: Int?
    var next: Date?

    init?(after doseID: DoseEntry.ID, in journal: Journal) {
        guard let saved = journal.doses.first(where: { $0.id == doseID }) else { return nil }
        let compound = journal.compound(saved.compoundID)
        stars = journal.doses(of: saved.compoundID).count
        summary = "\(compound?.name ?? "") · \(Fmt.dose(saved.amount))"
        dosesLeft = saved.vialID
            .flatMap { id in journal.vials.first { $0.id == id } }
            .flatMap { vial in saved.amount.mass(compound?.iuConversion)
                .map { VialForecast.dosesLeft(remaining: journal.remaining(in: vial), dose: $0) } }
        // The next dose not already logged (one logged early is not "next").
        next = Adherence.upcoming(in: journal, now: Date(), calendar: .current)
            .first { scheduled in journal.regimens.first { $0.id == scheduled.regimenID }?.compoundID == saved.compoundID }?
            .date
    }
}
