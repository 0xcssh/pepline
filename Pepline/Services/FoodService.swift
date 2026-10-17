import Foundation
import UIKit

/// Network side of nutrition: Open Food Facts (search and barcode, free,
/// ODbL) and Pepline's photo estimate (Pro, `server/api/food/scan`). The
/// JSON is parsed by `FoodData` in the tested core.
enum FoodService {
    enum Failure: Error {
        case network, notFound, notPro, rateLimited, unavailable
    }

    /// Open Food Facts asks every app to identify itself (api docs, "User-Agent").
    private static var userAgent: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Pepline/\(version) (awdianthony@gmail.com)"
    }

    private static func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        guard let result = try? await URLSession.shared.data(for: request),
              (result.1 as? HTTPURLResponse)?.statusCode == 200
        else { throw Failure.network }
        return result.0
    }

    /// `api/v2/product/{code}`; reads are limited to 15 per minute per user.
    static func lookup(barcode: String) async throws -> FoodItem {
        let code = barcode.filter(\.isNumber)
        guard !code.isEmpty, let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code)" +
            "?fields=product_name,serving_size,nutriments,code")
        else { throw Failure.notFound }
        guard let item = FoodData.item(fromLookup: try await get(url), barcode: code) else { throw Failure.notFound }
        return item
    }

    /// Full-text search (10 per minute per user, so it runs on submit only).
    static func search(_ query: String) async throws -> [FoodItem] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "25"),
            URLQueryItem(name: "fields", value: "product_name,serving_size,nutriments,code"),
        ]
        return FoodData.items(fromSearch: try await get(components.url!))
    }

    static let scanURL = URL(string: "https://pepline-api.vercel.app/api/food/scan")!

    /// Sends one meal photo for an estimate. The server checks the Pro
    /// entitlement and does not keep the photo.
    static func scan(_ image: UIImage, appUserID: String) async throws -> [FoodItem] {
        guard let jpeg = image.resizedForUpload().jpegData(compressionQuality: 0.7) else { throw Failure.unavailable }
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        var request = URLRequest(url: scanURL, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "image": jpeg.base64EncodedString(), "appUserID": appUserID, "language": language,
        ])
        guard let result = try? await URLSession.shared.data(for: request),
              let status = (result.1 as? HTTPURLResponse)?.statusCode
        else { throw Failure.network }
        switch status {
        case 200: return FoodData.items(fromScan: result.0)
        case 403: throw Failure.notPro
        case 429: throw Failure.rateLimited
        default: throw Failure.unavailable
        }
    }
}

private extension UIImage {
    /// 1024 px on the long side is plenty for a portion estimate and keeps
    /// the upload small.
    func resizedForUpload(maxSide: CGFloat = 1024) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
