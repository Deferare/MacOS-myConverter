import Foundation

enum FFmpegCommandCache {
    final class InFlightCommand: @unchecked Sendable {
        nonisolated let group: DispatchGroup
        nonisolated(unsafe) var result: FFmpegCommandResult?

        nonisolated init() {
            group = DispatchGroup()
            group.enter()
        }
    }

    nonisolated private static let cacheQueue = DispatchQueue(label: "myconverter.ffmpeg.command.cache")
    nonisolated(unsafe) private static var cache: [String: FFmpegCommandResult] = [:]
    nonisolated(unsafe) private static var inFlight: [String: InFlightCommand] = [:]

    nonisolated static func run(
        runtime: any FFmpegRuntime,
        arguments: [String]
    ) -> FFmpegCommandResult {
        let cacheKey = makeCacheKey(identity: runtime.cacheIdentity, arguments: arguments)
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
            return FFmpegCommandResult(terminationStatus: -1, output: "")
        }

        let result = runtime.runCommandSync(arguments: arguments)

        cacheQueue.sync {
            cache[cacheKey] = result
            command.result = result
            inFlight[cacheKey] = nil
            command.group.leave()
        }

        return result
    }

    nonisolated static func run(
        path: String,
        arguments: [String]
    ) -> FFmpegCommandResult {
        run(runtime: ProcessFFmpegRuntime(path: path), arguments: arguments)
    }

    nonisolated private static func makeCacheKey(identity: String, arguments: [String]) -> String {
        let separator = "\u{1F}"
        return ([identity] + arguments).joined(separator: separator)
    }
}
