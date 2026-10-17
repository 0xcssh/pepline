import Foundation

/// Turns Open Food Facts product JSON (api/v2/product and cgi/search.pl
/// results) and the photo-scan server's JSON into `FoodItem`s. Pure, so the
/// parsing is tested without a network.
///
/// Open Food Facts data: Open Database License (ODbL) — attribution shown in
/// Settings; docs/SOURCES.md § Nutrition data.
enum FoodData {
    /// One product object (the `product` of a v2 lookup, or an element of a
    /// search's `products`). Per serving when the label gives a serving,
    /// otherwise per 100 g. Nil without a name or any nutrient.
    static func item(fromProduct product: [String: Any], barcode: String? = nil, source: FoodSource) -> FoodItem? {
        let name = (product["product_name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty, let nutriments = product["nutriments"] as? [String: Any] else { return nil }
        let serving = (product["serving_size"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let suffix = serving != nil && nutriments["energy-kcal_serving"] != nil ? "_serving" : "_100g"
        func value(_ key: String) -> Decimal {
            let raw = nutriments[key + suffix]
            if let number = raw as? NSNumber { return Decimal(number.doubleValue).rounded(1) }
            if let text = raw as? String, let number = Double(text) { return Decimal(number).rounded(1) }
            return 0
        }
        let label = suffix == "_serving" ? "\(name) (\(serving!))" : "\(name) (100 g)"
        let item = FoodItem(name: label, kcal: value("energy-kcal"), protein: value("proteins"),
                            carbs: value("carbohydrates"), fat: value("fat"), fiber: value("fiber"),
                            source: source, barcode: barcode ?? (product["code"] as? String))
        return item.kcal + item.protein + item.carbs + item.fat > 0 ? item : nil
    }

    /// `api/v2/product/{code}` response.
    static func item(fromLookup data: Data, barcode: String) -> FoodItem? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (json["status"] as? Int) == 1,
              let product = json["product"] as? [String: Any]
        else { return nil }
        return item(fromProduct: product, barcode: barcode, source: .barcode)
    }

    /// `cgi/search.pl?json=1` response.
    static func items(fromSearch data: Data) -> [FoodItem] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = json["products"] as? [[String: Any]]
        else { return [] }
        return products.compactMap { item(fromProduct: $0, source: .search) }
    }

    /// The photo-scan server's answer: `{"items":[{"name":…,"kcal":…,
    /// "protein":…,"carbs":…,"fat":…,"fiber":…}]}`. Estimates, editable
    /// by the user before anything is saved.
    static func items(fromScan data: Data) -> [FoodItem] {
        struct Scan: Decodable {
            struct Item: Decodable {
                var name: String
                var kcal: Double?
                var protein: Double?
                var carbs: Double?
                var fat: Double?
                var fiber: Double?
            }
            var items: [Item]
        }
        guard let scan = try? JSONDecoder().decode(Scan.self, from: data) else { return [] }
        return scan.items.compactMap { item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            func d(_ value: Double?) -> Decimal { Decimal(max(value ?? 0, 0)).rounded(1) }
            return FoodItem(name: name, kcal: d(item.kcal), protein: d(item.protein), carbs: d(item.carbs),
                            fat: d(item.fat), fiber: d(item.fiber), source: .photo)
        }
    }
}
