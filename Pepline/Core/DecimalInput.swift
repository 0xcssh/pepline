import Foundation

/// Parses what the user typed in a number field. Broken decimal input is a
/// top complaint against the category leaders, so this accepts both "0,25"
/// and "0.25" whatever the locale, grouping separators, spaces and the
/// full-width digits of Japanese/Chinese keyboards.
enum DecimalInput {
    static func parse(_ text: String, locale: Locale = .current) -> Decimal? {
        var s = String(String.UnicodeScalarView(text.unicodeScalars.map(halfwidth)))
        s.removeAll { $0.isWhitespace || $0 == "'" || $0 == "\u{2019}" }
        guard !s.isEmpty,
              s.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }),
              s.contains(where: \.isNumber)
        else { return nil }

        let dots = s.filter { $0 == "." }.count
        let commas = s.filter { $0 == "," }.count
        let normalized: String?

        switch (dots, commas) {
        case (0, 0):
            normalized = s
        case (1, 0), (0, 1):
            let separator: Character = dots == 1 ? "." : ","
            let parts = s.split(separator: separator, omittingEmptySubsequences: false)
            // "1,000" in English is a thousand; anywhere else one separator is
            // the decimal point.
            let isGrouping = String(separator) == locale.groupingSeparator
                && (1...3).contains(parts[0].count) && parts[0].first != "0" && parts[1].count == 3
            normalized = isGrouping ? parts.joined() : parts.joined(separator: ".")
        case (_, 0), (0, _):
            // Same separator several times: grouping ("1.000.000").
            normalized = groupedInteger(s, separator: dots > 0 ? "." : ",")
        default:
            // Both kinds: the last one is the decimal point and appears once.
            let decimalSeparator: Character = s.lastIndex(of: ".")! > s.lastIndex(of: ",")! ? "." : ","
            let groupingSeparator: Character = decimalSeparator == "." ? "," : "."
            let parts = s.split(separator: decimalSeparator, omittingEmptySubsequences: false)
            if parts.count == 2, let integer = groupedInteger(String(parts[0]), separator: groupingSeparator) {
                normalized = integer + "." + parts[1]
            } else {
                normalized = nil
            }
        }

        guard let normalized else { return nil }
        // ".5" → "0.5", "5." → "5"
        var padded = normalized.hasPrefix(".") ? "0" + normalized : normalized
        if padded.hasSuffix(".") { padded.removeLast() }
        return Decimal(string: padded, locale: Locale(identifier: "en_US_POSIX"))
    }

    /// Full-width "０．２５" (U+FF01…U+FF5E) → ASCII "0.25".
    private static func halfwidth(_ scalar: Unicode.Scalar) -> Unicode.Scalar {
        guard (0xFF01...0xFF5E).contains(scalar.value) else { return scalar }
        return Unicode.Scalar(scalar.value - 0xFEE0)!
    }

    /// "1.000.000" → "1000000"; nil unless every group after the first has
    /// exactly three digits.
    private static func groupedInteger(_ s: String, separator: Character) -> String? {
        let groups = s.split(separator: separator, omittingEmptySubsequences: false)
        guard let first = groups.first, !first.isEmpty, first.count <= 3,
              groups.dropFirst().allSatisfy({ $0.count == 3 })
        else { return nil }
        return groups.joined()
    }
}
