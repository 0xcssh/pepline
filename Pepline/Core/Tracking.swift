import Foundation

/// A scheduled dose the user chose to skip: shown as "skipped", not "missed".
struct SkippedDose: Codable, Hashable, Identifiable {
    var id = UUID()
    var regimenID: Regimen.ID
    /// The scheduled instant that was skipped.
    var scheduledAt: Date
}

// MARK: - Side effects

/// What GLP-1 trackers let people log (MeAgain, Shotsy, Pep AI); the user
/// logs what they feel, the app never interprets it.
struct SideEffectEntry: Codable, Hashable, Identifiable {
    enum Symptom: String, Codable, CaseIterable {
        case nausea, constipation, diarrhea, reflux, fatigue, headache, lowAppetite, injectionSite, other
    }

    var id = UUID()
    var date: Date
    var symptom: Symptom
    /// Free text for `.other`.
    var customName = ""
    /// 1 (mild) … 5 (severe), clamped.
    var severity: Int {
        didSet { severity = SideEffectEntry.clamp(severity) }
    }
    var notes = ""

    init(id: UUID = UUID(), date: Date, symptom: Symptom, customName: String = "", severity: Int, notes: String = "") {
        self.id = id
        self.date = date
        self.symptom = symptom
        self.customName = customName
        self.severity = SideEffectEntry.clamp(severity)
        self.notes = notes
    }

    static func clamp(_ value: Int) -> Int { min(max(value, 1), 5) }
}

// MARK: - Nutrition

enum FoodSource: String, Codable {
    case manual, search, barcode, photo
}

/// One serving of a food, as found or typed. Grams per serving.
struct FoodItem: Codable, Hashable {
    var name: String
    var kcal: Decimal = 0
    var protein: Decimal = 0
    var carbs: Decimal = 0
    var fat: Decimal = 0
    var fiber: Decimal = 0
    var source = FoodSource.manual
    var barcode: String?
}

struct FoodEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var item: FoodItem
    /// How many servings were eaten (0.5, 1, 2…).
    var servings: Decimal = 1
}

struct WaterEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    var milliliters: Decimal
}

/// Targets the user sets themselves; Pepline suggests none.
struct NutritionGoals: Codable, Hashable {
    var kcal: Decimal?
    var protein: Decimal?
    var fiber: Decimal?
    var waterMl: Decimal?
}

struct NutritionTotals: Hashable {
    var kcal: Decimal = 0
    var protein: Decimal = 0
    var carbs: Decimal = 0
    var fat: Decimal = 0
    var fiber: Decimal = 0
    var waterMl: Decimal = 0
}

// MARK: - Progress photos

/// A photo stored in the app sandbox; only its metadata lives in the journal.
struct ProgressPhoto: Codable, Hashable, Identifiable {
    var id = UUID()
    var date: Date
    /// File name inside the app's photos folder.
    var fileName: String
}

extension Journal {
    /// Food and water of one day, summed.
    func nutrition(on day: Date, calendar: Calendar) -> NutritionTotals {
        var totals = NutritionTotals()
        for entry in foods where calendar.isDate(entry.date, inSameDayAs: day) {
            totals.kcal += entry.item.kcal * entry.servings
            totals.protein += entry.item.protein * entry.servings
            totals.carbs += entry.item.carbs * entry.servings
            totals.fat += entry.item.fat * entry.servings
            totals.fiber += entry.item.fiber * entry.servings
        }
        for entry in water where calendar.isDate(entry.date, inSameDayAs: day) {
            totals.waterMl += entry.milliliters
        }
        return totals
    }

    /// Foods of one day, in time order.
    func foods(on day: Date, calendar: Calendar) -> [FoodEntry] {
        foods.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    /// Distinct foods logged before, most recent first, for one-tap re-logging.
    func recentFoods(limit: Int = 12) -> [FoodItem] {
        var seen = Set<String>()
        var items: [FoodItem] = []
        for entry in foods.sorted(by: { $0.date > $1.date }) where seen.insert(entry.item.name.lowercased()).inserted {
            items.append(entry.item)
            if items.count == limit { break }
        }
        return items
    }

    /// Side effects of one day, in time order.
    func sideEffects(on day: Date, calendar: Calendar) -> [SideEffectEntry] {
        sideEffects.filter { calendar.isDate($0.date, inSameDayAs: day) }.sorted { $0.date < $1.date }
    }

    /// Photos oldest first.
    var photoSeries: [ProgressPhoto] { photos.sorted { $0.date < $1.date } }
}
