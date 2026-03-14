import Foundation

extension ContentViewModel {
    nonisolated static func collectPreparedSourceValues<Value: Sendable>(
        from preparedSources: [PreparedSourceConversion],
        buildValue: @escaping @Sendable (PreparedSourceConversion) async -> Value
    ) async -> [String: Value] {
        await withTaskGroup(
            of: (String, Value)?.self,
            returning: [String: Value].self
        ) { group in
            for preparedSource in preparedSources {
                group.addTask {
                    await SecurityScopedResourceAccess.withAccess(to: preparedSource.sourceURL) {
                        let value = await buildValue(preparedSource)
                        return (preparedSource.sourceID, value)
                    }
                }
            }

            var prepared: [String: Value] = [:]
            for await result in group {
                guard let (sourceID, value) = result else { continue }
                prepared[sourceID] = value
            }
            return prepared
        }
    }

    nonisolated static func prepareBatchExecutionEnvironment<Value: Sendable>(
        preparedSources: [PreparedSourceConversion],
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider(),
        makeFFmpegContext: @escaping @Sendable (any FFmpegRuntimeProviding) -> FFmpegExecutionContext?,
        buildValue: @escaping @Sendable (PreparedSourceConversion) async -> Value,
        makeEnvironment: @escaping @Sendable (FFmpegExecutionContext?, [String: Value]) -> BatchExecutionEnvironment
    ) async -> BatchExecutionEnvironment {
        let ffmpegContext = makeFFmpegContext(runtimeProvider)
        let preparedValues = await collectPreparedSourceValues(
            from: preparedSources,
            buildValue: buildValue
        )
        return makeEnvironment(ffmpegContext, preparedValues)
    }
}
