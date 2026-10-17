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

    /// Health samples already seen by an import: a weigh-in deleted in
    /// Pepline is not brought back by the next one.
    private var seenSamples: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "healthSeenSamples") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "healthSeenSamples") }
    }

    /// The sample Pepline wrote for each journal entry, so an edit replaces
    /// it and a delete removes it instead of leaving duplicates in Health.
    private var writtenSamples: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: "healthWrittenSamples") as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: "healthWrittenSamples") }
    }

    /// Weigh-ins of the last two years from other apps and devices, each
    /// imported once, skipping any already in the journal (same day and same
    /// value within 0.05 kg). Pepline's own samples are never read back.
    func importWeights(into dataStore: DataStore) async {
        guard isOn, isAvailable else { return }
        let start = Calendar.current.date(byAdding: .year, value: -2, to: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        let descriptor = HKSampleQueryDescriptor(predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
                                                 sortDescriptors: [SortDescriptor(\.startDate)])
        guard let samples = try? await descriptor.result(for: store) else { return }
        let existing = dataStore.journal.weights
        let calendar = Calendar.current
        let ownBundle = Bundle.main.bundleIdentifier
        var seen = seenSamples
        let fresh = samples.filter { sample in
            sample.sourceRevision.source.bundleIdentifier != ownBundle && seen.insert(sample.uuid.uuidString).inserted
        }
        seenSamples = seen
        let new = fresh.compactMap { sample -> WeightEntry? in
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

    /// Writes one weigh-in to Health when the link is on, replacing the
    /// sample written for the same entry before (an edit).
    func write(_ entry: WeightEntry) {
        guard isOn, isAvailable else { return }
        delete(entryID: entry.id)
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: NSDecimalNumber(decimal: entry.kilograms).doubleValue)
        let sample = HKQuantitySample(type: bodyMass, quantity: quantity, start: entry.date, end: entry.date)
        writtenSamples[entry.id.uuidString] = sample.uuid.uuidString
        store.save(sample) { _, _ in }
    }

    /// Removes from Health the sample Pepline wrote for this entry, if any.
    func delete(entryID: WeightEntry.ID) {
        guard let uuidString = writtenSamples[entryID.uuidString], let uuid = UUID(uuidString: uuidString) else { return }
        writtenSamples[entryID.uuidString] = nil
        guard isAvailable else { return }
        store.deleteObjects(of: bodyMass, predicate: HKQuery.predicateForObject(with: uuid)) { _, _, _ in }
    }
}
