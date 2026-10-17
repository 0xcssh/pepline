import Foundation
import Security

/// What the next-dose widget shows, written by the app after every change.
/// Only the upcoming doses travel: the journal itself stays in the app's
/// own protected container.
///
/// Shared through a keychain access group, not an App Group: provisioning
/// profiles already allow every `TEAMID.*` keychain group, while an App
/// Group has to be registered by hand in the developer portal (the App Store
/// Connect API cannot create one).
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

    /// "TEAMID." from Info.plist (`$(AppIdentifierPrefix)`), the same in the
    /// app and the widget; empty in unsigned simulator builds.
    private static var accessGroup: String? {
        guard let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String,
              !prefix.isEmpty else { return nil }
        return prefix + "com.awdia.pepline.shared"
    }

    private static func query() -> [String: Any]? {
        guard let group = accessGroup else { return nil }
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.awdia.pepline.widget",
            kSecAttrAccount as String: "snapshot",
            kSecAttrAccessGroup as String: group,
        ]
    }

    static func read() -> WidgetSnapshot? {
        guard var query = query() else { return nil }
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func write() {
        guard let query = WidgetSnapshot.query(), let data = try? JSONEncoder().encode(self) else { return }
        // Readable by the widget while the phone is locked, after the first
        // unlock since boot; never synced to iCloud or other devices.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        if SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil)
        }
    }
}
