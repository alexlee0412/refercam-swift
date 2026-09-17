import Photos
import UIKit

enum ImageService {
    /// The reference is a framing guide; the MVP output is the captured camera photo,
    /// with the reference never burned into the saved image.
    static func outputImage(from capturedImage: UIImage) -> UIImage {
        capturedImage
    }

    /// Optional compositing for an alternate preview mode. Not used by the default
    /// capture/save flow, which saves the plain camera photo.
    static func composite(
        capturedImage: UIImage,
        referenceImage: UIImage,
        opacity: Double
    ) throws -> UIImage {
        let size = capturedImage.size
        guard size.width > 0, size.height > 0 else {
            throw ImageServiceError.invalidImage
        }

        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)

        return renderer.image { _ in
            capturedImage.draw(in: CGRect(origin: .zero, size: size))

            let referenceSize = referenceImage.size
            guard referenceSize.width > 0, referenceSize.height > 0 else { return }

            let scale = min(size.width / referenceSize.width, size.height / referenceSize.height)
            let fittedSize = CGSize(width: referenceSize.width * scale, height: referenceSize.height * scale)
            let origin = CGPoint(
                x: (size.width - fittedSize.width) / 2,
                y: (size.height - fittedSize.height) / 2
            )

            referenceImage.draw(
                in: CGRect(origin: origin, size: fittedSize),
                blendMode: .normal,
                alpha: CGFloat(max(0, min(1, opacity)))
            )
        }
    }

    static func saveToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ImageServiceError.notAuthorized
        }

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }
}

enum ImageServiceError: LocalizedError {
    case notAuthorized
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Photos access is required to save."
        case .invalidImage:
            return "The photo couldn't be processed."
        }
    }
}
