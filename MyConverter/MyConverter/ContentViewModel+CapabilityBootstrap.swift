import Foundation

extension ContentViewModel {
    struct WarmedDefaultCapabilities: Sendable {
        var videoFormats: [VideoFormatOption] = []
        var imageFormats: [ImageFormatOption] = []
        var audioFormats: [AudioFormatOption] = []
    }

    enum CapabilityWarmupResult: Sendable {
        case videoFormats([VideoFormatOption])
        case imageFormats([ImageFormatOption])
        case audioFormats([AudioFormatOption])
        case warmed
    }

    struct CapabilityBootstrapDescriptor {
        let applyPlaceholder: (ContentViewModel) -> Void
        let applyWarmedIfIdle: (ContentViewModel, WarmedDefaultCapabilities) -> Void
    }

    func capabilityBootstrapDescriptor(for kind: MediaKind) -> CapabilityBootstrapDescriptor {
        switch kind {
        case .video:
            return CapabilityBootstrapDescriptor(
                applyPlaceholder: { viewModel in
                    viewModel.applyAvailableOutputFormats(
                        ContentViewModelSupport.placeholderVideoFormats(),
                        using: viewModel.videoOutputFormatDescriptor()
                    )
                    viewModel.availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(
                        for: viewModel.selectedOutputFormat
                    )
                    viewModel.availableAudioEncoders = ContentViewModelSupport.placeholderVideoAudioEncoders(
                        for: viewModel.selectedOutputFormat
                    )
                    viewModel.normalizeVideoOptionDependencies()
                },
                applyWarmedIfIdle: { viewModel, warmed in
                    viewModel.applyWarmedOutputFormatsIfIdle(
                        warmed.videoFormats,
                        for: .video,
                        formatDescriptor: viewModel.videoOutputFormatDescriptor(),
                        postApply: viewModel.refreshVideoCodecOptions
                    )
                }
            )
        case .image:
            return CapabilityBootstrapDescriptor(
                applyPlaceholder: { viewModel in
                    viewModel.applyAvailableOutputFormats(
                        ContentViewModelSupport.placeholderImageFormats(),
                        using: viewModel.imageOutputFormatDescriptor()
                    )
                },
                applyWarmedIfIdle: { viewModel, warmed in
                    viewModel.applyWarmedOutputFormatsIfIdle(
                        warmed.imageFormats,
                        for: .image,
                        formatDescriptor: viewModel.imageOutputFormatDescriptor()
                    )
                }
            )
        case .audio:
            return CapabilityBootstrapDescriptor(
                applyPlaceholder: { viewModel in
                    viewModel.applyAvailableOutputFormats(
                        ContentViewModelSupport.placeholderAudioFormats(),
                        using: viewModel.audioOutputFormatDescriptor()
                    )
                    viewModel.availableAudioOutputEncoders =
                        ContentViewModelSupport.placeholderAudioOutputEncoders(
                            for: viewModel.selectedAudioOutputFormat
                        )
                    viewModel.normalizeAudioOptionDependencies()
                },
                applyWarmedIfIdle: { viewModel, warmed in
                    viewModel.applyWarmedOutputFormatsIfIdle(
                        warmed.audioFormats,
                        for: .audio,
                        formatDescriptor: viewModel.audioOutputFormatDescriptor(),
                        postApply: viewModel.refreshAudioCodecOptions
                    )
                }
            )
        }
    }

    func applyPlaceholderCapabilityState() {
        MediaKind.allCases.forEach { applyPlaceholderCapabilities(for: $0) }
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

    func applyPlaceholderCapabilities(for kind: MediaKind) {
        capabilityBootstrapDescriptor(for: kind).applyPlaceholder(self)
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
                        Self.applyCapabilityWarmupResult(result, to: &warmed)
                    }
                }

                return warmed
            }.value

            guard !Task.isCancelled, let self else { return }
            applyWarmedDefaultCapabilitiesIfNeeded(warmed)
            taskState.capabilityBootstrapTask = nil
        }
    }

    nonisolated static func applyCapabilityWarmupResult(
        _ result: CapabilityWarmupResult,
        to warmed: inout WarmedDefaultCapabilities
    ) {
        switch result {
        case .videoFormats(let videoFormats):
            warmed.videoFormats = videoFormats
        case .imageFormats(let imageFormats):
            warmed.imageFormats = imageFormats
        case .audioFormats(let audioFormats):
            warmed.audioFormats = audioFormats
        case .warmed:
            break
        }
    }

    func applyWarmedDefaultCapabilitiesIfNeeded(_ warmed: WarmedDefaultCapabilities) {
        MediaKind.allCases.forEach {
            capabilityBootstrapDescriptor(for: $0).applyWarmedIfIdle(self, warmed)
        }
    }
}
