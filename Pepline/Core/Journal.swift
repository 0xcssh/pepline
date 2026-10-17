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
    /// Scheduled doses the user chose to skip (they are not "missed").
    var skippedDoses: [SkippedDose] = []
    var sideEffects: [SideEffectEntry] = []
    var foods: [FoodEntry] = []
    var favoriteFoods: [FoodItem] = []
    var water: [WaterEntry] = []
    var nutritionGoals = NutritionGoals()
    var photos: [ProgressPhoto] = []

    // MARK: Edits — every entry can be added, edited and deleted.

    mutating func save(_ compound: Compound) { Journal.upsert(compound, in: &compounds) }
    mutating func save(_ vial: Vial) { Journal.upsert(vial, in: &vials) }
    mutating func save(_ dose: DoseEntry) { Journal.upsert(dose, in: &doses) }
    mutating func save(_ regimen: Regimen) { Journal.upsert(regimen, in: &regimens) }
    mutating func save(_ weight: WeightEntry) { Journal.upsert(weight, in: &weights) }
    mutating func save(_ skipped: SkippedDose) { Journal.upsert(skipped, in: &skippedDoses) }
    mutating func save(_ entry: SideEffectEntry) { Journal.upsert(entry, in: &sideEffects) }
    mutating func save(_ entry: FoodEntry) { Journal.upsert(entry, in: &foods) }
    mutating func save(_ entry: WaterEntry) { Journal.upsert(entry, in: &water) }
    mutating func save(_ photo: ProgressPhoto) { Journal.upsert(photo, in: &photos) }

    mutating func deleteSkipped(_ id: SkippedDose.ID) { skippedDoses.removeAll { $0.id == id } }
    mutating func deleteSideEffect(_ id: SideEffectEntry.ID) { sideEffects.removeAll { $0.id == id } }
    mutating func deleteFood(_ id: FoodEntry.ID) { foods.removeAll { $0.id == id } }
    mutating func deleteWater(_ id: WaterEntry.ID) { water.removeAll { $0.id == id } }
    mutating func deletePhoto(_ id: ProgressPhoto.ID) { photos.removeAll { $0.id == id } }

    /// Adds the item to the favourites, or removes it when already there.
    mutating func toggleFavorite(_ item: FoodItem) {
        if let index = favoriteFoods.firstIndex(where: { $0.name == item.name }) {
            favoriteFoods.remove(at: index)
        } else {
            favoriteFoods.append(item)
        }
    }

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

// Decoding by hand so files written by older versions (without the newer
// collections) still load: every field falls back to its default. Kept in
// an extension so the memberwise and empty initialisers stay synthesised.
extension Journal {
    private enum CodingKeys: String, CodingKey {
        case version, compounds, vials, doses, regimens, weights, goalWeightKg, preferredSyringe
        case skippedDoses, sideEffects, foods, favoriteFoods, water, nutritionGoals, photos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Journal.currentVersion
        compounds = try c.decodeIfPresent([Compound].self, forKey: .compounds) ?? []
        vials = try c.decodeIfPresent([Vial].self, forKey: .vials) ?? []
        doses = try c.decodeIfPresent([DoseEntry].self, forKey: .doses) ?? []
        regimens = try c.decodeIfPresent([Regimen].self, forKey: .regimens) ?? []
        weights = try c.decodeIfPresent([WeightEntry].self, forKey: .weights) ?? []
        goalWeightKg = try c.decodeIfPresent(Decimal.self, forKey: .goalWeightKg)
        preferredSyringe = try c.decodeIfPresent(SyringeModel.self, forKey: .preferredSyringe)
        skippedDoses = try c.decodeIfPresent([SkippedDose].self, forKey: .skippedDoses) ?? []
        sideEffects = try c.decodeIfPresent([SideEffectEntry].self, forKey: .sideEffects) ?? []
        foods = try c.decodeIfPresent([FoodEntry].self, forKey: .foods) ?? []
        favoriteFoods = try c.decodeIfPresent([FoodItem].self, forKey: .favoriteFoods) ?? []
        water = try c.decodeIfPresent([WaterEntry].self, forKey: .water) ?? []
        nutritionGoals = try c.decodeIfPresent(NutritionGoals.self, forKey: .nutritionGoals) ?? NutritionGoals()
        photos = try c.decodeIfPresent([ProgressPhoto].self, forKey: .photos) ?? []
    }
}
