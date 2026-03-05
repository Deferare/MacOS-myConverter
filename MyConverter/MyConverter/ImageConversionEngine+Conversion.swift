import CoreGraphics
import Foundation
import ImageIO

extension ImageConversionEngine {
    nonisolated static func convert(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL {
        try OutputPathUtilities.removeFileIfExists(at: outputURL)

        let requiresAnimatedOutput =
            outputSettings.sourceIsAnimated &&
            outputSettings.preserveAnimation &&
            outputSettings.containerFormat.supportsAnimation
        let imageIOCanEncode = canEncodeWithImageIO(outputSettings.containerFormat)

        if let ffmpegOutput = try await attemptFFmpegConversion(
            inputURL: inputURL,
            outputURL: outputURL,
            outputSettings: outputSettings,
            allowFallbackOnFailure: imageIOCanEncode,
            onProgress: onProgress
        ) {
            return ffmpegOutput
        }

        if requiresAnimatedOutput {
            throw ImageConversionError.ffmpegUnavailableForAnimatedOutput
        }

        if !imageIOCanEncode {
            throw ImageConversionError.unsupportedOutputFormat(outputSettings.containerFormat)
        }

        return try await Task.detached(priority: .userInitiated) {
            try convertSyncUsingImageIO(
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                onProgress: onProgress
            )
        }.value
    }

    nonisolated static func ffmpegCanDecodeSource(
        ffmpegPath: String,
        inputURL: URL
    ) -> Bool {
        let stagedInputURL: URL
        do {
            stagedInputURL = try stageInputForFFmpeg(inputURL)
        } catch {
            return false
        }
        defer {
            try? OutputPathUtilities.removeFileIfExists(at: stagedInputURL)
        }

        let result = ProcessCommandRunner.runCommandSync(
            path: ffmpegPath,
            arguments: [
                "-hide_banner",
                "-loglevel", "error",
                "-i", stagedInputURL.path,
                "-map", "0:v:0",
                "-frames:v", "1",
                "-f", "null",
                "-"
            ]
        )
        return result.terminationStatus == 0
    }

    nonisolated private static func attemptFFmpegConversion(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        allowFallbackOnFailure: Bool,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL? {
        guard let ffmpegPath = FFmpegBinaryLocator.findPath() else {
            return nil
        }

        guard isFFmpegFormatSupported(outputSettings.containerFormat, ffmpegPath: ffmpegPath) else {
            return nil
        }

        do {
            try await runFFmpegConversion(
                ffmpegPath: ffmpegPath,
                inputURL: inputURL,
                outputURL: outputURL,
                outputSettings: outputSettings,
                onProgress: onProgress
            )
            return outputURL
        } catch {
            try? OutputPathUtilities.removeFileIfExists(at: outputURL)
            if !allowFallbackOnFailure ||
                (outputSettings.sourceIsAnimated && outputSettings.preserveAnimation && outputSettings.containerFormat.supportsAnimation) {
                throw error
            }
            return nil
        }
    }

    nonisolated private static func withStagedFFmpegInput<T>(
        _ inputURL: URL,
        operation: (URL) async throws -> T
    ) async throws -> T {
        try await FFmpegStagingSupport.withStagedInput(
            for: inputURL,
            makeError: { code, message in
                ImageConversionError.ffmpegFailed(code, message)
            },
            operation: operation
        )
    }

    nonisolated private static func runFFmpegConversion(
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) async throws {
        let introspection = try inspectFFmpeg(at: ffmpegPath)
        try await withStagedFFmpegInput(inputURL) { stagedInputURL in
            let selectedCodec = outputSettings.containerFormat.ffmpegEncoderCandidates.first(where: { introspection.encoders.contains($0) })

            if !outputSettings.containerFormat.ffmpegEncoderCandidates.isEmpty &&
                selectedCodec == nil &&
                !outputSettings.containerFormat.allowsFFmpegAutomaticCodec {
                throw ImageConversionError.ffmpegUnsupportedFormat(outputSettings.containerFormat)
            }

            if !outputSettings.containerFormat.ffmpegRequiredMuxers.isEmpty &&
                !outputSettings.containerFormat.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) }) {
                throw ImageConversionError.ffmpegUnsupportedFormat(outputSettings.containerFormat)
            }

            var args: [String] = [
                "-y",
                "-hide_banner",
                "-loglevel", "error",
                "-i", stagedInputURL.path
            ]

            if let resolution = outputSettings.resolution {
                let scaleFilter = "scale=w=\(resolution.width):h=\(resolution.height):force_original_aspect_ratio=decrease"
                args.append(contentsOf: ["-vf", scaleFilter])
            }

            let shouldPreserveAnimation =
                outputSettings.sourceIsAnimated &&
                outputSettings.preserveAnimation &&
                outputSettings.containerFormat.supportsAnimation

            if !shouldPreserveAnimation {
                args.append(contentsOf: ["-frames:v", "1"])
            }

            if let selectedCodec {
                args.append(contentsOf: ["-c:v", selectedCodec])
            }
            appendFFmpegFormatArguments(&args, outputSettings: outputSettings)

            if let preferredMuxer = outputSettings.containerFormat.preferredFFmpegMuxer,
               introspection.muxers.contains(preferredMuxer) {
                args.append(contentsOf: ["-f", preferredMuxer])
            }

            args.append(outputURL.path)

            try Task.checkCancellation()
            reportProgress(0.05, onProgress: onProgress)
            let result = try await ProcessCommandRunner.runCommand(path: ffmpegPath, arguments: args)
            try Task.checkCancellation()

            guard result.terminationStatus == 0 else {
                throw ImageConversionError.ffmpegFailed(result.terminationStatus, result.output)
            }

            reportProgress(1.0, onProgress: onProgress)
        }
    }

    nonisolated private static func stageInputForFFmpeg(_ inputURL: URL) throws -> URL {
        try FFmpegStagingSupport.stageInputURL(for: inputURL) { code, message in
            ImageConversionError.ffmpegFailed(code, message)
        }
    }

    nonisolated private static func appendFFmpegFormatArguments(
        _ args: inout [String],
        outputSettings: ImageOutputSettings
    ) {
        let formatID = outputSettings.containerFormat.normalizedID
        let qualityPercent = Int(((outputSettings.compressionQuality ?? 1.0) * 100).rounded())

        if formatID == "public.png" {
            if let compressionLevel = outputSettings.pngCompressionLevel {
                args.append(contentsOf: ["-compression_level", "\(max(0, min(compressionLevel, 9)))"])
            }
            return
        }

        if ["public.jpeg", "public.jpeg-2000", "org.webmproject.webp"].contains(formatID) {
            if outputSettings.compressionQuality != nil {
                args.append(contentsOf: ["-q:v", "\(ImageQualityOption.ffmpegQScale(fromPercent: qualityPercent))"])
            }
            return
        }

        if ["public.heic", "public.avif"].contains(formatID) {
            if outputSettings.compressionQuality != nil {
                args.append(contentsOf: ["-crf", "\(ImageQualityOption.ffmpegCRF(fromPercent: qualityPercent))"])
            }
            args.append(contentsOf: ["-pix_fmt", "yuv420p"])
            if formatID == "public.heic" {
                args.append(contentsOf: ["-tag:v", "hvc1"])
            }
            return
        }

        if formatID == "com.compuserve.gif",
           outputSettings.sourceIsAnimated,
           outputSettings.preserveAnimation {
            args.append(contentsOf: ["-loop", "0"])
        }
    }

    nonisolated private static func convertSyncUsingImageIO(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) throws -> URL {
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

    nonisolated private static func reportProgress(_ progress: Double, onProgress: @escaping ProgressHandler) {
        let clamped = min(max(progress, 0), 1)
        Task {
            await onProgress(clamped)
        }
    }
}
