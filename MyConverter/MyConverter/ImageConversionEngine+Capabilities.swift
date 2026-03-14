import Foundation
import ImageIO

extension ImageConversionEngine {
    nonisolated static func imageIODestinationTypeIdentifiers() -> Set<String> {
        CachedValueSupport.resolve(
            readCached: { outputFormatCacheQueue.sync(execute: { imageIODestinationTypeCache }) },
            storeCached: { resolved in
                outputFormatCacheQueue.sync {
                    imageIODestinationTypeCache = resolved
                }
            }
        ) {
            Set((CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []).map { $0.lowercased() })
        }
    }

    nonisolated static func canEncodeWithImageIO(_ format: ImageFormatOption) -> Bool {
        guard let identifier = format.imageIOUTTypeIdentifier?.lowercased() else {
            return false
        }
        return imageIODestinationTypeIdentifiers().contains(identifier)
    }
}
