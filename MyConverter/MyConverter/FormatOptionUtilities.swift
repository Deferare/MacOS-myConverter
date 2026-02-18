import Foundation

enum FormatOptionUtilities {
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
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { continue }
            if seen.insert(normalized).inserted {
                result.append(normalized)
            }
        }

        return result
    }

    nonisolated static func uniqueNonEmptyStrings(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            guard !value.isEmpty else { continue }
            if seen.insert(value).inserted {
                result.append(value)
            }
        }

        return result
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
