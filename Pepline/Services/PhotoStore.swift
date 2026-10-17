import UIKit

/// Progress photos as JPEG files in Application Support/Photos. Re-encoding
/// through UIImage drops EXIF (location, device), so nothing but the pixels
/// is kept. Never uploaded, never in iCloud.
enum PhotoStore {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Photos", isDirectory: true)
    }

    /// Saves the image and returns its file name.
    static func save(_ image: UIImage) -> String? {
        let resized = image.resized(maxSide: 1600)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return name
        } catch {
            return nil
        }
    }

    static func image(named name: String) -> UIImage? {
        UIImage(contentsOfFile: folder.appendingPathComponent(name).path)
    }

    static func delete(named name: String) {
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
    }
}

private extension UIImage {
    func resized(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: target).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
