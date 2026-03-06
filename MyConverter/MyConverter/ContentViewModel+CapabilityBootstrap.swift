import Foundation

extension ContentViewModel {
    struct WarmedDefaultCapabilities: Sendable {
        let videoFormats: [VideoFormatOption]
        let imageFormats: [ImageFormatOption]
        let audioFormats: [AudioFormatOption]
    }

    func applyPlaceholderCapabilityState() {
        applyPlaceholderVideoCapabilities()
        applyPlaceholderImageCapabilities()
        applyPlaceholderAudioCapabilities()
    }

    func applyPlaceholderVideoCapabilities() {
        availableOutputFormats = ContentViewModelSupport.placeholderVideoFormats()
        ensureSelectedVideoOutputFormatIsAvailable()
        availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(for: selectedOutputFormat)
        availableAudioEncoders = ContentViewModelSupport.placeholderVideoAudioEncoders(for: selectedOutputFormat)
        normalizeVideoOptionDependencies()
    }

    func applyPlaceholderImageCapabilities() {
        availableImageOutputFormats = ContentViewModelSupport.placeholderImageFormats()
        ensureSelectedImageOutputFormatIsAvailable()
    }

    func applyPlaceholderAudioCapabilities() {
        availableAudioOutputFormats = ContentViewModelSupport.placeholderAudioFormats()
        ensureSelectedAudioOutputFormatIsAvailable()
        availableAudioOutputEncoders = ContentViewModelSupport.placeholderAudioOutputEncoders(
            for: selectedAudioOutputFormat
        )
        normalizeAudioOptionDependencies()
    }

    func scheduleCapabilityBootstrap() {
        cancelTask(&capabilityBootstrapTask)

        let selectedVideoFormat = selectedOutputFormat
        let selectedAudioFormat = selectedAudioOutputFormat
        capabilityBootstrapTask = Task { [weak self] in
            let warmed = await Task.detached(priority: .userInitiated) {
                let videoFormats = VideoConversionEngine.defaultOutputFormats()
                let imageFormats = ImageConversionEngine.defaultOutputFormats()
                let audioFormats = VideoConversionEngine.defaultAudioOutputFormats()

                _ = VideoConversionEngine.availableVideoEncoders(for: selectedVideoFormat)
                if selectedVideoFormat.supportsAudioTrack {
                    _ = VideoConversionEngine.availableAudioEncoders(for: selectedVideoFormat)
                }
                _ = VideoConversionEngine.availableAudioEncoders(for: selectedAudioFormat)

                return WarmedDefaultCapabilities(
                    videoFormats: videoFormats,
                    imageFormats: imageFormats,
                    audioFormats: audioFormats
                )
            }.value

            guard !Task.isCancelled, let self else { return }
            applyWarmedDefaultCapabilitiesIfNeeded(warmed)
            capabilityBootstrapTask = nil
        }
    }

    func applyWarmedDefaultCapabilitiesIfNeeded(_ warmed: WarmedDefaultCapabilities) {
        if sourceURL == nil && !isAnalyzingSource {
            availableOutputFormats = warmed.videoFormats
            ensureSelectedVideoOutputFormatIsAvailable()
            refreshVideoCodecOptions()
        }

        if imageSourceURL == nil && !isAnalyzingImageSource {
            availableImageOutputFormats = warmed.imageFormats
            ensureSelectedImageOutputFormatIsAvailable()
        }

        if audioSourceURL == nil && !isAnalyzingAudioSource {
            availableAudioOutputFormats = warmed.audioFormats
            ensureSelectedAudioOutputFormatIsAvailable()
            refreshAudioCodecOptions()
        }
    }
}
