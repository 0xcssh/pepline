import Foundation

/// Display formatting. Everything goes through the user's locale; nothing
/// here assumes a decimal separator or a language.
enum Fmt {
    /// "2.5", "2,5", "1 250,75"… with at most `digits` decimals.
    static func number(_ value: Decimal, digits: Int = 2) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)))
    }

    /// No grouping: what a number field can be set to without being ambiguous.
    static func plain(_ value: Decimal) -> String {
        let text = value.formatted(.number.grouping(.never).precision(.fractionLength(0...6)))
        // "1.125" also reads as 1125 (a thousands separator), so DecimalInput
        // asks; a trailing zero ("1.1250") makes what we write back unambiguous.
        return DecimalInput.parse(text)?.alternative == nil ? text : text + "0"
    }

    static func symbol(_ unit: DoseUnit) -> String {
        switch unit {
        case .mcg: return "mcg"
        case .mg: return "mg"
        case .iu: return String(localized: "IU", comment: "International Units, abbreviated")
        }
    }

    static func dose(_ amount: DoseAmount) -> String {
        "\(number(amount.value, digits: 3)) \(symbol(amount.unit))"
    }

    /// mg from 1 mg up, mcg below.
    static func mass(_ mass: Mass) -> String {
        mass.mcg >= 1000
            ? "\(number(mass.value(in: .mg), digits: 3)) mg"
            : "\(number(mass.mcg, digits: 1)) mcg"
    }

    /// Units to draw, the same everywhere (calculator, Today, reminders,
    /// widget): up to two decimals, as the calculator computes them.
    static func units(_ value: Decimal) -> String { number(value, digits: 2) }

    static func ml(_ value: Decimal) -> String { "\(number(value, digits: 3)) ml" }

    /// Water drunk: whole millilitres.
    static func water(_ milliliters: Decimal) -> String { "\(number(milliliters, digits: 0)) ml" }

    /// User's weight unit: kg or lb, from Settings (default from the locale).
    static func weight(_ kilograms: Decimal, in unit: UnitMass) -> String {
        let value = Measurement(value: NSDecimalNumber(decimal: kilograms).doubleValue, unit: UnitMass.kilograms)
            .converted(to: unit)
        return value.formatted(.measurement(width: .abbreviated, usage: .asProvided,
                                            numberFormatStyle: .number.precision(.fractionLength(0...1))))
    }

    /// Kilograms from a value typed in `unit` (Foundation's conversion; the
    /// pound is defined as exactly 0.45359237 kg — docs/SOURCES.md).
    static func kilograms(_ value: Decimal, from unit: UnitMass) -> Decimal {
        let kg = Measurement(value: NSDecimalNumber(decimal: value).doubleValue, unit: unit)
            .converted(to: .kilograms).value
        return Decimal(kg).rounded(3)
    }

    static func weightValue(_ kilograms: Decimal, in unit: UnitMass) -> Decimal {
        let value = Measurement(value: NSDecimalNumber(decimal: kilograms).doubleValue, unit: UnitMass.kilograms)
            .converted(to: unit).value
        return Decimal(value).rounded(1)
    }
}

extension Fmt {
    /// "Thigh · Left"
    static func site(_ site: InjectionSite, _ side: BodySide?) -> String {
        [site.label, side?.label].compactMap { $0 }.joined(separator: " · ")
    }
}

extension InjectionSite {
    var label: String {
        switch self {
        case .abdomen: return String(localized: "Abdomen")
        case .thigh: return String(localized: "Thigh")
        case .glute: return String(localized: "Glute")
        case .arm: return String(localized: "Arm")
        }
    }
}

extension BodySide {
    var label: String {
        switch self {
        case .left: return String(localized: "Left")
        case .right: return String(localized: "Right")
        }
    }
}

extension SyringeModel {
    /// "0.3 ml · ½ unit marks"
    var label: String {
        let size = Fmt.ml(capacityMl)
        let tick = Fmt.number(tickUnits, digits: 1)
        return String(localized: "\(size) · \(tick)-unit marks")
    }
}
