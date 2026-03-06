import UniformTypeIdentifiers

extension ContentViewModelSupport {
    nonisolated static func inferredUTType(for url: URL) -> UTType? {
        let fileExtension = url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileExtension.isEmpty else { return nil }
        return FormatOptionUtilities.cachedUTType(forFilenameExtension: fileExtension)
    }

    nonisolated static func isVideoInputURL(_ url: URL) -> Bool {
        if let type = inferredUTType(for: url),
           type.conforms(to: .movie) || type.conforms(to: .video) {
            return true
        }
        return VideoFormatOption.isLikelyVideoFileExtension(url.pathExtension)
    }

    nonisolated static func isImageInputURL(_ url: URL) -> Bool {
        if let type = inferredUTType(for: url),
           type.conforms(to: .image) {
            return true
        }
        return ImageFormatOption.isLikelyImageFileExtension(url.pathExtension)
    }

    nonisolated static func isAudioInputURL(_ url: URL) -> Bool {
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
}
