import Foundation

extension FormatOptionUtilities {
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
