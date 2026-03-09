import Foundation

extension ContentViewModel {
    enum WarmedDefaultCapability: Sendable {
        case video([VideoFormatOption])
        case image([ImageFormatOption])
        case audio([AudioFormatOption])

        var kind: MediaKind {
            switch self {
            case .video:
                return .video
            case .image:
                return .image
            case .audio:
                return .audio
            }
        }
    }

    struct CapabilityBootstrapDescriptor {
        let warmDefaultCapabilities: @Sendable () -> WarmedDefaultCapability
        let applyPlaceholder: (ContentViewModel) -> Void
        let applyWarmedIfIdle: (ContentViewModel, WarmedDefaultCapability) -> Void
    }

    func makeCapabilityBootstrapDescriptor<Format>(
        for kind: MediaKind,
        warmDefaultCapabilities: @escaping @Sendable () -> WarmedDefaultCapability,
        placeholderFormats: @escaping () -> [Format],
        formatDescriptor: @escaping (ContentViewModel) -> OutputFormatDescriptor<Format>,
        warmedFormats: @escaping (WarmedDefaultCapability) -> [Format]?,
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
                guard let formats = warmedFormats(warmed) else { return }
                viewModel.applyWarmedOutputFormatsIfIdle(
                    formats,
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
            warmDefaultCapabilities: { .video(VideoConversionEngine.defaultOutputFormats()) },
            placeholderFormats: ContentViewModelSupport.placeholderVideoFormats,
            formatDescriptor: { $0.videoOutputFormatDescriptor() },
            warmedFormats: {
                guard case let .video(formats) = $0 else { return nil }
                return formats
            },
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
            warmDefaultCapabilities: { .image(ImageConversionEngine.defaultOutputFormats()) },
            placeholderFormats: ContentViewModelSupport.placeholderImageFormats,
            formatDescriptor: { $0.imageOutputFormatDescriptor() },
            warmedFormats: {
                guard case let .image(formats) = $0 else { return nil }
                return formats
            }
        )
    }

    func audioCapabilityBootstrapDescriptor() -> CapabilityBootstrapDescriptor {
        makeCapabilityBootstrapDescriptor(
            for: .audio,
            warmDefaultCapabilities: { .audio(VideoConversionEngine.defaultAudioOutputFormats()) },
            placeholderFormats: ContentViewModelSupport.placeholderAudioFormats,
            formatDescriptor: { $0.audioOutputFormatDescriptor() },
            warmedFormats: {
                guard case let .audio(formats) = $0 else { return nil }
                return formats
            },
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
        mediaBehaviorDescriptor(for: kind).capabilityBootstrap
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
        let descriptor = mediaStateDescriptor(for: kind)
        guard mediaStateValue(using: descriptor, \.sourceURL) == nil,
              !mediaStateValue(using: descriptor, \.isAnalyzing) else {
            return
        }

        applyAvailableOutputFormats(warmedFormats, using: formatDescriptor, postApply: postApply)
    }

    func applyPlaceholderCapabilities(for kind: MediaKind) {
        capabilityBootstrapDescriptor(for: kind).applyPlaceholder(self)
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
                self.capabilityBootstrapDescriptor(for: $0).warmDefaultCapabilities
            }

            let warmed = await Task.detached(priority: .userInitiated) {
                await withTaskGroup(
                    of: WarmedDefaultCapability.self,
                    returning: [WarmedDefaultCapability].self
                ) { group in
                    for warmCapabilities in warmDefaultCapabilities {
                        group.addTask {
                            warmCapabilities()
                        }
                    }

                    var warmed: [WarmedDefaultCapability] = []
                    for await capability in group {
                        warmed.append(capability)
                    }

                    return warmed
                }
            }.value

            guard !Task.isCancelled else { return }
            applyWarmedDefaultCapabilitiesIfNeeded(warmed)
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

    func applyWarmedDefaultCapabilitiesIfNeeded(_ warmedCapabilities: [WarmedDefaultCapability]) {
        warmedCapabilities.forEach {
            capabilityBootstrapDescriptor(for: $0.kind).applyWarmedIfIdle(self, $0)
        }
    }
}
