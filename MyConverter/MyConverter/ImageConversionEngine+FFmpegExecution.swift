import Foundation

extension ImageConversionEngine {
    nonisolated static func attemptFFmpegConversion(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        allowFallbackOnFailure: Bool,
        ffmpegContext: FFmpegExecutionContext? = nil,
        runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider(),
        onProgress: @escaping ProgressHandler
    ) async throws -> URL? {
        guard let ffmpegContext = ffmpegContext ?? makeFFmpegExecutionContext(using: runtimeProvider) else {
            return nil
        }

        guard isFFmpegFormatSupported(
            outputSettings.containerFormat,
            introspection: ffmpegContext.introspection
        ) else {
            return nil
        }

        do {
            try await runFFmpegConversion(
                ffmpegContext: ffmpegContext,
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
        ffmpegContext: FFmpegExecutionContext,
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) async throws {
        try await withStagedFFmpegInput(inputURL) { stagedInputURL in
            let selectedCodec = outputSettings.containerFormat.ffmpegEncoderCandidates.first(where: {
                ffmpegContext.introspection.videoEncoders.contains($0)
            })

            if !outputSettings.containerFormat.ffmpegEncoderCandidates.isEmpty &&
                selectedCodec == nil &&
                !outputSettings.containerFormat.allowsFFmpegAutomaticCodec {
                throw ImageConversionError.ffmpegUnsupportedFormat(outputSettings.containerFormat)
            }

            if !outputSettings.containerFormat.ffmpegRequiredMuxers.isEmpty &&
                !outputSettings.containerFormat.ffmpegRequiredMuxers.contains(where: {
                    ffmpegContext.introspection.muxers.contains($0)
                }) {
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
               ffmpegContext.introspection.muxers.contains(preferredMuxer) {
                args.append(contentsOf: ["-f", preferredMuxer])
            }

            args.append(outputURL.path)

            try Task.checkCancellation()
            reportProgress(0.05, onProgress: onProgress)
            let token = PerformanceSignpost.begin("ImageEncode", message: inputURL.lastPathComponent)
            let result: FFmpegCommandResult
            do {
                result = try await ffmpegContext.runtime.runCommand(
                    arguments: args,
                    outputLineHandler: nil
                )
                PerformanceSignpost.end("ImageEncode", token: token, message: inputURL.lastPathComponent)
            } catch {
                PerformanceSignpost.end("ImageEncode", token: token, message: "failed")
                throw error
            }
            try Task.checkCancellation()

            guard result.terminationStatus == 0 else {
                throw ImageConversionError.ffmpegFailed(result.terminationStatus, result.output)
            }

            reportProgress(1.0, onProgress: onProgress)
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

    nonisolated static func reportProgress(_ progress: Double, onProgress: @escaping ProgressHandler) {
        let clamped = min(max(progress, 0), 1)
        Task {
            await onProgress(clamped)
        }
    }

    nonisolated static func makeFFmpegExecutionContext(
        using runtimeProvider: any FFmpegRuntimeProviding = DefaultFFmpegRuntimeProvider()
    ) -> FFmpegExecutionContext? {
        FFmpegExecutionContextSupport.makeContext(
            using: runtimeProvider,
            inspect: { try inspectFFmpeg(using: $0) }
        )
    }

    nonisolated static func makeFFmpegExecutionContext() -> FFmpegExecutionContext? {
        makeFFmpegExecutionContext(using: DefaultFFmpegRuntimeProvider())
    }
}
