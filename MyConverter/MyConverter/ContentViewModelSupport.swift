import Foundation
import UniformTypeIdentifiers

enum ContentViewModelSupport {
    static func defaultVideoFormat() -> VideoFormatOption {
        if let preferred = VideoFormatOption.defaultSelection(from: VideoConversionEngine.defaultOutputFormats()) {
            return preferred
        }
        return VideoFormatOption.fromFFmpegExtension("mp4", muxer: "mp4")
    }

    static func defaultAudioFormat() -> AudioFormatOption {
        if let preferred = AudioFormatOption.defaultSelection(from: VideoConversionEngine.defaultAudioOutputFormats()) {
            return preferred
        }
        return AudioFormatOption.fromFFmpegExtension("m4a", muxer: "ipod")
    }

    static func sourceIdentifier(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    static func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        var unique: [URL] = []

        for url in urls {
            // Preserve the original URL object to keep any attached security scope.
            let key = sourceIdentifier(for: url)
            if seen.insert(key).inserted {
                unique.append(url)
            }
        }

        return unique
    }

    static func inferredUTType(for url: URL) -> UTType? {
        let fileExtension = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileExtension.isEmpty else { return nil }
        return UTType(filenameExtension: fileExtension)
    }

    static func isVideoInputURL(_ url: URL) -> Bool {
        if let type = inferredUTType(for: url),
           type.conforms(to: .movie) || type.conforms(to: .video) {
            return true
        }
        return VideoFormatOption.isLikelyVideoFileExtension(url.pathExtension)
    }

    static func isImageInputURL(_ url: URL) -> Bool {
        if let type = inferredUTType(for: url),
           type.conforms(to: .image) {
            return true
        }
        return ImageFormatOption.isLikelyImageFileExtension(url.pathExtension)
    }

    static func isAudioInputURL(_ url: URL) -> Bool {
        if let type = inferredUTType(for: url),
           type.conforms(to: .audio) ||
            type.conforms(to: .movie) ||
            type.conforms(to: .video) ||
            type.conforms(to: .audiovisualContent) {
            return true
        }
        return AudioFormatOption.isLikelyAudioFileExtension(url.pathExtension) ||
            VideoFormatOption.isLikelyVideoFileExtension(url.pathExtension)
    }

    static func reorderedURLsByMoving(_ draggedURL: URL, to targetURL: URL, in urls: [URL]) -> [URL]? {
        let draggedID = sourceIdentifier(for: draggedURL)
        let targetID = sourceIdentifier(for: targetURL)
        guard draggedID != targetID else { return nil }

        var reordered = urls
        guard
            let sourceIndex = reordered.firstIndex(where: { sourceIdentifier(for: $0) == draggedID }),
            let destinationIndex = reordered.firstIndex(where: { sourceIdentifier(for: $0) == targetID }),
            sourceIndex != destinationIndex
        else {
            return nil
        }

        let movedURL = reordered.remove(at: sourceIndex)
        reordered.insert(movedURL, at: destinationIndex)
        return reordered
    }

    static func labeledCapabilityMessage(_ message: String, for sourceURL: URL, totalCount: Int) -> String {
        guard totalCount > 1 else { return message }
        return "\(sourceURL.lastPathComponent): \(message)"
    }

    static func joinedCapabilityMessages(_ messages: [String]) -> String? {
        var seen = Set<String>()
        var uniqueMessages: [String] = []

        for message in messages {
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                uniqueMessages.append(trimmed)
            }
        }

        guard !uniqueMessages.isEmpty else { return nil }
        return uniqueMessages.joined(separator: "\n")
    }

    static func intersectFormats<Format>(
        _ lhs: [Format],
        _ rhs: [Format],
        normalizedID: (Format) -> String
    ) -> [Format] {
        let rhsIDs = Set(rhs.map(normalizedID))
        return lhs.filter { rhsIDs.contains(normalizedID($0)) }
    }

    static func clampedProgress(_ rawProgress: Double) -> Double {
        min(max(rawProgress, 0), 1)
    }

    static func preferredVideoEncoder(from options: [VideoEncoderOption]) -> VideoEncoderOption? {
        guard !options.isEmpty else { return nil }
        if options.contains(.h264GPU) { return .h264GPU }
        if options.contains(.h264CPU) { return .h264CPU }
        if options.contains(.auto) { return .auto }
        return options.first
    }

    static func preferredAudioEncoder(from options: [AudioEncoderOption]) -> AudioEncoderOption? {
        guard !options.isEmpty else { return nil }
        if options.contains(.aac) { return .aac }
        if options.contains(.auto) { return .auto }
        return options.first
    }

    static func preferredAudioOutputEncoder(
        for format: AudioFormatOption,
        from options: [AudioEncoderOption]
    ) -> AudioEncoderOption? {
        guard !options.isEmpty else { return nil }

        switch format.fileExtension.lowercased() {
        case "m4a", "aac":
            if options.contains(.aac) { return .aac }
        case "mp3":
            if options.contains(.mp3) { return .mp3 }
        case "wav", "aiff", "aif", "caf":
            if options.contains(.pcm) { return .pcm }
        case "flac":
            if options.contains(.flac) { return .flac }
        case "opus", "ogg", "oga":
            if options.contains(.opus) { return .opus }
        default:
            break
        }

        if options.contains(.aac) { return .aac }
        if options.contains(.mp3) { return .mp3 }
        if options.contains(.auto) { return .auto }
        return options.first
    }
}
