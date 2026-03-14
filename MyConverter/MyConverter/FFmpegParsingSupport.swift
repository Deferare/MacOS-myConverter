import Foundation

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
}
