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

func detachedTaskValue<T: Sendable>(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async -> T
) async -> T {
    let task = Task.detached(priority: priority) {
        await operation()
    }
    return await awaitDetachedTaskValue(task)
}

func throwingDetachedTaskValue<T: Sendable>(
    priority: TaskPriority? = nil,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    let task = Task.detached(priority: priority) {
        try await operation()
    }
    return try await awaitThrowingDetachedTaskValue(task)
}
