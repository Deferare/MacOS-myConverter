import Foundation

struct FFmpegCommandResult: Sendable {
    let terminationStatus: Int32
    let output: String
}

struct FFmpegIntrospection: Sendable {
    let videoEncoders: Set<String>
    let audioEncoders: Set<String>
    let muxers: Set<String>
    let muxerExtensions: [String: [String]]
}

struct FFmpegExecutionContext: Sendable {
    let runtime: any FFmpegRuntime
    let introspection: FFmpegIntrospection
}

protocol FFmpegRuntime: Sendable {
    nonisolated var cacheIdentity: String { get }
    nonisolated var displayName: String { get }

    nonisolated func runCommand(
        arguments: [String],
        outputLineHandler: (@Sendable (String) -> Void)?
    ) async throws -> FFmpegCommandResult

    nonisolated func runCommandSync(arguments: [String]) -> FFmpegCommandResult
}

protocol FFmpegRuntimeProviding {
    nonisolated func makeRuntime() -> (any FFmpegRuntime)?
}

enum FFmpegRuntimeError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let message):
            return message
        }
    }
}
