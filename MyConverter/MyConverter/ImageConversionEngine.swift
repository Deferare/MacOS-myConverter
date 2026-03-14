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

        private static let kindMatchers: [(kind: Self, matches: (ImageConversionError) -> Bool)] = [
            (.unreadableImage, {
                if case .unreadableImage = $0 { return true }
                return false
            }),
            (.noFramesFound, {
                if case .noFramesFound = $0 { return true }
                return false
            }),
            (.invalidSourceDimensions, {
                if case .invalidSourceDimensions = $0 { return true }
                return false
            }),
            (.unsupportedOutputFormat, {
                if case .unsupportedOutputFormat = $0 { return true }
                return false
            }),
            (.ffmpegUnsupportedFormat, {
                if case .ffmpegUnsupportedFormat = $0 { return true }
                return false
            }),
            (.ffmpegUnavailableForAnimatedOutput, {
                if case .ffmpegUnavailableForAnimatedOutput = $0 { return true }
                return false
            }),
            (.ffmpegFailed, {
                if case .ffmpegFailed = $0 { return true }
                return false
            }),
            (.encodingFailed, {
                if case .encodingFailed = $0 { return true }
                return false
            })
        ]

        static func resolve(from error: ImageConversionError) -> Self {
            Self.kindMatchers.first(where: { $0.matches(error) })?.kind ?? .encodingFailed
        }
    }

    private static let errorMessageProviderByKind: [Kind: (Self) -> String] = [
        .unreadableImage: { _ in "Failed to read input image file." },
        .noFramesFound: { _ in "No image frame found in source file." },
        .invalidSourceDimensions: { _ in "Input image has invalid dimensions." },
        .unsupportedOutputFormat: { error in
            guard case let .unsupportedOutputFormat(format) = error else {
                return "Image output is not supported in this environment."
            }
            return "\(format.displayName) output is not supported in this environment."
        },
        .ffmpegUnsupportedFormat: { error in
            guard case let .ffmpegUnsupportedFormat(format) = error else {
                return "Image output is not supported by the bundled ffmpeg build."
            }
            return "\(format.displayName) output is not supported by the bundled ffmpeg build."
        },
        .ffmpegUnavailableForAnimatedOutput: { _ in
            "Animated output requires ffmpeg support for this format."
        },
        .ffmpegFailed: { _ in "FFmpeg image conversion failed." },
        .encodingFailed: { _ in "Failed to encode image with selected settings." }
    ]

    private var kind: Kind {
        Kind.resolve(from: self)
    }

    private var errorMessage: String {
        Self.errorMessageProviderByKind[kind]?(self) ?? "Image conversion failed."
    }

    var errorDescription: String? { errorMessage }
}
