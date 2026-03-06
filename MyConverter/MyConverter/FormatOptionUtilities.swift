import Foundation
import UniformTypeIdentifiers

enum FormatOptionUtilities {
    private struct CachedUTType {
        let value: UTType?
    }

    nonisolated private static let utTypeCacheQueue = DispatchQueue(
        label: "myconverter.formatoption.uttype.cache"
    )
    nonisolated(unsafe) private static var filenameExtensionTypeCache: [String: CachedUTType] = [:]
    nonisolated(unsafe) private static var identifierTypeCache: [String: CachedUTType] = [:]

    nonisolated static func cachedUTType(forFilenameExtension fileExtension: String) -> UTType? {
        let normalizedExtension = normalizedFileExtension(fileExtension)
        guard !normalizedExtension.isEmpty else { return nil }

        if let cached = utTypeCacheQueue.sync(execute: { filenameExtensionTypeCache[normalizedExtension] }) {
            return cached.value
        }

        let resolved = UTType(filenameExtension: normalizedExtension)
        utTypeCacheQueue.sync {
            filenameExtensionTypeCache[normalizedExtension] = CachedUTType(value: resolved)
        }
        return resolved
    }

    nonisolated static func cachedUTType(forIdentifier identifier: String) -> UTType? {
        let normalizedIdentifier = identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !normalizedIdentifier.isEmpty else { return nil }

        if let cached = utTypeCacheQueue.sync(execute: { identifierTypeCache[normalizedIdentifier] }) {
            return cached.value
        }

        let resolved = UTType(normalizedIdentifier)
        utTypeCacheQueue.sync {
            identifierTypeCache[normalizedIdentifier] = CachedUTType(value: resolved)
        }
        return resolved
    }
}
