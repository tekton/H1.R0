import Foundation
import SwiftGD
import Vapor

/// Resizes JPEGs to 200x133 thumbnails using SwiftGD (libgd), mirroring the
/// Rails RMagick `resize_to_fit!(200, 133)` behaviour (aspect-fit within the box).
enum ThumbnailService {
    struct ThumbnailError: Error { let message: String }

    static let targetWidth = 200
    static let targetHeight = 133

    /// Create a thumbnail for `sourcePath`, writing it to `destinationPath`.
    /// Intermediate directories are created as needed.
    static func generate(sourcePath: String, destinationPath: String, logger: Logger) throws {
        let sourceURL = URL(fileURLWithPath: sourcePath)

        guard let image = Image(url: sourceURL) else {
            throw ThumbnailError(message: "Could not read image at \(sourcePath)")
        }

        // Aspect-fit: scale so the image fits inside 200x133 without distortion,
        // matching RMagick's resize_to_fit!.
        let (w, h) = fittedSize(width: image.size.width, height: image.size.height)

        guard let resized = image.resizedTo(width: w, height: h) else {
            throw ThumbnailError(message: "Resize failed for \(sourcePath)")
        }

        // Ensure the destination directory exists.
        let destURL = URL(fileURLWithPath: destinationPath)
        try FileManager.default.createDirectory(
            at: destURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard resized.write(to: destURL, quality: 85) else {
            throw ThumbnailError(message: "Could not write thumbnail to \(destinationPath)")
        }
        logger.info("Wrote thumbnail \(destinationPath) (\(w)x\(h))")
    }

    /// Compute the largest size that fits within the target box, preserving aspect ratio.
    static func fittedSize(width: Int, height: Int) -> (Int, Int) {
        guard width > 0, height > 0 else { return (targetWidth, targetHeight) }
        let scale = min(Double(targetWidth) / Double(width), Double(targetHeight) / Double(height))
        let w = max(1, Int((Double(width) * scale).rounded()))
        let h = max(1, Int((Double(height) * scale).rounded()))
        return (w, h)
    }
}
