import Foundation
import HealthKit

/// Optional Apple Health link for body weight only (Shotsy, MeAgain): read
/// past weigh-ins into the journal, write new ones to Health. Nothing else is
/// read or written; turned on from the Progress tab.
@MainActor
final class HealthService: ObservableObject {
    static let shared = HealthService()

    private let store = HKHealthStore()
    private let bodyMass = HKQuantityType(.bodyMass)

    @Published var isOn: Bool {
        didSet { UserDefaults.standard.set(isOn, forKey: "healthSync") }
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private init() {
        isOn = UserDefaults.standard.bool(forKey: "healthSync")
    }

    /// Asks for read and write access to body mass, then imports.
    func enable(into dataStore: DataStore) async {
        guard isAvailable else { return }
        do {
            try await store.requestAuthorization(toShare: [bodyMass], read: [bodyMass])
            isOn = true
            await importWeights(into: dataStore)
        } catch {
            isOn = false
        }
    }

    /// Weigh-ins of the last two years not already in the journal (same day
    /// and same value within 0.05 kg).
    func importWeights(into dataStore: DataStore) async {
        guard isOn, isAvailable else { return }
        let start = Calendar.current.date(byAdding: .year, value: -2, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
                                                 sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: store) else { return }
        let existing = dataStore.journal.weights
        let calendar = Calendar.current
        let new = samples.compactMap { sample -> WeightEntry? in
            let kg = Decimal(sample.quantity.doubleValue(for: .gramUnit(with: .kilo))).rounded(2)
            let duplicate = existing.contains {
                calendar.isDate($0.date, inSameDayAs: sample.startDate) && abs(NSDecimalNumber(decimal: $0.kilograms - kg).doubleValue) < 0.05
            }
            return duplicate ? nil : WeightEntry(date: sample.startDate, kilograms: kg)
        }
        guard !new.isEmpty else { return }
        dataStore.update { journal in new.forEach { journal.save($0) } }
        Analytics.track(.healthImported, ["count": String(new.count)])
    }

    /// Writes one weigh-in to Health when the link is on.
    func write(_ entry: WeightEntry) {
        guard isOn, isAvailable else { return }
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: NSDecimalNumber(decimal: entry.kilograms).doubleValue)
        let sample = HKQuantitySample(type: bodyMass, quantity: quantity, start: entry.date, end: entry.date)
        store.save(sample) { _, _ in }
    }
}
