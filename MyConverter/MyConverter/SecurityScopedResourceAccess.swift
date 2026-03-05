import Foundation

enum SecurityScopedResourceAccess {
    nonisolated static func withAccess<T>(
        to url: URL,
        operation: () throws -> T
    ) rethrows -> T {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation()
    }

    nonisolated static func withAccess<T>(
        to url: URL,
        operation: () async throws -> T
    ) async rethrows -> T {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation()
    }
}
