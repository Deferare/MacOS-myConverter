import Foundation

enum FFmpegParsingSupport {
    nonisolated static func parseEncoders(
        from output: String,
        mediaFlag: Character
    ) -> Set<String> {
        var encoders = Set<String>()

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }

            let flags = String(parts[0])
            guard flags.count >= 6, flags.first == mediaFlag else { continue }
            encoders.insert(String(parts[1]))
        }

        return encoders
    }

    nonisolated static func parseMuxerDescriptors(
        from output: String,
        lowercaseDescription: Bool
    ) -> [(name: String, description: String)] {
        var descriptors: [(name: String, description: String)] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(maxSplits: 2, whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }

            let flags = String(parts[0])
            guard flags.contains("E") else { continue }

            let nameField = String(parts[1])
            var description = parts.count == 3
                ? String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            if lowercaseDescription {
                description = description.lowercased()
            }

            let names = nameField
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            for name in names {
                descriptors.append((name: name, description: description))
            }
        }

        return descriptors
    }

    nonisolated static func parseMuxerExtensions(
        from output: String,
        maxTokenLength: Int?
    ) -> [String] {
        var collecting = false
        var buffer = ""

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if !collecting {
                guard let range = trimmed.range(of: "Common extensions:", options: [.caseInsensitive]) else { continue }
                collecting = true
                buffer += String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                buffer += " " + trimmed
            }

            if buffer.contains(".") {
                break
            }
        }

        guard !buffer.isEmpty else { return [] }
        if let periodIndex = buffer.firstIndex(of: ".") {
            buffer = String(buffer[..<periodIndex])
        }

        let allowed = CharacterSet.alphanumerics
        var seen = Set<String>()
        var result: [String] = []

        for token in buffer.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let cleanedScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
            let normalized = String(String.UnicodeScalarView(cleanedScalars)).lowercased()
            guard !normalized.isEmpty else { continue }
            if let maxTokenLength, normalized.count > maxTokenLength {
                continue
            }
            guard seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }

        return result
    }
}

enum FFmpegCommandCache {
    struct CommandResult {
        let terminationStatus: Int32
        let output: String
    }

    final class InFlightCommand: @unchecked Sendable {
        nonisolated let group: DispatchGroup
        nonisolated(unsafe) var result: CommandResult?

        nonisolated init() {
            group = DispatchGroup()
            group.enter()
        }
    }

    nonisolated private static let cacheQueue = DispatchQueue(label: "myconverter.ffmpeg.command.cache")
    nonisolated(unsafe) private static var cache: [String: CommandResult] = [:]
    nonisolated(unsafe) private static var inFlight: [String: InFlightCommand] = [:]

    nonisolated static func run(
        path: String,
        arguments: [String]
    ) -> CommandResult {
        let cacheKey = makeCacheKey(path: path, arguments: arguments)
        if let cached = cacheQueue.sync(execute: { cache[cacheKey] }) {
            return cached
        }

        let (command, shouldRun) = cacheQueue.sync { () -> (InFlightCommand, Bool) in
            if let existing = inFlight[cacheKey] {
                return (existing, false)
            }

            let created = InFlightCommand()
            inFlight[cacheKey] = created
            return (created, true)
        }

        if !shouldRun {
            command.group.wait()
            if let result = command.result {
                return result
            }
            return CommandResult(terminationStatus: -1, output: "")
        }

        let resolved = ProcessCommandRunner.runCommandSync(path: path, arguments: arguments)
        let result = CommandResult(
            terminationStatus: resolved.terminationStatus,
            output: resolved.output
        )

        cacheQueue.sync {
            cache[cacheKey] = result
            command.result = result
            inFlight[cacheKey] = nil
            command.group.leave()
        }

        return result
    }

    nonisolated private static func makeCacheKey(path: String, arguments: [String]) -> String {
        let separator = "\u{1F}"
        return ([path] + arguments).joined(separator: separator)
    }
}
