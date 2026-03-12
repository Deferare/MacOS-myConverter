import Foundation

struct ProcessFFmpegRuntime: FFmpegRuntime {
    let path: String

    var cacheIdentity: String {
        "process:\(path)"
    }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    func runCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult {
        #if os(macOS)
        let result = try await ProcessCommandRunner.runCommand(
            path: path,
            arguments: arguments,
            outputLineHandler: outputLineHandler
        )
        return FFmpegCommandResult(
            terminationStatus: result.terminationStatus,
            output: result.output
        )
        #else
        throw FFmpegRuntimeError.unavailable(
            "Process-based FFmpeg execution is unavailable on this platform."
        )
        #endif
    }

    func runCommandSync(arguments: [String]) -> FFmpegCommandResult {
        #if os(macOS)
        let result = ProcessCommandRunner.runCommandSync(path: path, arguments: arguments)
        return FFmpegCommandResult(
            terminationStatus: result.terminationStatus,
            output: result.output
        )
        #else
        return FFmpegCommandResult(
            terminationStatus: -1,
            output: "Process-based FFmpeg execution is unavailable on this platform."
        )
        #endif
    }
}
