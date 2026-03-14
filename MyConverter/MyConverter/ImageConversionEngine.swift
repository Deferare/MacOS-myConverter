import Foundation

struct ImageOutputSettings: Sendable {
    let containerFormat: ImageFormatOption
    let resolution: (width: Int, height: Int)?
    let compressionQuality: Double?
    let pngCompressionLevel: Int?
    let preserveAnimation: Bool
    let sourceIsAnimated: Bool
}

struct ImageSourceCapabilities: Sendable {
    let availableOutputFormats: [ImageFormatOption]
    let warningMessage: String?
    let errorMessage: String?
    let frameCount: Int
    let hasAlpha: Bool
}

enum ImageConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void

    nonisolated static let introspectionCacheQueue = DispatchQueue(label: "myconverter.image.ffmpeg.introspection.cache")
    nonisolated(unsafe) static var introspectionCache: [String: FFmpegIntrospection] = [:]
    nonisolated(unsafe) static var introspectionInFlight: [String: InFlightGroupedResult<FFmpegIntrospection>] = [:]
    nonisolated static let outputFormatCacheQueue = DispatchQueue(label: "myconverter.image.output.cache")
    nonisolated(unsafe) static var defaultOutputFormatsCache: [String: [ImageFormatOption]] = [:]
    nonisolated(unsafe) static var imageIODestinationTypeCache: Set<String>? = nil
    nonisolated(unsafe) static var imageIOAvailableFormatsCache: [ImageFormatOption]? = nil
    nonisolated static let sourceCapabilityCacheQueue = DispatchQueue(label: "myconverter.image.source.capability.cache")
    nonisolated(unsafe) static var sourceCapabilitiesCache: [String: ImageSourceCapabilities] = [:]
    nonisolated(unsafe) static var sourceCapabilitiesInFlight: [String: InFlightContinuation<ImageSourceCapabilities>] = [:]

    nonisolated static func ffmpegRuntime(
        using runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) -> (any FFmpegRuntime)? {
        runtimeProvider.makeRuntime()
    }

    nonisolated static func isFFmpegAvailable() -> Bool {
        ffmpegRuntime() != nil
    }
}

enum ImageConversionError: LocalizedError {
    case unreadableImage
    case noFramesFound
    case invalidSourceDimensions
    case unsupportedOutputFormat(ImageFormatOption)
    case ffmpegUnsupportedFormat(ImageFormatOption)
    case ffmpegUnavailableForAnimatedOutput
    case ffmpegFailed(Int32, String)
    case encodingFailed

    private enum Kind: Hashable {
        case unreadableImage
        case noFramesFound
        case invalidSourceDimensions
        case unsupportedOutputFormat
        case ffmpegUnsupportedFormat
        case ffmpegUnavailableForAnimatedOutput
        case ffmpegFailed
        case encodingFailed
    }

    private static let errorMessageByKind: [Kind: String] = [
        .unreadableImage: "Failed to read input image file.",
        .noFramesFound: "No image frame found in source file.",
        .invalidSourceDimensions: "Input image has invalid dimensions.",
        .ffmpegUnavailableForAnimatedOutput: "Animated output requires ffmpeg support for this format.",
        .ffmpegFailed: "FFmpeg image conversion failed.",
        .encodingFailed: "Failed to encode image with selected settings."
    ]

    private var kind: Kind {
        switch self {
        case .unreadableImage:
            .unreadableImage
        case .noFramesFound:
            .noFramesFound
        case .invalidSourceDimensions:
            .invalidSourceDimensions
        case .unsupportedOutputFormat:
            .unsupportedOutputFormat
        case .ffmpegUnsupportedFormat:
            .ffmpegUnsupportedFormat
        case .ffmpegUnavailableForAnimatedOutput:
            .ffmpegUnavailableForAnimatedOutput
        case .ffmpegFailed:
            .ffmpegFailed
        case .encodingFailed:
            .encodingFailed
        }
    }

    private var errorMessage: String {
        switch self {
        case .unsupportedOutputFormat(let format):
            return "\(format.displayName) output is not supported in this environment."
        case .ffmpegUnsupportedFormat(let format):
            return "\(format.displayName) output is not supported by the bundled ffmpeg build."
        default:
            return Self.errorMessageByKind[kind] ?? "Image conversion failed."
        }
    }

    var errorDescription: String? { errorMessage }
}
