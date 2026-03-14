import Foundation

enum FFmpegExecutionContextSupport {
    nonisolated static func makeContext(
        using runtimeProvider: any FFmpegRuntimeProviding,
        inspect: (any FFmpegRuntime) throws -> FFmpegIntrospection
    ) -> FFmpegExecutionContext? {
        guard let runtime = runtimeProvider.makeRuntime(),
              let introspection = try? inspect(runtime) else {
            return nil
        }

        return FFmpegExecutionContext(
            runtime: runtime,
            introspection: introspection
        )
    }
}
