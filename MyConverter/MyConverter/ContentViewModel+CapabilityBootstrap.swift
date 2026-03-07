import Foundation

extension ContentViewModel {
    struct WarmedDefaultCapabilities: Sendable {
        var videoFormats: [VideoFormatOption] = []
        var imageFormats: [ImageFormatOption] = []
        var audioFormats: [AudioFormatOption] = []
    }

    struct CapabilityWarmupMutation: Sendable {
        let apply: @Sendable (inout WarmedDefaultCapabilities) -> Void
    }

    struct CapabilityBootstrapDescriptor {
        let warmDefaultCapabilities: @Sendable () -> CapabilityWarmupMutation
        let applyPlaceholder: (ContentViewModel) -> Void
        let applyWarmedIfIdle: (ContentViewModel, WarmedDefaultCapabilities) -> Void
    }

    func makeCapabilityBootstrapDescriptor<Format>(
        for kind: MediaKind,
        warmDefaultCapabilities: @escaping @Sendable () -> CapabilityWarmupMutation,
        placeholderFormats: @escaping () -> [Format],
        formatDescriptor: @escaping (ContentViewModel) -> OutputFormatDescriptor<Format>,
        warmedFormats: @escaping (WarmedDefaultCapabilities) -> [Format],
        applyAdditionalPlaceholderState: @escaping (ContentViewModel) -> Void = { _ in },
        postApplyWhenWarmed: @escaping (ContentViewModel) -> Void = { _ in }
    ) -> CapabilityBootstrapDescriptor {
        CapabilityBootstrapDescriptor(
            warmDefaultCapabilities: warmDefaultCapabilities,
            applyPlaceholder: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    placeholderFormats(),
                    using: formatDescriptor(viewModel)
                )
                applyAdditionalPlaceholderState(viewModel)
            },
            applyWarmedIfIdle: { viewModel, warmed in
                viewModel.applyWarmedOutputFormatsIfIdle(
                    warmedFormats(warmed),
                    for: kind,
                    formatDescriptor: formatDescriptor(viewModel),
                    postApply: {
                        postApplyWhenWarmed(viewModel)
                    }
                )
            }
        )
    }

    func videoCapabilityBootstrapDescriptor() -> CapabilityBootstrapDescriptor {
        makeCapabilityBootstrapDescriptor(
            for: .video,
            warmDefaultCapabilities: {
                let formats = VideoConversionEngine.defaultOutputFormats()
                return CapabilityWarmupMutation { $0.videoFormats = formats }
            },
            placeholderFormats: ContentViewModelSupport.placeholderVideoFormats,
            formatDescriptor: { $0.videoOutputFormatDescriptor() },
            warmedFormats: { $0.videoFormats },
            applyAdditionalPlaceholderState: { viewModel in
                viewModel.availableVideoEncoders = ContentViewModelSupport.placeholderVideoEncoders(
                    for: viewModel.selectedOutputFormat
                )
                viewModel.availableAudioEncoders = ContentViewModelSupport.placeholderVideoAudioEncoders(
                    for: viewModel.selectedOutputFormat
                )
                viewModel.normalizeVideoOptionDependencies()
            },
            postApplyWhenWarmed: { $0.refreshVideoCodecOptions() }
        )
    }

    func imageCapabilityBootstrapDescriptor() -> CapabilityBootstrapDescriptor {
        makeCapabilityBootstrapDescriptor(
            for: .image,
            warmDefaultCapabilities: {
                let formats = ImageConversionEngine.defaultOutputFormats()
                return CapabilityWarmupMutation { $0.imageFormats = formats }
            },
            placeholderFormats: ContentViewModelSupport.placeholderImageFormats,
            formatDescriptor: { $0.imageOutputFormatDescriptor() },
            warmedFormats: { $0.imageFormats }
        )
    }

    func audioCapabilityBootstrapDescriptor() -> CapabilityBootstrapDescriptor {
        makeCapabilityBootstrapDescriptor(
            for: .audio,
            warmDefaultCapabilities: {
                let formats = VideoConversionEngine.defaultAudioOutputFormats()
                return CapabilityWarmupMutation { $0.audioFormats = formats }
            },
            placeholderFormats: ContentViewModelSupport.placeholderAudioFormats,
            formatDescriptor: { $0.audioOutputFormatDescriptor() },
            warmedFormats: { $0.audioFormats },
            applyAdditionalPlaceholderState: { viewModel in
                viewModel.availableAudioOutputEncoders =
                    ContentViewModelSupport.placeholderAudioOutputEncoders(
                        for: viewModel.selectedAudioOutputFormat
                    )
                viewModel.normalizeAudioOptionDependencies()
            },
            postApplyWhenWarmed: { $0.refreshAudioCodecOptions() }
        )
    }

    func capabilityBootstrapDescriptor(for kind: MediaKind) -> CapabilityBootstrapDescriptor {
        mediaStateDescriptor(for: kind).capabilityBootstrap
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
        mediaStateDescriptor(for: kind).capabilityBootstrap.applyPlaceholder(self)
    }

    func scheduleCapabilityBootstrap(for kind: MediaKind) {
        scheduleCapabilityBootstrap(for: [kind])
    }

    func scheduleCapabilityBootstrap(for kinds: [MediaKind]) {
        let requestedKinds = uniqueMediaKinds(kinds)
        guard !requestedKinds.isEmpty else { return }

        cancelTask(&taskState.capabilityBootstrapTask)

        taskState.capabilityBootstrapTask = Task { [weak self] in
            guard let self else { return }
            let warmDefaultCapabilities = requestedKinds.map {
                self.mediaStateDescriptor(for: $0).capabilityBootstrap.warmDefaultCapabilities
            }

            let warmed = await Task.detached(priority: .userInitiated) {
                var warmed = WarmedDefaultCapabilities(
                    videoFormats: [],
                    imageFormats: [],
                    audioFormats: []
                )

                await withTaskGroup(of: CapabilityWarmupMutation.self) { group in
                    for warmCapabilities in warmDefaultCapabilities {
                        group.addTask {
                            warmCapabilities()
                        }
                    }

                    for await mutation in group {
                        mutation.apply(&warmed)
                    }
                }

                return warmed
            }.value

            guard !Task.isCancelled else { return }
            applyWarmedDefaultCapabilitiesIfNeeded(warmed, for: requestedKinds)
            taskState.capabilityBootstrapTask = nil
        }
    }

    func uniqueMediaKinds(_ kinds: [MediaKind]) -> [MediaKind] {
        var unique: [MediaKind] = []

        for kind in kinds where !unique.contains(kind) {
            unique.append(kind)
        }

        return unique
    }

    func applyWarmedDefaultCapabilitiesIfNeeded(
        _ warmed: WarmedDefaultCapabilities,
        for kinds: [MediaKind]
    ) {
        kinds.forEach {
            mediaStateDescriptor(for: $0).capabilityBootstrap.applyWarmedIfIdle(self, warmed)
        }
    }
}
