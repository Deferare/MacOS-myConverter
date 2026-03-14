import Foundation

enum EmbeddedFFmpegBridge {
    nonisolated static var isConfigured: Bool {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        true
        #else
        false
        #endif
    }

    nonisolated static func runCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        let task = Task.detached(priority: .userInitiated) {
            try runCapturedCommand(
                arguments: arguments,
                outputLineHandler: outputLineHandler
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            cancelCurrentCommand()
            task.cancel()
        }
        #else
        throw FFmpegRuntimeError.unavailable(
            "The in-process FFmpeg bridge is not configured for this build."
        )
        #endif
    }

    nonisolated static func runCommandSync(arguments: [String]) -> FFmpegCommandResult {
        #if os(iOS) && MYCONVERTER_IOS_FFMPEG_BRIDGE
        do {
            return try runCapturedCommand(arguments: arguments, outputLineHandler: nil)
        } catch {
            return FFmpegCommandResult(
                terminationStatus: -1,
                output: error.localizedDescription
            )
        }
        #else
        FFmpegCommandResult(
            terminationStatus: -1,
            output: "The in-process FFmpeg bridge is not configured for this build."
        )
        #endif
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
