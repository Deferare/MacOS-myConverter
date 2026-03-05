import Foundation

extension FormatOptionUtilities {
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
}
