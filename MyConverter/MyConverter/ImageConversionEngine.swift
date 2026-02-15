import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct ImageOutputSettings: Sendable {
    let containerFormat: ImageContainerOption
    let resolution: (width: Int, height: Int)?
    let compressionQuality: Double?
}

struct ImageSourceCapabilities: Sendable {
    let availableOutputFormats: [ImageContainerOption]
    let warningMessage: String?
    let errorMessage: String?
}

enum ImageConversionEngine {
    typealias ProgressHandler = @Sendable (Double) async -> Void

    nonisolated static func sourceCapabilities(for inputURL: URL) async -> ImageSourceCapabilities {
        await Task.detached(priority: .userInitiated) {
            sourceCapabilitiesSync(for: inputURL)
        }.value
    }

    nonisolated static func uniqueOutputURL(
        for sourceURL: URL,
        format: ImageContainerOption,
        in outputDirectory: URL
    ) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = format.fileExtension
        var candidate = outputDirectory.appendingPathComponent("\(baseName).\(ext)")
        var index = 1

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = outputDirectory.appendingPathComponent("\(baseName)_converted_\(index).\(ext)")
            index += 1
        }

        return candidate
    }

    nonisolated static func temporaryOutputURL(for sourceURL: URL, format: ImageContainerOption) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = format.fileExtension
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(baseName)_working_\(UUID().uuidString).\(ext)")
    }

    nonisolated static func convert(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            try convertSync(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                onProgress: onProgress
            )
        }.value
    }

    nonisolated private static func sourceCapabilitiesSync(for inputURL: URL) -> ImageSourceCapabilities {
        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            return ImageSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "Could not parse input image file."
            )
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            return ImageSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No image frame found in source file."
            )
        }

        let availableOutputFormats = ImageContainerOption.systemSupportedCases

        if availableOutputFormats.isEmpty {
            return ImageSourceCapabilities(
                availableOutputFormats: [],
                warningMessage: nil,
                errorMessage: "No compatible output format is available on this system."
            )
        }

        let warningMessage = frameCount > 1
            ? "Animated image detected. Only the first frame will be converted."
            : nil

        return ImageSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warningMessage,
            errorMessage: nil
        )
    }

    nonisolated private static func convertSync(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) throws -> URL {
        try removeFileIfExists(at: outputURL)
        reportProgress(0, onProgress: onProgress)
        try Task.checkCancellation()

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            throw ImageConversionError.unreadableImage
        }

        guard CGImageSourceGetCount(source) > 0 else {
            throw ImageConversionError.noFramesFound
        }

        guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageConversionError.unreadableImage
        }

        let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]

        reportProgress(0.25, onProgress: onProgress)
        try Task.checkCancellation()

        let outputImage = try resizedImageIfNeeded(image, resolution: outputSettings.resolution)

        reportProgress(0.6, onProgress: onProgress)
        try Task.checkCancellation()

        let outputUTType = outputSettings.containerFormat.utType.identifier as CFString
        guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, outputUTType, 1, nil) else {
            throw ImageConversionError.unsupportedOutputFormat(outputSettings.containerFormat)
        }

        var destinationProperties = metadata ?? [:]
        if let quality = outputSettings.compressionQuality,
           outputSettings.containerFormat.supportsCompressionQuality {
            destinationProperties[kCGImageDestinationLossyCompressionQuality] = max(0, min(quality, 1))
        }

        CGImageDestinationAddImage(destination, outputImage, destinationProperties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageConversionError.encodingFailed
        }

        reportProgress(1, onProgress: onProgress)
        return outputURL
    }

    nonisolated private static func resizedImageIfNeeded(
        _ image: CGImage,
        resolution: (width: Int, height: Int)?
    ) throws -> CGImage {
        guard let resolution else {
            return image
        }

        let sourceWidth = CGFloat(image.width)
        let sourceHeight = CGFloat(image.height)
        guard sourceWidth > 0, sourceHeight > 0 else {
            throw ImageConversionError.invalidSourceDimensions
        }

        let targetWidth = CGFloat(max(1, resolution.width))
        let targetHeight = CGFloat(max(1, resolution.height))

        let scale = min(targetWidth / sourceWidth, targetHeight / sourceHeight)
        let outputWidth = max(Int((sourceWidth * scale).rounded()), 1)
        let outputHeight = max(Int((sourceHeight * scale).rounded()), 1)

        if outputWidth == image.width && outputHeight == image.height {
            return image
        }

        let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)
        guard let colorSpace else {
            throw ImageConversionError.encodingFailed
        }

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageConversionError.encodingFailed
        }

        context.interpolationQuality = .high
        context.draw(
            image,
            in: CGRect(x: 0, y: 0, width: CGFloat(outputWidth), height: CGFloat(outputHeight))
        )

        guard let resizedImage = context.makeImage() else {
            throw ImageConversionError.encodingFailed
        }

        return resizedImage
    }

    nonisolated private static func removeFileIfExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    nonisolated private static func reportProgress(_ progress: Double, onProgress: @escaping ProgressHandler) {
        let clamped = min(max(progress, 0), 1)
        Task {
            await onProgress(clamped)
        }
    }
}

enum ImageConversionError: LocalizedError {
    case unreadableImage
    case noFramesFound
    case invalidSourceDimensions
    case unsupportedOutputFormat(ImageContainerOption)
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
            return "\(format.rawValue) output is not supported on this system."
        case .encodingFailed:
            return "Failed to encode image with selected settings."
        }
    }
}
