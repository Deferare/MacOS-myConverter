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
    nonisolated(unsafe) static var introspectionInFlight: [String: InFlightFFmpegIntrospection] = [:]
    nonisolated static let outputFormatCacheQueue = DispatchQueue(label: "myconverter.image.output.cache")
    nonisolated(unsafe) static var defaultOutputFormatsCache: [String: [ImageFormatOption]] = [:]
    nonisolated(unsafe) static var imageIODestinationTypeCache: Set<String>? = nil
    nonisolated(unsafe) static var imageIOAvailableFormatsCache: [ImageFormatOption]? = nil
    nonisolated static let sourceCapabilityCacheQueue = DispatchQueue(label: "myconverter.image.source.capability.cache")
    nonisolated(unsafe) static var sourceCapabilitiesCache: [String: ImageSourceCapabilities] = [:]
    nonisolated(unsafe) static var sourceCapabilitiesInFlight: [String: InFlightCapability<ImageSourceCapabilities>] = [:]

    struct FFmpegIntrospection {
        let encoders: Set<String>
        let muxers: Set<String>
        let muxerExtensions: [String: [String]]
    }

    struct FFmpegExecutionContext: Sendable {
        let ffmpegPath: String
        let introspection: FFmpegIntrospection
    }

    final class InFlightFFmpegIntrospection: @unchecked Sendable {
        nonisolated let group: DispatchGroup
        nonisolated(unsafe) var result: Result<FFmpegIntrospection, Error>?

        nonisolated init() {
            group = DispatchGroup()
            group.enter()
        }
    }

    final class InFlightCapability<Value>: @unchecked Sendable {
        nonisolated(unsafe) var result: Value?
        nonisolated(unsafe) var continuations: [CheckedContinuation<Value, Never>] = []

        nonisolated init() {}
    }

    struct FFmpegMuxerDescriptor {
        let name: String
        let description: String
    }

    nonisolated static func isFFmpegAvailable() -> Bool {
        FFmpegBinaryLocator.findPath() != nil
    }

    nonisolated static func uniqueOutputURL(
        for sourceURL: URL,
        format: ImageFormatOption,
        in outputDirectory: URL
    ) -> URL {
        OutputPathUtilities.uniqueOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension,
            in: outputDirectory
        )
    }

    nonisolated static func temporaryOutputURL(for sourceURL: URL, format: ImageFormatOption) -> URL {
        OutputPathUtilities.temporaryOutputURL(
            for: sourceURL,
            fileExtension: format.fileExtension
        )
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
