import Foundation

extension ContentViewModelSupport {
    nonisolated static func labeledCapabilityMessage(_ message: String, for sourceURL: URL, totalCount: Int) -> String {
        guard totalCount > 1 else { return message }
        return "\(sourceURL.lastPathComponent): \(message)"
    }

    nonisolated static func joinedCapabilityMessages(_ messages: [String]) -> String? {
        var seen = Set<String>()
        var uniqueMessages: [String] = []

        for message in messages {
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                uniqueMessages.append(trimmed)
            }
        }

        guard !uniqueMessages.isEmpty else { return nil }
        return uniqueMessages.joined(separator: "\n")
    }

    nonisolated static func intersectFormats<Format>(
        _ lhs: [Format],
        _ rhs: [Format],
        normalizedID: (Format) -> String
    ) -> [Format] {
        let rhsIDs = Set(rhs.map(normalizedID))
        return lhs.filter { rhsIDs.contains(normalizedID($0)) }
    }

    nonisolated static func clampedProgress(_ rawProgress: Double) -> Double {
        min(max(rawProgress, 0), 1)
    }
}
