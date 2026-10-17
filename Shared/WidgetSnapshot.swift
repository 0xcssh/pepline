import Foundation

/// What the next-dose widget shows, written by the app into the App Group
/// after every change. Only the upcoming doses travel: the journal itself
/// stays in the app's own protected container.
struct WidgetSnapshot: Codable, Equatable {
    struct Dose: Codable, Equatable {
        var date: Date
        var compound: String
        /// Already formatted by the app ("250 mcg").
        var dose: String
        /// Units to draw on the syringe, formatted; nil without a vial.
        var units: String?
    }

    /// Time order, the first one possibly a little overdue.
    var doses: [Dose]

    static let appGroup = "group.com.awdia.pepline"

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("widget.json")
    }

    static func read() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(WidgetSnapshot.self, from: data)
    }

    func write() {
        guard let url = WidgetSnapshot.fileURL, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
