import CoreGraphics
import Foundation
import ImageIO

extension ImageConversionEngine {
    nonisolated static func sourceCapabilities(for inputURL: URL) async -> ImageSourceCapabilities {
        await Task.detached(priority: .userInitiated) {
            sourceCapabilitiesSync(for: inputURL)
        }.value
    }

    nonisolated private static func makeSourceCapabilities(
        availableOutputFormats: [ImageFormatOption],
        warningMessage: String?,
        errorMessage: String?,
        frameCount: Int,
        hasAlpha: Bool
    ) -> ImageSourceCapabilities {
        ImageSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: errorMessage,
            frameCount: frameCount,
            hasAlpha: hasAlpha
        )
    }

    nonisolated private static func sourceCapabilitiesSync(for inputURL: URL) -> ImageSourceCapabilities {
        let availableOutputFormats = defaultOutputFormats()
        let ffmpegPath = FFmpegBinaryLocator.findPath()

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            if let ffmpegPath,
               ffmpegCanDecodeSource(ffmpegPath: ffmpegPath, inputURL: inputURL) {
                return makeSourceCapabilities(
                    availableOutputFormats: availableOutputFormats,
                    warningMessage: "Image metadata could not be read by ImageIO. Conversion will rely on ffmpeg.",
                    errorMessage: nil,
                    frameCount: 1,
                    hasAlpha: false
                )
            }

            return makeSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "Could not parse input image file.",
                frameCount: 0,
                hasAlpha: false
            )
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            return makeSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No image frame found in source file.",
                frameCount: 0,
                hasAlpha: false
            )
        }

        let hasAlpha = detectHasAlpha(in: source)

        if availableOutputFormats.isEmpty {
            return makeSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No compatible output format is available on this system.",
                frameCount: frameCount,
                hasAlpha: hasAlpha
            )
        }

        var warnings: [String] = []
        if frameCount > 1 {
            warnings.append("Animated image detected.")
            if ffmpegPath == nil {
                warnings.append("ffmpeg is unavailable, so only the first frame can be exported.")
            }
        }

        return makeSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warnings.isEmpty ? nil : warnings.joined(separator: " "),
            errorMessage: nil,
            frameCount: frameCount,
            hasAlpha: hasAlpha
        )
    }

    nonisolated private static func detectHasAlpha(in source: CGImageSource) -> Bool {
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let hasAlpha = properties[kCGImagePropertyHasAlpha] as? Bool {
            return hasAlpha
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return false
        }

        switch image.alphaInfo {
        case .first, .last, .premultipliedFirst, .premultipliedLast, .alphaOnly:
            return true
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        @unknown default:
            return false
        }
    }
}
