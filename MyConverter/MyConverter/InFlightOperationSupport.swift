import Foundation

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

    nonisolated static func loadCachedGroupedValue<Value>(
        cacheKey: String,
        on queue: DispatchQueue,
        cachedValue: () -> Value?,
        existingInFlight: () -> InFlightGroupedResult<Value>?,
        storeInFlight: (InFlightGroupedResult<Value>?) -> Void,
        missingResultError: @autoclosure () -> Error,
        build: () throws -> Value,
        storeCachedValue: (Value) -> Void
    ) throws -> Value {
        if let cached = queue.sync(execute: cachedValue) {
            return cached
        }

        let (inFlight, shouldBuild) = queue.sync { () -> (InFlightGroupedResult<Value>, Bool) in
            if let existing = existingInFlight() {
                return (existing, false)
            }

            let created = InFlightGroupedResult<Value>()
            storeInFlight(created)
            return (created, true)
        }

        if !shouldBuild {
            return try waitForGroupedResult(
                inFlight,
                cachedValue: { queue.sync(execute: cachedValue) },
                missingResultError: missingResultError()
            )
        }

        do {
            let resolved = try build()
            finishGroupedResult(.success(resolved), in: inFlight, on: queue) { result in
                if case .success(let resolved) = result {
                    storeCachedValue(resolved)
                }
                storeInFlight(nil)
            }
            return resolved
        } catch {
            finishGroupedResult(.failure(error), in: inFlight, on: queue) { _ in
                storeInFlight(nil)
            }
            throw error
        }
    }

    nonisolated static func loadCachedAsyncValue<Value>(
        cacheKey: String,
        on queue: DispatchQueue,
        cachedValue: () -> Value?,
        existingInFlight: () -> InFlightContinuation<Value>?,
        storeInFlight: (InFlightContinuation<Value>?) -> Void,
        build: () async -> Value,
        storeCachedValue: (Value) -> Void
    ) async -> Value {
        if let cached = queue.sync(execute: cachedValue) {
            return cached
        }

        let (inFlight, shouldBuild) = queue.sync { () -> (InFlightContinuation<Value>, Bool) in
            if let existing = existingInFlight() {
                return (existing, false)
            }

            let created = InFlightContinuation<Value>()
            storeInFlight(created)
            return (created, true)
        }

        if !shouldBuild {
            return await awaitContinuation(inFlight, on: queue)
        }

        let resolved = await build()
        return finishContinuation(resolved, in: inFlight, on: queue) {
            storeCachedValue(resolved)
            storeInFlight(nil)
        }
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
