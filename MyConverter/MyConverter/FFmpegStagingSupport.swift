import Foundation

enum FFmpegStagingSupport {
    struct StagedInputLease: Sendable {
        let cacheKey: String
        let stagedURL: URL
    }

    final class InFlightLease: @unchecked Sendable {
        nonisolated let group: DispatchGroup
        nonisolated(unsafe) var result: Result<StagedInputLease, Error>?

        nonisolated init() {
            group = DispatchGroup()
            group.enter()
        }
    }

    nonisolated static let leaseQueue = DispatchQueue(label: "myconverter.ffmpeg.staging.lease")
    nonisolated(unsafe) static var activeLeases: [String: ActiveLease] = [:]
    nonisolated(unsafe) static var inFlightLeases: [String: InFlightLease] = [:]

    nonisolated static func withStagedInput<T>(
        for inputURL: URL,
        makeError: (Int32, String) -> Error,
        operation: (URL) async throws -> T
    ) async throws -> T {
        let lease = try acquireLease(for: inputURL, makeError: makeError)
        defer {
            releaseLease(lease)
        }
        return try await operation(lease.stagedURL)
    }

    nonisolated static func withStagedInputSync<T>(
        for inputURL: URL,
        makeError: (Int32, String) -> Error,
        operation: (URL) throws -> T
    ) throws -> T {
        let lease = try acquireLease(for: inputURL, makeError: makeError)
        defer {
            releaseLease(lease)
        }
        return try operation(lease.stagedURL)
    }
}
