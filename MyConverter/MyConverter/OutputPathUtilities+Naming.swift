import Foundation

extension OutputPathUtilities {
    nonisolated private static let maximumGeneratedFilenameComponentBytes = 180

    private struct CachedFileFingerprint {
        let value: String
        let timestamp: UInt64
    }

    nonisolated private static let fileFingerprintCacheQueue = DispatchQueue(
        label: "myconverter.file.fingerprint.cache"
    )
    nonisolated(unsafe) private static var fileFingerprintCache: [String: CachedFileFingerprint] = [:]
    nonisolated private static let fileFingerprintCacheTTL: UInt64 = 500_000_000

    nonisolated static func fileFingerprint(for url: URL) -> String {
        let standardizedURL = url.standardizedFileURL
        let path = standardizedURL.path
        let now = DispatchTime.now().uptimeNanoseconds

        if let cached = fileFingerprintCacheQueue.sync(execute: { fileFingerprintCache[path] }) {
            let age = now >= cached.timestamp ? now - cached.timestamp : 0
            if age < fileFingerprintCacheTTL {
                return cached.value
            }
        }

        let resourceValues = try? standardizedURL.resourceValues(
            forKeys: [.contentModificationDateKey, .fileSizeKey]
        )
        let fileSize = resourceValues?.fileSize ?? -1
        let modificationInterval = resourceValues?.contentModificationDate?.timeIntervalSinceReferenceDate ?? -1
        let fingerprint = "\(path)|\(fileSize)|\(modificationInterval)"

        fileFingerprintCacheQueue.sync {
            fileFingerprintCache[path] = CachedFileFingerprint(
                value: fingerprint,
                timestamp: now
            )
        }

        return fingerprint
    }

    nonisolated static func sourceBaseName(for sourceURL: URL, fallback: String) -> String {
        let rawBaseName = sourceURL.deletingPathExtension()
            .lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = normalizedGeneratedBaseName(rawBaseName, fallback: fallback)
        return boundedFilenameStem(
            normalized,
            maxUTF8Length: maximumGeneratedFilenameComponentBytes
        )
    }

    nonisolated static func temporaryOutputURL(
        for sourceURL: URL,
        fileExtension: String
    ) -> URL {
        let baseName = sourceBaseName(for: sourceURL, fallback: "output")
        let filename = generatedFilenameComponent(
            baseName: baseName,
            fileExtension: fileExtension,
            suffix: "_working_\(UUID().uuidString)"
        )
        return workingDirectoryURL()
            .appendingPathComponent(filename)
    }

    nonisolated static func normalizedOutputComponents(
        baseName: String,
        fileExtension: String
    ) -> (baseName: String, fileExtension: String) {
        let effectiveBaseName = normalizedGeneratedBaseName(baseName, fallback: "output")
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        return (effectiveBaseName, ext)
    }

    nonisolated static func hiddenWorkingFilename(for destinationURL: URL) -> String {
        let stem = destinationURL.pathExtension.isEmpty
            ? destinationURL.lastPathComponent
            : destinationURL.deletingPathExtension().lastPathComponent
        return generatedFilenameComponent(
            baseName: normalizedGeneratedBaseName(stem, fallback: "output"),
            fileExtension: destinationURL.pathExtension,
            prefix: ".",
            suffix: ".myconverter-working-\(UUID().uuidString)"
        )
    }

    nonisolated static func normalizedGeneratedBaseName(
        _ baseName: String,
        fallback: String
    ) -> String {
        var normalized = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            normalized = fallback
        }

        let generatedSuffixPatterns = [
            #"(?:_converted_\d+)+$"#,
            #"_working_[0-9A-Fa-f-]+$"#,
            #"\.myconverter-working-[0-9A-Fa-f-]+$"#
        ]

        var changed = true
        while changed {
            changed = false
            for pattern in generatedSuffixPatterns {
                if let range = normalized.range(of: pattern, options: .regularExpression) {
                    normalized.removeSubrange(range)
                    normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: " ._-"))
                    changed = true
                }
            }
        }

        return normalized.isEmpty ? fallback : normalized
    }

    nonisolated static func generatedFilenameComponent(
        baseName: String,
        fileExtension: String,
        prefix: String = "",
        suffix: String = ""
    ) -> String {
        let ext = fileExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        let reservedBytes = prefix.utf8.count + suffix.utf8.count + (ext.isEmpty ? 0 : ext.utf8.count + 1)
        let maxStemBytes = max(32, maximumGeneratedFilenameComponentBytes - reservedBytes)
        let safeBaseName = boundedFilenameStem(baseName, maxUTF8Length: maxStemBytes)
        let filename = "\(prefix)\(safeBaseName)\(suffix)"
        guard !ext.isEmpty else { return filename }
        return "\(filename).\(ext)"
    }

    nonisolated static func boundedFilenameStem(
        _ stem: String,
        maxUTF8Length: Int
    ) -> String {
        let trimmed = stem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.utf8.count > maxUTF8Length else { return trimmed }

        let hash = shortStableHash(for: trimmed)
        let separator = "-"
        let reservedBytes = hash.utf8.count + separator.utf8.count
        let prefixBytes = max(16, maxUTF8Length - reservedBytes)
        let safePrefix = utf8Prefix(of: trimmed, maxLength: prefixBytes)
        return "\(safePrefix)\(separator)\(hash)"
    }

    nonisolated static func utf8Prefix(of value: String, maxLength: Int) -> String {
        guard maxLength > 0 else { return "" }

        var utf8Count = 0
        var endIndex = value.startIndex

        for character in value {
            let characterLength = String(character).utf8.count
            if utf8Count + characterLength > maxLength {
                break
            }
            utf8Count += characterLength
            endIndex = value.index(after: endIndex)
        }

        return String(value[..<endIndex])
    }

    nonisolated static func shortStableHash(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return String(hash, radix: 16, uppercase: false)
    }
}
