import XCTest
@testable import Pepline

final class DecimalInputTests: XCTestCase {
    private let en = Locale(identifier: "en_US")
    private let fr = Locale(identifier: "fr_FR")
    private let de = Locale(identifier: "de_DE")

    private func parse(_ text: String, _ locale: Locale) -> Decimal? {
        DecimalInput.parse(text, locale: locale)
    }

    func testIntegers() {
        XCTAssertEqual(parse("5", en), 5)
        XCTAssertEqual(parse("250", fr), 250)
        XCTAssertEqual(parse(" 10 ", de), 10)
    }

    func testDotAndCommaBothWorkEverywhere() {
        for locale in [en, fr, de] {
            XCTAssertEqual(parse("0.25", locale), d("0.25"), "\(locale.identifier)")
            XCTAssertEqual(parse("0,25", locale), d("0.25"), "\(locale.identifier)")
            XCTAssertEqual(parse("2,5", locale), d("2.5"), "\(locale.identifier)")
        }
    }

    func testLeadingAndTrailingSeparator() {
        XCTAssertEqual(parse(".5", en), d("0.5"))
        XCTAssertEqual(parse(",5", fr), d("0.5"))
        XCTAssertEqual(parse("5.", en), 5)
    }

    func testThreeDigitsAfterTheLocaleGroupingSeparatorIsAThousand() {
        XCTAssertEqual(parse("1,000", en), 1000)
        XCTAssertEqual(parse("1.000", de), 1000)
        // Not the locale's grouping separator: decimal.
        XCTAssertEqual(parse("1,000", de), 1)
        XCTAssertEqual(parse("1.000", en), 1)
        XCTAssertEqual(parse("0,250", en), d("0.25"), "leading zero is never grouped")
        XCTAssertEqual(parse("1234,567", en), d("1234.567"), "too many digits to be a group")
    }

    func testFrenchSpaceGrouping() {
        XCTAssertEqual(parse("1 000", fr), 1000)
        XCTAssertEqual(parse("1\u{202F}000,5", fr), d("1000.5"))
        XCTAssertEqual(parse("1\u{00A0}000", fr), 1000)
    }

    func testRepeatedSeparatorIsGrouping() {
        XCTAssertEqual(parse("1,000,000", en), 1_000_000)
        XCTAssertEqual(parse("1.000.000", fr), 1_000_000)
        XCTAssertNil(parse("1.00.0", en))
        XCTAssertNil(parse("1234.000.000", en))
    }

    func testBothSeparators() {
        XCTAssertEqual(parse("1,000.5", en), d("1000.5"))
        XCTAssertEqual(parse("1.000,5", de), d("1000.5"))
        XCTAssertEqual(parse("1'000.5", Locale(identifier: "de_CH")), d("1000.5"))
        XCTAssertNil(parse("1,2.3,4", en))
        XCTAssertNil(parse("1.0000,5", de))
    }

    func testFullWidthDigits() {
        XCTAssertEqual(parse("０．２５", Locale(identifier: "ja_JP")), d("0.25"))
        XCTAssertEqual(parse("２５０", Locale(identifier: "zh_Hans_CN")), 250)
    }

    func testRejectsGarbage() {
        for text in ["", "   ", ".", ",", "abc", "1a", "-5", "1e3", "5 mg", "1/2"] {
            XCTAssertNil(parse(text, en), "\"\(text)\"")
        }
    }
}
