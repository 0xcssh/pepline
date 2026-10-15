import Foundation

/// Everything the user saved, as one value. Persisted as a single JSON file
/// by `DataStore`; every edit is a pure function here so it can be tested.
struct Journal: Codable, Equatable {
    /// Bumped when the format changes in a way that needs a migration.
    static let currentVersion = 1

    var version = Journal.currentVersion
    var compounds: [Compound] = []
    var vials: [Vial] = []
    var doses: [DoseEntry] = []
    var regimens: [Regimen] = []
    var weights: [WeightEntry] = []
    /// Drawn as a line on the weight chart; set in onboarding or Settings.
    /// Optional fields decode as nil from older files: no migration needed.
    var goalWeightKg: Decimal?
    /// Syringe the calculator starts with (onboarding answer).
    var preferredSyringe: SyringeModel?

    // MARK: Edits — every entry can be added, edited and deleted.

    mutating func save(_ compound: Compound) { Journal.upsert(compound, in: &compounds) }
    mutating func save(_ vial: Vial) { Journal.upsert(vial, in: &vials) }
    mutating func save(_ dose: DoseEntry) { Journal.upsert(dose, in: &doses) }
    mutating func save(_ regimen: Regimen) { Journal.upsert(regimen, in: &regimens) }
    mutating func save(_ weight: WeightEntry) { Journal.upsert(weight, in: &weights) }

    mutating func deleteDose(_ id: DoseEntry.ID) { doses.removeAll { $0.id == id } }
    mutating func deleteRegimen(_ id: Regimen.ID) { regimens.removeAll { $0.id == id } }
    mutating func deleteWeight(_ id: WeightEntry.ID) { weights.removeAll { $0.id == id } }

    /// Deleting a vial keeps the doses drawn from it (they still happened);
    /// they just stop pointing at it.
    mutating func deleteVial(_ id: Vial.ID) {
        vials.removeAll { $0.id == id }
        for index in doses.indices where doses[index].vialID == id {
            doses[index].vialID = nil
        }
    }

    /// Deleting a compound deletes everything about it. The UI confirms first.
    mutating func deleteCompound(_ id: Compound.ID) {
        compounds.removeAll { $0.id == id }
        vials.removeAll { $0.compoundID == id }
        doses.removeAll { $0.compoundID == id }
        regimens.removeAll { $0.compoundID == id }
    }

    private static func upsert<T: Identifiable>(_ item: T, in array: inout [T]) {
        if let index = array.firstIndex(where: { $0.id == item.id }) {
            array[index] = item
        } else {
            array.append(item)
        }
    }

    // MARK: Queries

    func compound(_ id: Compound.ID) -> Compound? { compounds.first { $0.id == id } }

    /// Days with at least one dose, newest first; doses within a day in time order.
    func dosesByDay(calendar: Calendar) -> [(day: Date, doses: [DoseEntry])] {
        Dictionary(grouping: doses) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, doses: $0.value.sorted { $0.date < $1.date }) }
            .sorted { $0.day > $1.day }
    }

    /// One compound's doses, newest first.
    func doses(of compoundID: Compound.ID) -> [DoseEntry] {
        doses.filter { $0.compoundID == compoundID }.sorted { $0.date > $1.date }
    }

    /// What is left in a vial after the doses logged against it, never below
    /// zero. IU doses without a conversion factor cannot be subtracted and
    /// are ignored.
    func remaining(in vial: Vial) -> Mass {
        let conversion = compound(vial.compoundID)?.iuConversion
        let used = doses
            .filter { $0.vialID == vial.id }
            .compactMap { $0.amount.mass(conversion) }
            .reduce(Mass.zero, +)
        return max(vial.reconstitution.vial - used, .zero)
    }

    /// Where the last dose of a compound went — shown so the user can rotate
    /// sites; Pepline does not pick the next one.
    func lastSite(of compoundID: Compound.ID) -> (site: InjectionSite, side: BodySide?)? {
        guard let last = doses(of: compoundID).first(where: { $0.site != nil }) else { return nil }
        return (last.site!, last.side)
    }

    /// Weights oldest first, for the chart.
    var weightSeries: [WeightEntry] { weights.sorted { $0.date < $1.date } }
}
