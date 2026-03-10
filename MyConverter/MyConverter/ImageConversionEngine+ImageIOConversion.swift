import CoreGraphics
import Foundation
import ImageIO

extension ImageConversionEngine {
    nonisolated static func convertSyncUsingImageIO(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) throws -> URL {
        let token = PerformanceSignpost.begin("ImageEncode", message: inputURL.lastPathComponent)
        defer {
            PerformanceSignpost.end("ImageEncode", token: token, message: inputURL.lastPathComponent)
        }

        guard let outputUTTypeIdentifier = outputSettings.containerFormat.imageIOUTTypeIdentifier,
              imageIODestinationTypeIdentifiers().contains(outputUTTypeIdentifier.lowercased()) else {
            throw ImageConversionError.unsupportedOutputFormat(outputSettings.containerFormat)
        }

        try OutputPathUtilities.removeFileIfExists(at: outputURL)
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

        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            outputUTTypeIdentifier as CFString,
            1,
            nil
        ) else {
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
}
