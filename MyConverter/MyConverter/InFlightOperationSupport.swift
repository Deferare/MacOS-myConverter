import Foundation

final class InFlightGroupedResult<Value>: @unchecked Sendable {
    nonisolated let group: DispatchGroup
    nonisolated(unsafe) var result: Result<Value, Error>?

    nonisolated init() {
        group = DispatchGroup()
        group.enter()
    }
}

final class InFlightContinuation<Value>: @unchecked Sendable {
    nonisolated(unsafe) var result: Value?
    nonisolated(unsafe) var continuations: [CheckedContinuation<Value, Never>] = []

    nonisolated init() {}
}

enum InFlightOperationSupport {
    nonisolated static func awaitContinuation<Value>(
        _ inFlight: InFlightContinuation<Value>,
        on queue: DispatchQueue
    ) async -> Value {
        await withCheckedContinuation { continuation in
            var resolved: Value?

            queue.sync {
                if let result = inFlight.result {
                    resolved = result
                } else {
                    inFlight.continuations.append(continuation)
                }
            }

            if let resolved {
                continuation.resume(returning: resolved)
            }
        }
    }

    @discardableResult
    nonisolated static func finishContinuation<Value>(
        _ resolved: Value,
        in inFlight: InFlightContinuation<Value>,
        on queue: DispatchQueue,
        updateState: () -> Void
    ) -> Value {
        let continuations: [CheckedContinuation<Value, Never>] = queue.sync {
            inFlight.result = resolved
            updateState()
            let continuations = inFlight.continuations
            inFlight.continuations.removeAll()
            return continuations
        }

        for continuation in continuations {
            continuation.resume(returning: resolved)
        }

        return resolved
    }

    nonisolated static func waitForGroupedResult<Value>(
        _ inFlight: InFlightGroupedResult<Value>,
        cachedValue: () -> Value?,
        missingResultError: @autoclosure () -> Error
    ) throws -> Value {
        inFlight.group.wait()
        if let result = inFlight.result {
            return try result.get()
        }

        if let cached = cachedValue() {
            return cached
        }

        throw missingResultError()
    }

    nonisolated static func finishGroupedResult<Value>(
        _ result: Result<Value, Error>,
        in inFlight: InFlightGroupedResult<Value>,
        on queue: DispatchQueue,
        updateState: (Result<Value, Error>) -> Void
    ) {
        queue.sync {
            updateState(result)
            inFlight.result = result
            inFlight.group.leave()
        }
    }
}
