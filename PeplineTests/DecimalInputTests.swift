import XCTest
@testable import Pepline

final class DecimalInputTests: XCTestCase {
    private let en = Locale(identifier: "en_US")
    private let fr = Locale(identifier: "fr_FR")
    private let de = Locale(identifier: "de_DE")
    private let ja = Locale(identifier: "ja_JP")

    private func parse(_ text: String, _ locale: Locale) -> ParsedDecimal? {
        DecimalInput.parse(text, locale: locale)
    }

    /// Unambiguous result: the value, no alternative.
    private func exact(_ value: Decimal) -> ParsedDecimal { ParsedDecimal(value: value) }

    func testIntegers() {
        XCTAssertEqual(parse("5", en), exact(5))
        XCTAssertEqual(parse("250", fr), exact(250))
        XCTAssertEqual(parse(" 10 ", de), exact(10))
    }

    func testDotAndCommaBothWorkEverywhere() {
        for locale in [en, fr, de, ja] {
            XCTAssertEqual(parse("0.25", locale), exact(d("0.25")), "\(locale.identifier)")
            XCTAssertEqual(parse("0,25", locale), exact(d("0.25")), "\(locale.identifier)")
            XCTAssertEqual(parse("2,5", locale), exact(d("2.5")), "\(locale.identifier)")
            XCTAssertEqual(parse("1.2500", locale), exact(d("1.25")), "\(locale.identifier)")
        }
    }

    func testLeadingAndTrailingSeparator() {
        XCTAssertEqual(parse(".5", en), exact(d("0.5")))
        XCTAssertEqual(parse(",5", fr), exact(d("0.5")))
        XCTAssertEqual(parse("5.", en), exact(5))
    }

    func testThreeDigitsAfterOneSeparatorIsAmbiguous() {
        // The locale's reading first, the other one offered.
        XCTAssertEqual(parse("1,250", en), ParsedDecimal(value: 1250, alternative: d("1.25")))
        XCTAssertEqual(parse("1,250", fr), ParsedDecimal(value: d("1.25"), alternative: 1250))
        XCTAssertEqual(parse("1.000", de), ParsedDecimal(value: 1000, alternative: 1))
        XCTAssertEqual(parse("1.000", en), ParsedDecimal(value: 1, alternative: 1000))
        XCTAssertEqual(parse("2.500", fr), ParsedDecimal(value: d("2.5"), alternative: 2500))
        XCTAssertEqual(parse("1,250", ja), ParsedDecimal(value: 1250, alternative: d("1.25")))
    }

    func testNotAmbiguousWhenItCannotBeAGroup() {
        XCTAssertEqual(parse("0,250", en), exact(d("0.25")), "leading zero is never grouped")
        XCTAssertEqual(parse("1234,567", en), exact(d("1234.567")), "too many digits for a group")
        XCTAssertEqual(parse("1,25", en), exact(d("1.25")), "two digits is not a group")
        XCTAssertEqual(parse("1,2500", en), exact(d("1.25")), "four digits is not a group")
    }

    func testSpaceGrouping() {
        XCTAssertEqual(parse("1 000", fr), exact(1000))
        XCTAssertEqual(parse("1\u{202F}000,5", fr), exact(d("1000.5")))
        XCTAssertEqual(parse("1\u{00A0}000", fr), exact(1000))
    }

    func testRepeatedSeparatorIsGrouping() {
        XCTAssertEqual(parse("1,000,000", en), exact(1_000_000))
        XCTAssertEqual(parse("1.000.000", fr), exact(1_000_000))
        XCTAssertNil(parse("1.00.0", en))
        XCTAssertNil(parse("1234.000.000", en))
    }

    func testBothSeparators() {
        XCTAssertEqual(parse("1,000.5", en), exact(d("1000.5")))
        XCTAssertEqual(parse("1.000,5", de), exact(d("1000.5")))
        XCTAssertEqual(parse("1'000.5", Locale(identifier: "de_CH")), exact(d("1000.5")))
        XCTAssertNil(parse("1,2.3,4", en))
        XCTAssertNil(parse("1.0000,5", de))
    }

    func testFullWidthDigits() {
        XCTAssertEqual(parse("０．２５", ja), exact(d("0.25")))
        XCTAssertEqual(parse("２５０", Locale(identifier: "zh_Hans_CN")), exact(250))
    }

    func testRejectsGarbage() {
        for text in ["", "   ", ".", ",", "abc", "1a", "-5", "1e3", "5 mg", "1/2"] {
            XCTAssertNil(parse(text, en), "\"\(text)\"")
        }
    }
}
