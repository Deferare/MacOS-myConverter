import Foundation

enum EmbeddedFFmpegBridge {
    nonisolated static var isConfigured: Bool {
        false
    }

    static func runCommand(
        arguments _: [String],
        outputLineHandler _: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult {
        throw FFmpegRuntimeError.unavailable(
            "The in-process FFmpeg bridge is not configured for this build."
        )
    }

    static func runCommandSync(arguments _: [String]) -> FFmpegCommandResult {
        FFmpegCommandResult(
            terminationStatus: -1,
            output: "The in-process FFmpeg bridge is not configured for this build."
        )
    }
}

struct InProcessFFmpegRuntime: FFmpegRuntime {
    nonisolated init() {}

    nonisolated static func makeIfAvailable() -> (any FFmpegRuntime)? {
        guard EmbeddedFFmpegBridge.isConfigured else {
            return nil
        }
        return InProcessFFmpegRuntime()
    }

    var cacheIdentity: String {
        "inprocess:ffmpeg"
    }

    var displayName: String {
        "embedded-ffmpeg"
    }

    func runCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult {
        try await EmbeddedFFmpegBridge.runCommand(
            arguments: arguments,
            outputLineHandler: outputLineHandler
        )
    }

    func runCommandSync(arguments: [String]) -> FFmpegCommandResult {
        EmbeddedFFmpegBridge.runCommandSync(arguments: arguments)
    }
}
