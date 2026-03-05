import Foundation
import ImageIO

extension ImageConversionEngine {
    nonisolated static func imageIODestinationTypeIdentifiers() -> Set<String> {
        cachedOutputFormatValue(
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

    nonisolated static func cachedOutputFormatValue<Value>(
        readCached: () -> Value?,
        storeCached: (Value) -> Void,
        build: () -> Value
    ) -> Value {
        if let cached = readCached() {
            return cached
        }
        let resolved = build()
        storeCached(resolved)
        return resolved
    }
}
