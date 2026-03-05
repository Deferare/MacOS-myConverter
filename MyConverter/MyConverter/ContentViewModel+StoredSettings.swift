import Foundation

extension ContentViewModel {
    func withSettingsApplicationFlag(
        _ keyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        operation: () -> Void
    ) {
        self[keyPath: keyPath] = true
        defer { self[keyPath: keyPath] = false }
        operation()
    }

    func applyStoredFormatSelection<Format>(
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String
    ) {
        guard let normalizedStoredID = normalizeStoredID(storedFormatID),
              let matchingFormat = options.first(where: { formatNormalizedID($0) == normalizedStoredID }) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = matchingFormat
    }

    func applyStoredSourceSettings<Format>(
        applyingFlagKeyPath: ReferenceWritableKeyPath<ContentViewModel, Bool>,
        storedFormatID: String,
        normalizeStoredID: (String) -> String?,
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        applyAdditionalSettings: () -> Void,
        postApply: () -> Void
    ) {
        withSettingsApplicationFlag(applyingFlagKeyPath) {
            applyStoredFormatSelection(
                storedFormatID: storedFormatID,
                normalizeStoredID: normalizeStoredID,
                options: options,
                selectedFormatKeyPath: selectedFormatKeyPath,
                formatNormalizedID: formatNormalizedID
            )
            applyAdditionalSettings()
        }
        postApply()
    }

    func applyStoredSettings(_ settings: VideoConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: VideoFormatOption.legacyNormalizedID(from:),
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedVideoEncoder = settings.videoEncoder
                selectedResolution = settings.resolution
                selectedFrameRate = settings.frameRate
                selectedGIFPlaybackSpeed = settings.gifPlaybackSpeed
                selectedVideoBitRate = settings.videoBitRate
                customVideoBitRate = settings.customVideoBitRate
                selectedAudioEncoder = settings.audioEncoder
                selectedAudioMode = settings.audioMode
                selectedSampleRate = settings.sampleRate
                selectedAudioBitRate = settings.audioBitRate
            },
            postApply: {
                ensureSelectedVideoOutputFormatIsAvailable()
                refreshVideoCodecOptions()
            }
        )
    }

    func applyStoredImageSettings(_ settings: ImageConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredImageSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedImageResolution = settings.resolution
                selectedImageQuality = settings.quality
                selectedPNGCompressionLevel = settings.pngCompressionLevel
                preserveImageAnimation = settings.preserveAnimation
            },
            postApply: {
                ensureSelectedImageOutputFormatIsAvailable()
            }
        )
    }

    func applyStoredAudioSettings(_ settings: AudioConversionSettings) {
        applyStoredSourceSettings(
            applyingFlagKeyPath: \.isApplyingStoredAudioSettings,
            storedFormatID: settings.outputFormatID,
            normalizeStoredID: { $0.lowercased() },
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            applyAdditionalSettings: {
                selectedAudioOutputEncoder = settings.audioEncoder
                selectedAudioOutputMode = settings.audioMode
                selectedAudioOutputSampleRate = settings.sampleRate
                selectedAudioOutputBitRate = settings.audioBitRate
            },
            postApply: {
                ensureSelectedAudioOutputFormatIsAvailable()
                refreshAudioCodecOptions()
            }
        )
    }

    func ensureSelectedFormatIsAvailable<Format>(
        options: [Format],
        selectedFormatKeyPath: ReferenceWritableKeyPath<ContentViewModel, Format>,
        formatNormalizedID: (Format) -> String,
        preferredSelection: ([Format]) -> Format?
    ) {
        guard !options.isEmpty else { return }
        let selectedFormat = self[keyPath: selectedFormatKeyPath]
        guard !options.contains(where: { formatNormalizedID($0) == formatNormalizedID(selectedFormat) }),
              let preferredFormat = preferredSelection(options) else {
            return
        }
        self[keyPath: selectedFormatKeyPath] = preferredFormat
    }

    func ensureSelectedImageOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: imageOutputFormatOptions,
            selectedFormatKeyPath: \.selectedImageOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: { $0.first }
        )
    }

    func ensureSelectedAudioOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: audioOutputFormatOptions,
            selectedFormatKeyPath: \.selectedAudioOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: AudioFormatOption.defaultSelection(from:)
        )
    }

    func ensureSelectedVideoOutputFormatIsAvailable() {
        ensureSelectedFormatIsAvailable(
            options: outputFormatOptions,
            selectedFormatKeyPath: \.selectedOutputFormat,
            formatNormalizedID: { $0.normalizedID },
            preferredSelection: VideoFormatOption.defaultSelection(from:)
        )
    }
}
