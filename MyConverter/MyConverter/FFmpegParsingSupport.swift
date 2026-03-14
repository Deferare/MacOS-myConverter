import Foundation

struct FFmpegMuxerDescriptor: Sendable {
    let name: String
    let description: String
}

enum FFmpegParsingSupport {
    nonisolated static func runCommandOutput(
        runtime: any FFmpegRuntime,
        arguments: [String],
        makeError: (Int32, String) -> Error
    ) throws -> String {
        let result = FFmpegCommandCache.run(runtime: runtime, arguments: arguments)
        guard result.terminationStatus == 0 else {
            throw makeError(result.terminationStatus, result.output)
        }
        return result.output
    }

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
    ) -> [FFmpegMuxerDescriptor] {
        var descriptors: [FFmpegMuxerDescriptor] = []

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
                descriptors.append(FFmpegMuxerDescriptor(name: name, description: description))
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

    nonisolated static func collectMuxerExtensions(
        runtime: any FFmpegRuntime,
        muxerDescriptors: [FFmpegMuxerDescriptor],
        maxTokenLength: Int?,
        shouldInclude: (FFmpegMuxerDescriptor) -> Bool,
        fallbackExtension: (FFmpegMuxerDescriptor) -> String?
    ) -> [String: [String]] {
        var byMuxer: [String: [String]] = [:]
        var visited = Set<String>()

        for descriptor in muxerDescriptors {
            guard visited.insert(descriptor.name).inserted else { continue }
            guard shouldInclude(descriptor) else { continue }

            let help = FFmpegCommandCache.run(
                runtime: runtime,
                arguments: ["-hide_banner", "-h", "muxer=\(descriptor.name)"]
            )
            guard help.terminationStatus == 0 else { continue }

            var extensions = parseMuxerExtensions(
                from: help.output,
                maxTokenLength: maxTokenLength
            )
            if extensions.isEmpty, let fallbackExtension = fallbackExtension(descriptor) {
                extensions = [fallbackExtension]
            }
            guard !extensions.isEmpty else { continue }
            byMuxer[descriptor.name] = extensions
        }

        return byMuxer
    }

    nonisolated static func discoveredFormats<Format>(
        from introspection: FFmpegIntrospection,
        includeExtension: (String) -> Bool = { _ in true },
        makeFormat: (String, String) -> Format
    ) -> [Format] {
        var formats: [Format] = []

        for (muxer, extensions) in introspection.muxerExtensions {
            for fileExtension in extensions where includeExtension(fileExtension) {
                formats.append(makeFormat(fileExtension, muxer))
            }
        }

        return formats
    }
}
