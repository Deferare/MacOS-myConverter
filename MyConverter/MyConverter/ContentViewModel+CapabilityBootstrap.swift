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
        [.video, .image, .audio].forEach { mediaStateDescriptor(for: $0).applyPlaceholderCapabilities(self) }
    }

    func applyAvailableOutputFormats<Format>(
        _ formats: [Format],
        using descriptor: OutputFormatDescriptor<Format>,
        postApply: () -> Void = {}
    ) {
        self[keyPath: descriptor.availableFormats] = formats
        ensureSelectedOutputFormatIsAvailable(using: descriptor)
        postApply()
    }

    func applyWarmedOutputFormatsIfIdle<Format>(
        _ warmedFormats: [Format],
        for kind: MediaKind,
        formatDescriptor: OutputFormatDescriptor<Format>,
        postApply: () -> Void = {}
    ) {
        let mediaDescriptor = mediaStateDescriptor(for: kind)
        guard self[keyPath: mediaDescriptor.sourceURL] == nil,
              !self[keyPath: mediaDescriptor.isAnalyzing] else {
            return
        }

        applyAvailableOutputFormats(warmedFormats, using: formatDescriptor, postApply: postApply)
    }

    func applyPlaceholderVideoCapabilities() {
        applyAvailableOutputFormats(
            ContentViewModelSupport.placeholderVideoFormats(),
            using: videoOutputFormatDescriptor()
        )
        availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(for: selectedOutputFormat)
        availableAudioEncoders = ContentViewModelSupport.placeholderVideoAudioEncoders(for: selectedOutputFormat)
        normalizeVideoOptionDependencies()
    }

    func applyPlaceholderImageCapabilities() {
        applyAvailableOutputFormats(
            ContentViewModelSupport.placeholderImageFormats(),
            using: imageOutputFormatDescriptor()
        )
    }

    func applyPlaceholderAudioCapabilities() {
        applyAvailableOutputFormats(
            ContentViewModelSupport.placeholderAudioFormats(),
            using: audioOutputFormatDescriptor()
        )
        availableAudioOutputEncoders = ContentViewModelSupport.placeholderAudioOutputEncoders(
            for: selectedAudioOutputFormat
        )
        normalizeAudioOptionDependencies()
    }

    func scheduleCapabilityBootstrap() {
        cancelTask(&taskState.capabilityBootstrapTask)

        let selectedVideoFormat = selectedOutputFormat
        let selectedAudioFormat = selectedAudioOutputFormat
        taskState.capabilityBootstrapTask = Task { [weak self] in
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
            taskState.capabilityBootstrapTask = nil
        }
    }

    func applyWarmedDefaultCapabilitiesIfNeeded(_ warmed: WarmedDefaultCapabilities) {
        applyWarmedOutputFormatsIfIdle(
            warmed.videoFormats,
            for: .video,
            formatDescriptor: videoOutputFormatDescriptor(),
            postApply: refreshVideoCodecOptions
        )
        applyWarmedOutputFormatsIfIdle(
            warmed.imageFormats,
            for: .image,
            formatDescriptor: imageOutputFormatDescriptor()
        )
        applyWarmedOutputFormatsIfIdle(
            warmed.audioFormats,
            for: .audio,
            formatDescriptor: audioOutputFormatDescriptor(),
            postApply: refreshAudioCodecOptions
        )
    }
}
