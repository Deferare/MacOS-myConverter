import Foundation

func awaitDetachedTaskValue<T: Sendable>(_ task: Task<T, Never>) async -> T {
    await withTaskCancellationHandler {
        await task.value
    } onCancel: {
        task.cancel()
    }
}

func awaitThrowingDetachedTaskValue<T: Sendable>(_ task: Task<T, Error>) async throws -> T {
    try await withTaskCancellationHandler {
        try await task.value
    } onCancel: {
        task.cancel()
    }
}
