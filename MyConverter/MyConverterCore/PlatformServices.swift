import Foundation

struct PlatformServices {
    let ffmpegRuntimeProvider: any FFmpegRuntimeProviding
    let outputDestinationCoordinator: any OutputDestinationCoordinator
    let thumbnailProvider: any ThumbnailProvider

    static func makeDefault() -> Self {
        #if os(iOS)
        return Self(
            ffmpegRuntimeProvider: DefaultFFmpegRuntimeProvider(),
            outputDestinationCoordinator: IOSOutputDestinationCoordinator.shared,
            thumbnailProvider: QuickLookThumbnailProviderService.shared
        )
        #else
        return Self(
            ffmpegRuntimeProvider: DefaultFFmpegRuntimeProvider(),
            outputDestinationCoordinator: MacOutputDestinationCoordinator.shared,
            thumbnailProvider: QuickLookThumbnailProviderService.shared
        )
        #endif
    }
}

struct DefaultFFmpegRuntimeProvider: FFmpegRuntimeProviding, Sendable {
    nonisolated init() {}

    nonisolated func makeRuntime() -> (any FFmpegRuntime)? {
        #if os(iOS)
        return InProcessFFmpegRuntime.makeIfAvailable()
        #else
        guard let path = FFmpegBinaryLocator.findPath() else {
            return nil
        }
        return ProcessFFmpegRuntime(path: path)
        #endif
    }
}
