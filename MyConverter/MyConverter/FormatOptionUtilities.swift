import Foundation
import UniformTypeIdentifiers

enum FormatOptionUtilities {
    nonisolated private static func uniqueStrings(
        _ values: [String],
        transform: (String) -> String?
    ) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            guard let transformed = transform(value) else { continue }
            if seen.insert(transformed).inserted {
                result.append(transformed)
            }
        }

        return result
    }

    nonisolated static func normalizedFileExtension(_ fileExtension: String) -> String {
        var normalized = fileExtension.lowercased()
        if normalized.hasPrefix(".") {
            normalized.removeFirst()
        }

        normalized = normalized
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized
    }

    nonisolated static func uniqueLowercasedTrimmedStrings(_ values: [String]) -> [String] {
        uniqueStrings(values) { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized.isEmpty ? nil : normalized
        }
    }

    nonisolated static func uniqueNonEmptyStrings(_ values: [String]) -> [String] {
        uniqueStrings(values) { value in
            value.isEmpty ? nil : value
        }
    }

    nonisolated static func resolveFFmpegFormatMetadata<Profile>(
        fileExtension: String,
        muxer: String,
        profile: Profile?,
        profileID: (Profile) -> String,
        profileDisplayName: (Profile) -> String,
        profileFileExtension: (Profile) -> String,
        profileRequiredMuxers: (Profile) -> [String],
        profilePreferredMuxer: (Profile) -> String?
    ) -> (
        id: String,
        displayName: String,
        fileExtension: String,
        requiredMuxers: [String],
        preferredMuxer: String
    ) {
        let normalizedExtension = normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()
        let extensionUTType = UTType(filenameExtension: normalizedExtension)

        let resolvedID =
            profile.map(profileID) ??
            extensionUTType?.identifier.lowercased() ??
            "ffmpeg.\(normalizedExtension)"

        let resolvedDisplayName =
            profile.map(profileDisplayName) ??
            extensionUTType?.localizedDescription ??
            normalizedExtension.uppercased()

        let resolvedExtension =
            profile.map(profileFileExtension) ??
            extensionUTType?.preferredFilenameExtension ??
            normalizedExtension

        let resolvedMuxers = uniqueLowercasedTrimmedStrings(
            (profile.map(profileRequiredMuxers) ?? []) + [normalizedMuxer]
        )

        return (
            id: resolvedID,
            displayName: resolvedDisplayName,
            fileExtension: resolvedExtension,
            requiredMuxers: resolvedMuxers,
            preferredMuxer: profile.flatMap(profilePreferredMuxer) ?? normalizedMuxer
        )
    }

    nonisolated static func preferredDisplayName(_ lhs: String, _ rhs: String) -> String {
        lhs.count >= rhs.count ? lhs : rhs
    }

    nonisolated static func deduplicatedAndSorted<Option>(
        _ options: [Option],
        normalizedID: (Option) -> String,
        merge: (Option, Option) -> Option,
        displayName: (Option) -> String
    ) -> [Option] {
        var byID: [String: Option] = [:]

        for option in options {
            let key = normalizedID(option)
            if let existing = byID[key] {
                byID[key] = merge(existing, option)
            } else {
                byID[key] = option
            }
        }

        return byID.values.sorted { lhs, rhs in
            displayName(lhs).localizedCaseInsensitiveCompare(displayName(rhs)) == .orderedAscending
        }
    }

    nonisolated static func firstPreferredOption<Option>(
        in options: [Option],
        preferredExtensions: [String],
        fileExtension: (Option) -> String
    ) -> Option? {
        let normalizedPreferred = preferredExtensions.map { $0.lowercased() }

        for preferred in normalizedPreferred {
            if let matched = options.first(where: { fileExtension($0).lowercased() == preferred }) {
                return matched
            }
        }

        return options.first
    }

    nonisolated static func prettifiedIdentifier(_ identifier: String) -> String {
        let token = identifier
            .split(separator: ".")
            .last
            .map(String.init) ?? identifier

        return token
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .uppercased()
    }

    nonisolated static func guessedFileExtension(from identifier: String, defaultValue: String = "img") -> String {
        let token = identifier
            .split(separator: ".")
            .last
            .map(String.init) ?? defaultValue

        return normalizedFileExtension(token)
    }
}
