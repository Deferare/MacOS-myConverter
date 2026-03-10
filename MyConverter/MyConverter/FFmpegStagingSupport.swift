import Foundation

enum FFmpegStagingSupport {
    private enum LeaseAcquisition {
        case active(StagedInputLease)
        case wait(InFlightLease)
        case create(InFlightLease)
    }

    struct StagedInputLease: Sendable {
        let cacheKey: String
        let stagedURL: URL
    }

    private struct ActiveLease {
        let lease: StagedInputLease
        var referenceCount: Int
    }

    final class InFlightLease: @unchecked Sendable {
        nonisolated let group: DispatchGroup
        nonisolated(unsafe) var result: Result<StagedInputLease, Error>?

        nonisolated init() {
            group = DispatchGroup()
            group.enter()
        }
    }

    nonisolated private static let leaseQueue = DispatchQueue(label: "myconverter.ffmpeg.staging.lease")
    nonisolated(unsafe) private static var activeLeases: [String: ActiveLease] = [:]
    nonisolated(unsafe) private static var inFlightLeases: [String: InFlightLease] = [:]

    nonisolated static func acquireLease(
        for inputURL: URL,
        makeError: (Int32, String) -> Error
    ) throws -> StagedInputLease {
        let cacheKey = makeCacheKey(for: inputURL)
        let acquisition = leaseQueue.sync { () -> LeaseAcquisition in
            if var active = activeLeases[cacheKey] {
                active.referenceCount += 1
                activeLeases[cacheKey] = active
                return .active(active.lease)
            }

            if let existing = inFlightLeases[cacheKey] {
                return .wait(existing)
            }

            let created = InFlightLease()
            inFlightLeases[cacheKey] = created
            return .create(created)
        }

        switch acquisition {
        case .active(let lease):
            PerformanceSignpost.event("FFmpegStageReuse", message: inputURL.lastPathComponent)
            return lease
        case .wait(let inFlight):
            return try waitForLease(inFlight, cacheKey: cacheKey, sourceURL: inputURL)
        case .create(let inFlight):
            return try createLease(
                inFlight,
                cacheKey: cacheKey,
                inputURL: inputURL,
                makeError: makeError
            )
        }
    }

    nonisolated static func releaseLease(_ lease: StagedInputLease) {
        let removalURL: URL? = leaseQueue.sync {
            guard var active = activeLeases[lease.cacheKey] else { return nil }
            active.referenceCount -= 1
            if active.referenceCount > 0 {
                activeLeases[lease.cacheKey] = active
                return nil
            }

            activeLeases[lease.cacheKey] = nil
            return active.lease.stagedURL
        }

        guard let removalURL else { return }
        try? OutputPathUtilities.removeFileIfExists(at: removalURL)
        PerformanceSignpost.event("FFmpegStageRelease", message: removalURL.lastPathComponent)
    }

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

    nonisolated private static func createStagedInputURL(
        for inputURL: URL,
        makeError: (Int32, String) -> Error
    ) throws -> URL {
        do {
            return try OutputPathUtilities.stageInputURL(for: inputURL)
        } catch let stagingError as OutputPathUtilities.StagedInputError {
            switch stagingError {
            case .stagingDirectoryCreationFailed(let path, let message):
                throw makeError(
                    -1,
                    "Failed to prepare ffmpeg staging directory (\(path)): \(message)"
                )
            case .stagingCopyFailed(let sourcePath, let destinationPath, let message):
                throw makeError(
                    -1,
                    "Failed to stage input file for ffmpeg. Source: \(sourcePath), Destination: \(destinationPath), Detail: \(message)"
                )
            }
        } catch {
            throw makeError(
                -1,
                "Failed to stage input file for ffmpeg: \(error.localizedDescription)"
            )
        }
    }

    nonisolated private static func makeCacheKey(for inputURL: URL) -> String {
        OutputPathUtilities.fileFingerprint(for: inputURL)
    }

    nonisolated private static func waitForLease(
        _ inFlight: InFlightLease,
        cacheKey: String,
        sourceURL: URL
    ) throws -> StagedInputLease {
        inFlight.group.wait()

        return try leaseQueue.sync {
            if var active = activeLeases[cacheKey] {
                active.referenceCount += 1
                activeLeases[cacheKey] = active
                PerformanceSignpost.event("FFmpegStageReuse", message: sourceURL.lastPathComponent)
                return active.lease
            }

            if let result = inFlight.result {
                return try result.get()
            }

            throw makeInFlightResolutionError(for: sourceURL)
        }
    }

    nonisolated private static func createLease(
        _ inFlight: InFlightLease,
        cacheKey: String,
        inputURL: URL,
        makeError: (Int32, String) -> Error
    ) throws -> StagedInputLease {
        let token = PerformanceSignpost.begin("FFmpegStageInput", message: inputURL.lastPathComponent)
        let result: Result<StagedInputLease, Error>
        do {
            let stagedURL = try createStagedInputURL(for: inputURL, makeError: makeError)
            let lease = StagedInputLease(cacheKey: cacheKey, stagedURL: stagedURL)
            result = .success(lease)
            PerformanceSignpost.end("FFmpegStageInput", token: token, message: inputURL.lastPathComponent)
        } catch {
            result = .failure(error)
            PerformanceSignpost.end("FFmpegStageInput", token: token, message: "failed")
        }

        leaseQueue.sync {
            if case let .success(lease) = result {
                activeLeases[cacheKey] = ActiveLease(lease: lease, referenceCount: 1)
            }
            inFlight.result = result
            inFlightLeases[cacheKey] = nil
            inFlight.group.leave()
        }

        switch result {
        case .success(let lease):
            PerformanceSignpost.event("FFmpegStageCreate", message: inputURL.lastPathComponent)
            return lease
        case .failure(let error):
            throw error
        }
    }

    nonisolated private static func makeInFlightResolutionError(for inputURL: URL) -> Error {
        NSError(
            domain: "FFmpegStagingSupport",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Staged input did not resolve for \(inputURL.lastPathComponent)."
            ]
        )
    }
}
