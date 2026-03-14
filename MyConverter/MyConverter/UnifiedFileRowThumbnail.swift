#if os(macOS)
import AppKit
import QuickLookThumbnailing
import SwiftUI

struct UnifiedFileRowThumbnailView: View {
    let sourceURL: URL
    let size: CGSize
    let cornerRadius: CGFloat
    let borderOpacity: CGFloat

    @State private var thumbnailImage: NSImage?

    init(
        sourceURL: URL,
        size: CGSize,
        cornerRadius: CGFloat,
        borderOpacity: CGFloat
    ) {
        self.sourceURL = sourceURL
        self.size = size
        self.cornerRadius = cornerRadius
        self.borderOpacity = borderOpacity
        _thumbnailImage = State(
            initialValue: UnifiedFileThumbnailGenerator.fallbackIcon(for: sourceURL, size: size)
        )
    }

    var body: some View {
        Group {
            if let thumbnailImage {
                Image(nsImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholderThumbnail
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: cornerRadius,
                style: .continuous
            )
            .stroke(.white.opacity(borderOpacity), lineWidth: 1)
        )
        .task(id: sourceURL.path) {
            loadThumbnail()
        }
    }

    private var placeholderThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.white.opacity(0.05))

            Image(systemName: "doc")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func loadThumbnail() {
        if let cachedThumbnail = UnifiedFileThumbnailGenerator.cachedThumbnail(for: sourceURL) {
            thumbnailImage = cachedThumbnail
            return
        }

        let sourcePath = sourceURL.path
        UnifiedFileThumbnailGenerator.generateThumbnail(for: sourceURL, size: size) { image in
            guard sourceURL.path == sourcePath else { return }
            thumbnailImage = image
        }
    }
}

private enum UnifiedFileThumbnailGenerator {
    private static let cache = NSCache<NSString, NSImage>()

    static func cachedThumbnail(for url: URL) -> NSImage? {
        cache.object(forKey: cacheKey(for: url))
    }

    static func generateThumbnail(
        for url: URL,
        size: CGSize,
        completion: @escaping (NSImage) -> Void
    ) {
        let cacheKey = cacheKey(for: url)
        if let cachedImage = cache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }

        let pointSize = NSSize(width: size.width, height: size.height)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let image: NSImage
            if let cgImage = representation?.cgImage {
                image = NSImage(cgImage: cgImage, size: pointSize)
            } else {
                image = fallbackIcon(for: url, size: size)
            }

            cache.setObject(image, forKey: cacheKey)

            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    static func fallbackIcon(for url: URL, size: CGSize) -> NSImage {
        let image = NSWorkspace.shared.icon(forFile: url.path)
        image.size = NSSize(width: size.width, height: size.height)
        return image
    }

    private static func cacheKey(for url: URL) -> NSString {
        url.path as NSString
    }
}
#endif
