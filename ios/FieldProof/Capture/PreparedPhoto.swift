import ImageIO
import UIKit

/// The stored photo bytes, a small thumbnail, and the SHA-256 of the stored bytes.
struct PreparedPhoto {

    // MARK: - Fields

    let jpeg: Data
    let thumbnail: Data
    let hash: String
    let image: UIImage

    // MARK: - Limits

    static let maxSide: CGFloat = 1600
    static let quality: CGFloat = 0.8
    static let thumbSide: CGFloat = 320
    static let thumbQuality: CGFloat = 0.7

    // MARK: - Build

    /// A camera photo: resize to 1600 px, encode, then hash the bytes that will be stored.
    static func from(image: UIImage) -> PreparedPhoto? {
        guard let jpeg = resized(image, maxSide: maxSide).jpegData(compressionQuality: quality) else { return nil }
        return from(storedJPEG: jpeg)
    }

    /// A bundled sample that already fits the limits is stored byte for byte, so its hash (and its Mac-precomputed
    /// embedding) match on every device. Larger files go through the camera path.
    static func from(sampleJPEG data: Data) -> PreparedPhoto? {
        guard let image = UIImage(data: data) else { return nil }
        let side = max(image.size.width, image.size.height) * image.scale
        return side <= maxSide ? from(storedJPEG: data) : from(image: image)
    }

    private static func from(storedJPEG jpeg: Data) -> PreparedPhoto? {
        guard let image = UIImage(data: jpeg),
              let thumb = resized(image, maxSide: thumbSide).jpegData(compressionQuality: thumbQuality) else { return nil }
        return PreparedPhoto(jpeg: jpeg, thumbnail: thumb, hash: EvidenceHash.sha256Hex(jpeg), image: image)
    }

    // MARK: - Resize

    /// Draws upright at 1x, so the output has no EXIF rotation to worry about.
    private static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
