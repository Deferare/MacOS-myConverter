import Foundation

extension ContentViewModel {
    struct WarmedDefaultCapabilities: Sendable {
        let videoFormats: [VideoFormatOption]
        let imageFormats: [ImageFormatOption]
        let audioFormats: [AudioFormatOption]
    }

    enum CapabilityWarmupResult: Sendable {
        case videoFormats([VideoFormatOption])
        case imageFormats([ImageFormatOption])
        case audioFormats([AudioFormatOption])
        case warmed
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
                var warmed = WarmedDefaultCapabilities(
                    videoFormats: [],
                    imageFormats: [],
                    audioFormats: []
                )

                await withTaskGroup(of: CapabilityWarmupResult.self) { group in
                    group.addTask {
                        .videoFormats(VideoConversionEngine.defaultOutputFormats())
                    }
                    group.addTask {
                        .imageFormats(ImageConversionEngine.defaultOutputFormats())
                    }
                    group.addTask {
                        .audioFormats(VideoConversionEngine.defaultAudioOutputFormats())
                    }
                    group.addTask {
                        _ = VideoConversionEngine.availableVideoEncoders(for: selectedVideoFormat)
                        return .warmed
                    }
                    if selectedVideoFormat.supportsAudioTrack {
                        group.addTask {
                            _ = VideoConversionEngine.availableAudioEncoders(for: selectedVideoFormat)
                            return .warmed
                        }
                    }
                    group.addTask {
                        _ = VideoConversionEngine.availableAudioEncoders(for: selectedAudioFormat)
                        return .warmed
                    }

                    for await result in group {
                        switch result {
                        case .videoFormats(let videoFormats):
                            warmed = WarmedDefaultCapabilities(
                                videoFormats: videoFormats,
                                imageFormats: warmed.imageFormats,
                                audioFormats: warmed.audioFormats
                            )
                        case .imageFormats(let imageFormats):
                            warmed = WarmedDefaultCapabilities(
                                videoFormats: warmed.videoFormats,
                                imageFormats: imageFormats,
                                audioFormats: warmed.audioFormats
                            )
                        case .audioFormats(let audioFormats):
                            warmed = WarmedDefaultCapabilities(
                                videoFormats: warmed.videoFormats,
                                imageFormats: warmed.imageFormats,
                                audioFormats: audioFormats
                            )
                        case .warmed:
                            break
                        }
                    }
                }

                return warmed
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
