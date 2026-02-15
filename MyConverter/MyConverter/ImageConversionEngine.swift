import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

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
    nonisolated private static let introspectionCacheQueue = DispatchQueue(label: "myconverter.image.ffmpeg.introspection.cache")
    nonisolated(unsafe) private static var introspectionCache: [String: FFmpegIntrospection] = [:]
    nonisolated private static let ffmpegPathCacheQueue = DispatchQueue(label: "myconverter.image.ffmpeg.path.cache")
    nonisolated(unsafe) private static var ffmpegPathCache: String?? = nil
    nonisolated(unsafe) private static var ffmpegPathLookupTime: UInt64 = 0
    nonisolated private static let ffmpegPathNilCacheTTL: UInt64 = 30_000_000_000
    nonisolated private static let outputFormatCacheQueue = DispatchQueue(label: "myconverter.image.output.cache")
    nonisolated(unsafe) private static var defaultOutputFormatsCache: [String: [ImageFormatOption]] = [:]
    nonisolated(unsafe) private static var imageIODestinationTypeCache: Set<String>? = nil
    nonisolated(unsafe) private static var imageIOAvailableFormatsCache: [ImageFormatOption]? = nil

    nonisolated static func isFFmpegAvailable() -> Bool {
        findFFmpegPath() != nil
    }

    nonisolated static func defaultOutputFormats() -> [ImageFormatOption] {
        let imageIOFormats = imageIOAvailableFormats()

        guard let ffmpegPath = findFFmpegPath() else {
            return imageIOFormats
        }

        if let cached = outputFormatCacheQueue.sync(execute: { defaultOutputFormatsCache[ffmpegPath] }) {
            return cached
        }

        guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
            return imageIOFormats
        }

        let discoveredFFmpegFormats = ffmpegDiscoveredFormats(from: introspection)
        let candidates = ImageFormatOption.deduplicatedAndSorted(
            imageIOFormats + ImageFormatOption.ffmpegKnownFormats + discoveredFFmpegFormats
        )
        let ffmpegFormats = detectFFmpegSupportedOutputFormats(
            candidateFormats: candidates,
            introspection: introspection
        )

        let resolved = mergedFormats(primary: ffmpegFormats, secondary: imageIOFormats)
        outputFormatCacheQueue.sync {
            defaultOutputFormatsCache[ffmpegPath] = resolved
        }
        return resolved
    }

    nonisolated static func sourceCapabilities(for inputURL: URL) async -> ImageSourceCapabilities {
        await Task.detached(priority: .userInitiated) {
            sourceCapabilitiesSync(for: inputURL)
        }.value
    }

    nonisolated static func uniqueOutputURL(
        for sourceURL: URL,
        format: ImageFormatOption,
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

    nonisolated static func temporaryOutputURL(for sourceURL: URL, format: ImageFormatOption) -> URL {
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
        try removeFileIfExists(at: outputURL)

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

    nonisolated private static func sourceCapabilitiesSync(for inputURL: URL) -> ImageSourceCapabilities {
        let availableOutputFormats = defaultOutputFormats()

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil) else {
            if isFFmpegAvailable() {
                return ImageSourceCapabilities(
                    availableOutputFormats: availableOutputFormats,
                    warningMessage: "Image metadata could not be read by ImageIO. Conversion will rely on ffmpeg.",
                    errorMessage: nil,
                    frameCount: 1,
                    hasAlpha: false
                )
            }

            return ImageSourceCapabilities(
                availableOutputFormats: availableOutputFormats,
                warningMessage: nil,
                errorMessage: "Could not parse input image file.",
                frameCount: 0,
                hasAlpha: false
            )
        }

        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 0 else {
            return ImageSourceCapabilities(
                availableOutputFormats: availableOutputFormats,
                warningMessage: nil,
                errorMessage: "No image frame found in source file.",
                frameCount: 0,
                hasAlpha: false
            )
        }

        let hasAlpha = detectHasAlpha(in: source)

        if availableOutputFormats.isEmpty {
            return ImageSourceCapabilities(
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
            if !isFFmpegAvailable() {
                warnings.append("ffmpeg is unavailable, so only the first frame can be exported.")
            }
        }

        return ImageSourceCapabilities(
            availableOutputFormats: availableOutputFormats,
            warningMessage: warnings.isEmpty ? nil : warnings.joined(separator: " "),
            errorMessage: nil,
            frameCount: frameCount,
            hasAlpha: hasAlpha
        )
    }

    nonisolated private static func attemptFFmpegConversion(
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        allowFallbackOnFailure: Bool,
        onProgress: @escaping ProgressHandler
    ) async throws -> URL? {
        guard let ffmpegPath = findFFmpegPath() else {
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
            try? removeFileIfExists(at: outputURL)
            if !allowFallbackOnFailure ||
                (outputSettings.sourceIsAnimated && outputSettings.preserveAnimation && outputSettings.containerFormat.supportsAnimation) {
                throw error
            }
            return nil
        }
    }

    nonisolated private static func runFFmpegConversion(
        ffmpegPath: String,
        inputURL: URL,
        outputURL: URL,
        outputSettings: ImageOutputSettings,
        onProgress: @escaping ProgressHandler
    ) async throws {
        let introspection = try inspectFFmpeg(at: ffmpegPath)

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
            "-i", inputURL.path
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
        let result = try await runCommand(path: ffmpegPath, arguments: args)
        try Task.checkCancellation()

        guard result.terminationStatus == 0 else {
            throw ImageConversionError.ffmpegFailed(result.terminationStatus, result.output)
        }

        reportProgress(1.0, onProgress: onProgress)
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

    nonisolated private static func mergedFormats(
        primary: [ImageFormatOption],
        secondary: [ImageFormatOption]
    ) -> [ImageFormatOption] {
        ImageFormatOption.deduplicatedAndSorted(primary + secondary)
    }

    nonisolated private static func ffmpegDiscoveredFormats(from introspection: FFmpegIntrospection) -> [ImageFormatOption] {
        var discovered: [ImageFormatOption] = []

        for (muxer, extensions) in introspection.muxerExtensions {
            for ext in extensions {
                discovered.append(ImageFormatOption.fromFFmpegExtension(ext, muxer: muxer))
            }
        }

        return ImageFormatOption.deduplicatedAndSorted(discovered)
    }

    nonisolated private static func imageIODestinationTypeIdentifiers() -> Set<String> {
        if let cached = outputFormatCacheQueue.sync(execute: { imageIODestinationTypeCache }) {
            return cached
        }

        let resolved = Set((CGImageDestinationCopyTypeIdentifiers() as? [String] ?? []).map { $0.lowercased() })
        outputFormatCacheQueue.sync {
            imageIODestinationTypeCache = resolved
        }
        return resolved
    }

    nonisolated private static func imageIOAvailableFormats() -> [ImageFormatOption] {
        if let cached = outputFormatCacheQueue.sync(execute: { imageIOAvailableFormatsCache }) {
            return cached
        }

        let identifiers = (CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
        let options = identifiers.map { ImageFormatOption.fromImageIOTypeIdentifier($0) }
        let resolved = ImageFormatOption.deduplicatedAndSorted(options)
        outputFormatCacheQueue.sync {
            imageIOAvailableFormatsCache = resolved
        }
        return resolved
    }

    nonisolated private static func isFFmpegFormatSupported(_ format: ImageFormatOption, ffmpegPath: String) -> Bool {
        guard let introspection = try? inspectFFmpeg(at: ffmpegPath) else {
            return false
        }

        return isFFmpegFormatSupported(format, introspection: introspection)
    }

    nonisolated private static func canEncodeWithImageIO(_ format: ImageFormatOption) -> Bool {
        guard let identifier = format.imageIOUTTypeIdentifier?.lowercased() else {
            return false
        }
        return imageIODestinationTypeIdentifiers().contains(identifier)
    }

    private struct FFmpegIntrospection {
        let encoders: Set<String>
        let muxers: Set<String>
        let muxerExtensions: [String: [String]]
    }

    private struct FFmpegMuxerDescriptor {
        let name: String
        let description: String
    }

    nonisolated private static func detectFFmpegSupportedOutputFormats(
        candidateFormats: [ImageFormatOption],
        introspection: FFmpegIntrospection
    ) -> [ImageFormatOption] {
        return ImageFormatOption.deduplicatedAndSorted(candidateFormats).filter { format in
            isFFmpegFormatSupported(format, introspection: introspection)
        }
    }

    nonisolated private static func isFFmpegFormatSupported(
        _ format: ImageFormatOption,
        introspection: FFmpegIntrospection
    ) -> Bool {
        let hasMuxer =
            format.ffmpegRequiredMuxers.isEmpty ||
            format.ffmpegRequiredMuxers.contains(where: { introspection.muxers.contains($0) })

        guard hasMuxer else { return false }

        if format.ffmpegEncoderCandidates.isEmpty {
            return format.allowsFFmpegAutomaticCodec
        }

        let hasEncoder = format.ffmpegEncoderCandidates.contains { introspection.encoders.contains($0) }
        return hasEncoder || format.allowsFFmpegAutomaticCodec
    }

    nonisolated private static func inspectFFmpeg(at ffmpegPath: String) throws -> FFmpegIntrospection {
        if let cached = introspectionCacheQueue.sync(execute: { introspectionCache[ffmpegPath] }) {
            return cached
        }

        let encodersResult = runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-encoders"])
        let muxersResult = runCommandSync(path: ffmpegPath, arguments: ["-hide_banner", "-muxers"])

        guard encodersResult.terminationStatus == 0 else {
            throw ImageConversionError.ffmpegFailed(encodersResult.terminationStatus, encodersResult.output)
        }

        guard muxersResult.terminationStatus == 0 else {
            throw ImageConversionError.ffmpegFailed(muxersResult.terminationStatus, muxersResult.output)
        }

        let encoders = parseFFmpegEncoders(from: encodersResult.output)
        let muxerDescriptors = parseFFmpegMuxerDescriptors(from: muxersResult.output)
        let muxers = Set(muxerDescriptors.map(\.name))
        let muxerExtensions = parseFFmpegImageMuxerExtensions(
            ffmpegPath: ffmpegPath,
            muxerDescriptors: muxerDescriptors
        )

        let introspection = FFmpegIntrospection(
            encoders: encoders,
            muxers: muxers,
            muxerExtensions: muxerExtensions
        )

        introspectionCacheQueue.sync {
            introspectionCache[ffmpegPath] = introspection
        }

        return introspection
    }

    nonisolated private static func parseFFmpegEncoders(from output: String) -> Set<String> {
        var encoders = Set<String>()

        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }
            let flags = String(parts[0])
            guard flags.count >= 6, flags.first == "V" else { continue }

            encoders.insert(String(parts[1]))
        }

        return encoders
    }

    nonisolated private static func parseFFmpegMuxerDescriptors(from output: String) -> [FFmpegMuxerDescriptor] {
        var descriptors: [FFmpegMuxerDescriptor] = []

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(maxSplits: 2, whereSeparator: { $0.isWhitespace })
            guard parts.count >= 2 else { continue }

            let flags = String(parts[0])
            guard flags.contains("E") else { continue }

            let nameField = String(parts[1])
            let description = parts.count == 3 ? String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines) : ""

            let names = nameField
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            for name in names {
                descriptors.append(FFmpegMuxerDescriptor(name: name, description: description))
            }
        }

        return descriptors
    }

    nonisolated private static func parseFFmpegImageMuxerExtensions(
        ffmpegPath: String,
        muxerDescriptors: [FFmpegMuxerDescriptor]
    ) -> [String: [String]] {
        var map: [String: [String]] = [:]
        var seenMuxers = Set<String>()

        for descriptor in muxerDescriptors {
            guard seenMuxers.insert(descriptor.name).inserted else { continue }
            guard isLikelyImageMuxer(descriptor) else { continue }

            let helpResult = runCommandSync(
                path: ffmpegPath,
                arguments: ["-hide_banner", "-h", "muxer=\(descriptor.name)"]
            )
            guard helpResult.terminationStatus == 0 else { continue }

            var extensions = parseFFmpegMuxerExtensions(from: helpResult.output)
            if extensions.isEmpty, ImageFormatOption.isLikelyImageFileExtension(descriptor.name) {
                extensions = [descriptor.name]
            }

            guard !extensions.isEmpty else { continue }
            map[descriptor.name] = extensions
        }

        return map
    }

    nonisolated private static func parseFFmpegMuxerExtensions(from output: String) -> [String] {
        var collecting = false
        var buffer = ""

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if !collecting {
                guard let range = trimmed.range(of: "Common extensions:", options: [.caseInsensitive]) else { continue }
                collecting = true
                buffer += String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else {
                buffer += " " + trimmed
            }

            if buffer.contains(".") {
                break
            }
        }

        guard !buffer.isEmpty else { return [] }
        if let periodIndex = buffer.firstIndex(of: ".") {
            buffer = String(buffer[..<periodIndex])
        }

        let allowed = CharacterSet.alphanumerics
        var seen = Set<String>()
        var result: [String] = []

        for token in buffer.split(separator: ",") {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let cleanedScalars = trimmed.unicodeScalars.filter { allowed.contains($0) }
            let normalized = String(String.UnicodeScalarView(cleanedScalars)).lowercased()
            guard !normalized.isEmpty, normalized.count <= 16 else { continue }
            guard seen.insert(normalized).inserted else { continue }
            result.append(normalized)
        }

        return result
    }

    nonisolated private static func isLikelyImageMuxer(_ descriptor: FFmpegMuxerDescriptor) -> Bool {
        let name = descriptor.name.lowercased()
        let description = descriptor.description.lowercased()

        let explicitNames: Set<String> = [
            "image2",
            "gif",
            "webp",
            "avif",
            "heif",
            "apng",
            "ico",
            "jpegxl",
            "jxl"
        ]
        if explicitNames.contains(name) {
            return true
        }

        let keywords = [
            "image",
            "animation",
            "gif",
            "webp",
            "avif",
            "heif",
            "heic",
            "jpeg",
            "jpg",
            "png",
            "tiff",
            "bmp",
            "ico",
            "jxl",
            "jpegxl"
        ]

        return keywords.contains(where: { description.contains($0) })
    }

    nonisolated private static func findFFmpegPath() -> String? {
        let now = DispatchTime.now().uptimeNanoseconds
        let cacheSnapshot = ffmpegPathCacheQueue.sync {
            (ffmpegPathCache, ffmpegPathLookupTime)
        }

        if let cached = cacheSnapshot.0 {
            if let path = cached, FileManager.default.isExecutableFile(atPath: path) {
                return path
            }

            let nilCacheAge = now >= cacheSnapshot.1 ? now - cacheSnapshot.1 : 0
            if cached == nil && nilCacheAge < ffmpegPathNilCacheTTL {
                return nil
            }
        }

        let resolved = resolveFFmpegPath()
        ffmpegPathCacheQueue.sync {
            ffmpegPathCache = resolved
            ffmpegPathLookupTime = now
        }
        return resolved
    }

    nonisolated private static func resolveFFmpegPath() -> String? {
        var candidates: [String] = []

        if let bundled = Bundle.main.path(forResource: "ffmpeg", ofType: nil) {
            candidates.append(bundled)
        }
        if let resourcePath = Bundle.main.resourceURL?.path {
            candidates.append("\(resourcePath)/ffmpeg")
            candidates.append("\(resourcePath)/bin/ffmpeg")
        }
        if let executableDir = Bundle.main.executableURL?.deletingLastPathComponent().path {
            candidates.append("\(executableDir)/ffmpeg")
            candidates.append("\(executableDir)/bin/ffmpeg")
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ])
        if let fixed = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return fixed
        }

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for directory in path.split(separator: ":") {
                let candidate = "\(directory)/ffmpeg"
                if FileManager.default.isExecutableFile(atPath: candidate) {
                    return candidate
                }
            }
        }

        return nil
    }

    private final class ProcessCancellationController: @unchecked Sendable {
        private let queue = DispatchQueue(label: "myconverter.image.runcommand.process")
        nonisolated(unsafe) private var process: Process?

        nonisolated init() {}

        nonisolated func setProcess(_ process: Process) {
            queue.sync {
                self.process = process
            }
        }

        nonisolated func clearProcess() {
            queue.sync {
                process = nil
            }
        }

        nonisolated func terminateIfNeeded() {
            queue.sync {
                guard let process, process.isRunning else { return }
                process.terminate()
            }
        }
    }

    nonisolated private static func runCommand(
        path: String,
        arguments: [String]
    ) async throws -> (terminationStatus: Int32, output: String) {
        let cancellationController = ProcessCancellationController()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(Int32, String), Error>) in
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                cancellationController.setProcess(process)

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = outputPipe
                let outputHandle = outputPipe.fileHandleForReading

                process.terminationHandler = { proc in
                    outputHandle.readabilityHandler = nil
                    let outputData = outputHandle.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    cancellationController.clearProcess()
                    continuation.resume(returning: (proc.terminationStatus, output))
                }

                do {
                    try process.run()
                } catch {
                    outputHandle.readabilityHandler = nil
                    cancellationController.clearProcess()
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            cancellationController.terminateIfNeeded()
        }
    }

    nonisolated private static func runCommandSync(
        path: String,
        arguments: [String]
    ) -> (terminationStatus: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } catch {
            return (-1, error.localizedDescription)
        }
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
