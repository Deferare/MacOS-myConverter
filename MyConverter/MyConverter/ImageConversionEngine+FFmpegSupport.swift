import Foundation

extension ImageConversionEngine {
    nonisolated static func withStagedFFmpegInput<T>(
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

    nonisolated static func appendFFmpegFormatArguments(
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

    nonisolated static func reportProgress(_ progress: Double, onProgress: @escaping ProgressHandler) {
        let clamped = min(max(progress, 0), 1)
        Task {
            await onProgress(clamped)
        }
    }
}
