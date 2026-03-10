import Foundation

extension ImageConversionEngine {
    nonisolated static func convert(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        ffmpegContext: FFmpegExecutionContext? = nil,
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
            ffmpegContext: ffmpegContext,
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
}
