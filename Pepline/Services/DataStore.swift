import Foundation

/// Owns the user's `Journal` and keeps it in one JSON file in Application
/// Support. On-device only: no account, no iCloud (App Review 5.1.3(ii)
/// forbids personal health information in iCloud for sync). The file is part
/// of the device backup like any app data.
@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published private(set) var journal: Journal

    /// Set when the file exists but cannot be read; the UI shows it instead
    /// of silently starting empty (and overwriting the user's data).
    @Published private(set) var loadError: Error?

    private let fileURL: URL

    init(fileURL: URL = DataStore.defaultURL) {
        self.fileURL = fileURL
        do {
            let data = try Data(contentsOf: fileURL)
            journal = try JSONDecoder().decode(Journal.self, from: data)
        } catch CocoaError.fileReadNoSuchFile {
            journal = Journal()
        } catch {
            journal = Journal()
            loadError = error
        }
    }

    static var defaultURL: URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("journal.json")
    }

    /// Apply an edit and write it to disk atomically.
    func update(_ edit: (inout Journal) -> Void) {
        // Never overwrite a file we failed to read.
        guard loadError == nil else { return }
        var copy = journal
        edit(&copy)
        guard copy != journal else { return }
        journal = copy
        persist()
        NotificationScheduler.shared.replan(journal)
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(journal)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            assertionFailure("Journal write failed: \(error)")
        }
    }
}
