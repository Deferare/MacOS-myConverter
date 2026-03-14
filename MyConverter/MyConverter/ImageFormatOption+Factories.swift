import Foundation
import ImageIO
import UniformTypeIdentifiers

extension ImageFormatOption {
    nonisolated static func fromImageIOTypeIdentifier(_ identifier: String) -> ImageFormatOption {
        let normalizedIdentifier = identifier.lowercased()
        let profile = ImageFormatCatalog.byIdentifier[normalizedIdentifier]
        let utType = FormatOptionUtilities.cachedUTType(forIdentifier: identifier)

        let displayName =
            profile?.displayName ??
            utType?.localizedDescription ??
            FormatOptionUtilities.prettifiedIdentifier(identifier)

        let fileExtension =
            profile?.fileExtension ??
            utType?.preferredFilenameExtension ??
            FormatOptionUtilities.guessedFileExtension(from: identifier)

        return ImageFormatOption(
            id: normalizedIdentifier,
            displayName: displayName,
            fileExtension: fileExtension,
            imageIOUTTypeIdentifier: identifier,
            supportsCompressionQuality: profile?.supportsCompressionQuality ?? false,
            supportsAnimation: profile?.supportsAnimation ?? false,
            supportsPNGCompressionLevel: profile?.supportsPNGCompressionLevel ?? (normalizedIdentifier == "public.png"),
            ffmpegEncoderCandidates: profile?.ffmpegEncoderCandidates ?? [],
            ffmpegRequiredMuxers: profile?.ffmpegRequiredMuxers ?? [],
            preferredFFmpegMuxer: profile?.preferredFFmpegMuxer,
            allowsFFmpegAutomaticCodec: profile?.allowsFFmpegAutomaticCodec ?? false
        )
    }

    nonisolated static func fromFFmpegExtension(_ fileExtension: String, muxer: String) -> ImageFormatOption {
        let normalizedExtension = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()

        let extensionUTType = FormatOptionUtilities.cachedUTType(forFilenameExtension: normalizedExtension)
        let identifier = extensionUTType?.identifier.lowercased()
        let profile =
            identifier.flatMap { ImageFormatCatalog.byIdentifier[$0] } ??
            ImageFormatCatalog.byFileExtension[normalizedExtension]

        let resolvedUTType =
            profile?.imageIOUTTypeIdentifier.flatMap(FormatOptionUtilities.cachedUTType(forIdentifier:)) ??
            extensionUTType

        let resolvedIdentifier =
            profile?.id ??
            resolvedUTType?.identifier.lowercased() ??
            "ffmpeg.\(normalizedExtension)"

        let resolvedDisplayName =
            profile?.displayName ??
            resolvedUTType?.localizedDescription ??
            normalizedExtension.uppercased()

        let resolvedExtension =
            profile?.fileExtension ??
            resolvedUTType?.preferredFilenameExtension ??
            normalizedExtension

        let resolvedRequiredMuxers = FormatOptionUtilities.uniqueNonEmptyStrings(
            (profile?.ffmpegRequiredMuxers ?? []) + [normalizedMuxer]
        )

        return ImageFormatOption(
            id: resolvedIdentifier,
            displayName: resolvedDisplayName,
            fileExtension: resolvedExtension,
            imageIOUTTypeIdentifier: profile?.imageIOUTTypeIdentifier ?? resolvedUTType?.identifier,
            supportsCompressionQuality: profile?.supportsCompressionQuality ?? false,
            supportsAnimation: profile?.supportsAnimation ?? false,
            supportsPNGCompressionLevel: profile?.supportsPNGCompressionLevel ?? false,
            ffmpegEncoderCandidates: profile?.ffmpegEncoderCandidates ?? [],
            ffmpegRequiredMuxers: resolvedRequiredMuxers,
            preferredFFmpegMuxer: profile?.preferredFFmpegMuxer ?? normalizedMuxer,
            allowsFFmpegAutomaticCodec: profile?.allowsFFmpegAutomaticCodec ?? true
        )
    }

    nonisolated static func isLikelyImageFileExtension(_ fileExtension: String) -> Bool {
        let normalizedExtension = FormatOptionUtilities.normalizedFileExtension(fileExtension)
        guard !normalizedExtension.isEmpty else { return false }

        if let utType = FormatOptionUtilities.cachedUTType(forFilenameExtension: normalizedExtension),
           utType.conforms(to: .image) {
            return true
        }

        return ImageFormatCatalog.byFileExtension[normalizedExtension] != nil
    }

    nonisolated static let ffmpegKnownFormats: [ImageFormatOption] = {
        ImageFormatCatalog.ffmpegOnlyProfiles.map { profile in
            ImageFormatOption(
                id: profile.id,
                displayName: profile.displayName,
                fileExtension: profile.fileExtension,
                imageIOUTTypeIdentifier: profile.imageIOUTTypeIdentifier,
                supportsCompressionQuality: profile.supportsCompressionQuality,
                supportsAnimation: profile.supportsAnimation,
                supportsPNGCompressionLevel: profile.supportsPNGCompressionLevel,
                ffmpegEncoderCandidates: profile.ffmpegEncoderCandidates,
                ffmpegRequiredMuxers: profile.ffmpegRequiredMuxers,
                preferredFFmpegMuxer: profile.preferredFFmpegMuxer,
                allowsFFmpegAutomaticCodec: profile.allowsFFmpegAutomaticCodec
            )
        }
    }()
}
