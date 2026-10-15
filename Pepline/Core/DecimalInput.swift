import Foundation

/// A parsed number field. `alternative` is set when the text has two honest
/// readings — "1,250" is 1250 in English and 1.25 in French — and the UI must
/// ask: picking the wrong one is a 1000× error on a dose.
struct ParsedDecimal: Equatable {
    var value: Decimal
    var alternative: Decimal? = nil
}

/// Parses what the user typed in a number field. Broken decimal input is a
/// top complaint against the category leaders, so this accepts both "0,25"
/// and "0.25" whatever the locale, grouping separators, spaces and the
/// full-width digits of Japanese/Chinese keyboards.
enum DecimalInput {
    static func parse(_ text: String, locale: Locale = .current) -> ParsedDecimal? {
        var s = String(String.UnicodeScalarView(text.unicodeScalars.map(halfwidth)))
        s.removeAll { $0.isWhitespace || $0 == "'" || $0 == "\u{2019}" }
        guard !s.isEmpty,
              s.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == "." || $0 == ",") }),
              s.contains(where: \.isNumber)
        else { return nil }

        let dots = s.filter { $0 == "." }.count
        let commas = s.filter { $0 == "," }.count

        switch (dots, commas) {
        case (0, 0):
            return number(s).map { ParsedDecimal(value: $0) }
        case (1, 0), (0, 1):
            let separator: Character = dots == 1 ? "." : ","
            let parts = s.split(separator: separator, omittingEmptySubsequences: false)
            let asDecimal = parts.joined(separator: ".")
            // "1,250": one to three digits (no leading zero), then exactly
            // three. Both readings are possible; the locale's wins and the
            // other is offered.
            let couldBeGrouping = (1...3).contains(parts[0].count) && parts[0].first != "0" && parts[1].count == 3
            guard couldBeGrouping else { return number(asDecimal).map { ParsedDecimal(value: $0) } }
            let asInteger = parts.joined()
            let localeGroups = String(separator) == locale.groupingSeparator
            return ParsedDecimal(value: number(localeGroups ? asInteger : asDecimal)!,
                                 alternative: number(localeGroups ? asDecimal : asInteger)!)
        case (_, 0), (0, _):
            // Same separator several times: grouping ("1.000.000").
            return groupedInteger(s, separator: dots > 0 ? "." : ",")
                .flatMap(number)
                .map { ParsedDecimal(value: $0) }
        default:
            // Both kinds: the last one is the decimal point and appears once.
            let decimalSeparator: Character = s.lastIndex(of: ".")! > s.lastIndex(of: ",")! ? "." : ","
            let groupingSeparator: Character = decimalSeparator == "." ? "," : "."
            let parts = s.split(separator: decimalSeparator, omittingEmptySubsequences: false)
            guard parts.count == 2, let integer = groupedInteger(String(parts[0]), separator: groupingSeparator)
            else { return nil }
            return number(integer + "." + parts[1]).map { ParsedDecimal(value: $0) }
        }
    }

    /// ASCII digits with at most one "." → Decimal. ".5" → 0.5, "5." → 5.
    private static func number(_ text: String) -> Decimal? {
        var padded = text.hasPrefix(".") ? "0" + text : text
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
