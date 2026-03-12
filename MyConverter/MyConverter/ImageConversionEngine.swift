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

    nonisolated static func isFFmpegAvailable() -> Bool {
        DefaultFFmpegRuntimeProvider().makeRuntime() != nil
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

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Failed to read input image file."
        case .noFramesFound:
            return "No image frame found in source file."
        case .invalidSourceDimensions:
            return "Input image has invalid dimensions."
        case .unsupportedOutputFormat(let format):
            return "\(format.displayName) output is not supported in this environment."
        case .ffmpegUnsupportedFormat(let format):
            return "\(format.displayName) output is not supported by the bundled ffmpeg build."
        case .ffmpegUnavailableForAnimatedOutput:
            return "Animated output requires ffmpeg support for this format."
        case .ffmpegFailed:
            return "FFmpeg image conversion failed."
        case .encodingFailed:
            return "Failed to encode image with selected settings."
        }
    }
}
