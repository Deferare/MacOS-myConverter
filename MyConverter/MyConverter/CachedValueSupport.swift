import Foundation

enum CachedValueSupport {
    nonisolated static func resolve<Value>(
        readCached: () -> Value?,
        storeCached: (Value) -> Void,
        build: () -> Value
    ) -> Value {
        if let cached = readCached() {
            return cached
        }

        let resolved = build()
        storeCached(resolved)
        return resolved
    }
}
