import UIKit

// Photos are shrunk on the phone before saving, so each one stays around 100 KB.
// They're stored as bytes in Firestore, because Cloud Storage needs the paid Firebase plan.
enum PhotoCompressor {
    static let maxBytes = 300_000

    static func jpeg(from data: Data, longestSide: CGFloat = 900) -> Data? {
        guard let image = UIImage(data: data) else { return nil }

        let scale = min(1, longestSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        // Try a good quality first, then smaller ones until it fits.
        for quality in [0.7, 0.5, 0.35] {
            if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return jpeg
            }
        }
        return nil
    }
}

// Keeps loaded idea photos in memory, so scrolling and editing don't download them again.
enum PhotoCache {
    static let images = NSCache<NSString, UIImage>()
}
