import UniformTypeIdentifiers

extension FormatOptionUtilities {
    nonisolated static func resolveFFmpegFormatMetadata<Profile>(
        fileExtension: String,
        muxer: String,
        profile: Profile?,
        profileID: (Profile) -> String,
        profileDisplayName: (Profile) -> String,
        profileFileExtension: (Profile) -> String,
        profileRequiredMuxers: (Profile) -> [String],
        profilePreferredMuxer: (Profile) -> String?
    ) -> (
        id: String,
        displayName: String,
        fileExtension: String,
        requiredMuxers: [String],
        preferredMuxer: String
    ) {
        let normalizedExtension = normalizedFileExtension(fileExtension)
        let normalizedMuxer = muxer.lowercased()
        let extensionUTType = cachedUTType(forFilenameExtension: normalizedExtension)

        let resolvedID =
            profile.map(profileID) ??
            extensionUTType?.identifier.lowercased() ??
            "ffmpeg.\(normalizedExtension)"

        let resolvedDisplayName =
            profile.map(profileDisplayName) ??
            extensionUTType?.localizedDescription ??
            normalizedExtension.uppercased()

        let resolvedExtension =
            profile.map(profileFileExtension) ??
            extensionUTType?.preferredFilenameExtension ??
            normalizedExtension

        let resolvedMuxers = uniqueLowercasedTrimmedStrings(
            (profile.map(profileRequiredMuxers) ?? []) + [normalizedMuxer]
        )

        return (
            id: resolvedID,
            displayName: resolvedDisplayName,
            fileExtension: resolvedExtension,
            requiredMuxers: resolvedMuxers,
            preferredMuxer: profile.flatMap(profilePreferredMuxer) ?? normalizedMuxer
        )
    }
}
