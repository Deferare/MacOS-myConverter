import CoreGraphics
import Foundation
import QuickLookThumbnailing

protocol ThumbnailProvider: AnyObject {
    func makeThumbnail(for url: URL, size: CGSize) async -> CGImage?
}

final class QuickLookThumbnailProviderService: ThumbnailProvider {
    static let shared = QuickLookThumbnailProviderService()

    private init() {}

    func makeThumbnail(for url: URL, size: CGSize) async -> CGImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 2,
            representationTypes: .thumbnail
        )

        return await withCheckedContinuation { continuation in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, _ in
                continuation.resume(returning: thumbnail?.cgImage)
            }
        }
    }
}
