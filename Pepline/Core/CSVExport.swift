import Foundation

/// CSV export (RFC 4180). The header and the values are data, not UI: English
/// column names, ISO 8601 dates and "." decimals whatever the user's locale,
/// so spreadsheets and doctors' tools read the same file everywhere.
enum CSVExport {
    static func doses(_ journal: Journal, timeZone: TimeZone) -> String {
        let header = ["date", "compound", "amount", "unit", "site", "side", "notes"]
        let rows = journal.doses.sorted { $0.date < $1.date }.map { dose in
            [
                iso8601(dose.date, timeZone),
                journal.compound(dose.compoundID)?.name ?? "",
                "\(dose.amount.value)",
                dose.amount.unit.rawValue,
                dose.site?.rawValue ?? "",
                dose.side?.rawValue ?? "",
                dose.notes,
            ]
        }
        return table([header] + rows)
    }

    static func weights(_ journal: Journal, timeZone: TimeZone) -> String {
        let rows = journal.weightSeries.map { [iso8601($0.date, timeZone), "\($0.kilograms)"] }
        return table([["date", "kg"]] + rows)
    }

    /// A field is quoted when it holds a comma, a quote or a line break;
    /// quotes inside are doubled. Lines end with CRLF.
    static func field(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func table(_ rows: [[String]]) -> String {
        rows.map { $0.map(field).joined(separator: ",") + "\r\n" }.joined()
    }

    private static func iso8601(_ date: Date, _ timeZone: TimeZone) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}
