import XCTest
@testable import Pepline

final class FoodDataTests: XCTestCase {
    private func data(_ json: String) -> Data { Data(json.utf8) }

    func testLookupUsesServingWhenGiven() {
        let json = #"""
        {"status":1,"product":{"product_name":" Protein bar ","serving_size":"60 g",
         "nutriments":{"energy-kcal_100g":380,"energy-kcal_serving":228,"proteins_serving":"20.04",
                       "carbohydrates_serving":18,"fat_serving":7.5,"fiber_serving":4}}}
        """#
        let item = FoodData.item(fromLookup: data(json), barcode: "123")
        XCTAssertEqual(item, FoodItem(name: "Protein bar (60 g)", kcal: 228, protein: 20, carbs: 18, fat: d("7.5"),
                                      fiber: 4, source: .barcode, barcode: "123"))
    }

    func testLookupFallsBackTo100g() {
        let json = #"{"status":1,"product":{"product_name":"Skyr","nutriments":{"energy-kcal_100g":63,"proteins_100g":11}}}"#
        let item = FoodData.item(fromLookup: data(json), barcode: "9")
        XCTAssertEqual(item?.name, "Skyr (100 g)")
        XCTAssertEqual(item?.protein, 11)
        XCTAssertEqual(item?.fiber, 0)
        // A serving size without per-serving values still uses 100 g.
        let noServingValues = #"{"status":1,"product":{"product_name":"Oats","serving_size":"40 g","nutriments":{"energy-kcal_100g":370}}}"#
        XCTAssertEqual(FoodData.item(fromLookup: data(noServingValues), barcode: "1")?.name, "Oats (100 g)")
    }

    func testLookupRejectsUnknownOrEmptyProducts() {
        XCTAssertNil(FoodData.item(fromLookup: data(#"{"status":0}"#), barcode: "1"))
        XCTAssertNil(FoodData.item(fromLookup: data("not json"), barcode: "1"))
        XCTAssertNil(FoodData.item(fromLookup: data(#"{"status":1,"product":{"product_name":"","nutriments":{}}}"#), barcode: "1"))
        XCTAssertNil(FoodData.item(fromLookup: data(#"{"status":1,"product":{"nutriments":{"energy-kcal_100g":50}}}"#), barcode: "1"))
        XCTAssertNil(FoodData.item(fromLookup: data(#"{"status":1,"product":{"product_name":"Water"}}"#), barcode: "1"))
        XCTAssertNil(FoodData.item(fromLookup: data(#"{"status":1,"product":{"product_name":"Water","nutriments":{"energy-kcal_100g":0}}}"#), barcode: "1"))
    }

    func testSearchResults() {
        let json = #"""
        {"products":[{"code":"111","product_name":"Greek yogurt","nutriments":{"energy-kcal_100g":97,"proteins_100g":9}},
                     {"code":"222","product_name":"","nutriments":{"energy-kcal_100g":50}},
                     {"code":"333","product_name":"Tuna","nutriments":{"energy-kcal_100g":"116","proteins_100g":"x"}}]}
        """#
        let items = FoodData.items(fromSearch: data(json))
        XCTAssertEqual(items.map(\.name), ["Greek yogurt (100 g)", "Tuna (100 g)"])
        XCTAssertEqual(items[0].barcode, "111")
        XCTAssertEqual(items[0].source, .search)
        XCTAssertEqual(items[1].kcal, 116)
        XCTAssertEqual(items[1].protein, 0, "unreadable value counts as 0")
        XCTAssertTrue(FoodData.items(fromSearch: data("[]")).isEmpty)
    }

    func testScanResults() {
        let json = #"""
        {"items":[{"name":"Grilled chicken","kcal":248.04,"protein":46.4,"carbs":0,"fat":5.4,"fiber":0},
                  {"name":"  ","kcal":10},
                  {"name":"Rice","kcal":205,"protein":-1}]}
        """#
        let items = FoodData.items(fromScan: data(json))
        XCTAssertEqual(items.map(\.name), ["Grilled chicken", "Rice"])
        XCTAssertEqual(items[0].kcal, d("248"))
        XCTAssertEqual(items[0].source, .photo)
        XCTAssertEqual(items[1].protein, 0, "negative estimates are clamped")
        XCTAssertEqual(items[1].fiber, 0, "missing values are 0")
        XCTAssertTrue(FoodData.items(fromScan: data("{}")).isEmpty)
    }
}
