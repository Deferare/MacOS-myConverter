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
