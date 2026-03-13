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

        var videoFormats: [VideoFormatOption]? {
            guard case let .video(formats) = self else { return nil }
            return formats
        }

        var imageFormats: [ImageFormatOption]? {
            guard case let .image(formats) = self else { return nil }
            return formats
        }

        var audioFormats: [AudioFormatOption]? {
            guard case let .audio(formats) = self else { return nil }
            return formats
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
            warmedFormats: { $0.videoFormats },
            applyAdditionalPlaceholderState: { $0.applyPlaceholderVideoCodecOptions() },
            postApplyWhenWarmed: { $0.refreshVideoCodecOptions() }
        )
    }

    func imageCapabilityBootstrapDescriptor() -> CapabilityBootstrapDescriptor {
        makeCapabilityBootstrapDescriptor(
            for: .image,
            warmDefaultCapabilities: { .image(ImageConversionEngine.defaultOutputFormats()) },
            placeholderFormats: ContentViewModelSupport.placeholderImageFormats,
            formatDescriptor: { $0.imageOutputFormatDescriptor() },
            warmedFormats: { $0.imageFormats }
        )
    }

    func audioCapabilityBootstrapDescriptor() -> CapabilityBootstrapDescriptor {
        makeCapabilityBootstrapDescriptor(
            for: .audio,
            warmDefaultCapabilities: { .audio(VideoConversionEngine.defaultAudioOutputFormats()) },
            placeholderFormats: ContentViewModelSupport.placeholderAudioFormats,
            formatDescriptor: { $0.audioOutputFormatDescriptor() },
            warmedFormats: { $0.audioFormats },
            applyAdditionalPlaceholderState: { $0.applyPlaceholderAudioCodecOptions() },
            postApplyWhenWarmed: { $0.refreshAudioCodecOptions() }
        )
    }

    func capabilityBootstrapDescriptor(for kind: MediaKind) -> CapabilityBootstrapDescriptor {
        mediaBehaviorDescriptor(for: kind).capabilityBootstrap
    }

    func applyPlaceholderCapabilityState() {
        MediaKind.allCases.forEach { applyPlaceholderCapabilities(for: $0) }
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

    func markCapabilityBootstrapNeedsRefresh(for kinds: [MediaKind]) {
        capabilityWarmState.markNeedsWarm(for: uniqueMediaKinds(kinds))
    }

    func scheduleCapabilityBootstrap(for kind: MediaKind) {
        scheduleCapabilityBootstrap(for: [kind])
    }

    func scheduleCapabilityBootstrap(for selectedTab: ConverterTab) {
        guard let kind = selectedTab.mediaKind else { return }
        scheduleCapabilityBootstrap(for: kind)
    }

    func scheduleCapabilityBootstrap(for kinds: [MediaKind]) {
        let requestedKinds = uniqueMediaKinds(kinds)
        guard !requestedKinds.isEmpty else { return }
        let resolvedFFmpegRuntimeIdentity = services.ffmpegRuntimeProvider.makeRuntime()?.cacheIdentity
        capabilityWarmState.invalidateIfNeeded(for: resolvedFFmpegRuntimeIdentity)
        let pendingKinds = capabilityWarmState.pendingKinds(in: requestedKinds)
        guard !pendingKinds.isEmpty else {
            PerformanceSignpost.event(
                "CapabilityBootstrapSkip",
                message: pendingKindsDescription(for: requestedKinds)
            )
            return
        }

        cancelTask(&taskState.capabilityBootstrapTask)
        PerformanceSignpost.event(
            "CapabilityBootstrapSchedule",
            message: pendingKindsDescription(for: pendingKinds)
        )

        taskState.capabilityBootstrapTask = Task { [weak self] in
            guard let self else { return }
            let warmed = await warmDefaultCapabilities(for: pendingKinds)

            guard !Task.isCancelled else { return }
            applyWarmedDefaultCapabilitiesIfNeeded(warmed)
            capabilityWarmState.markWarmed(
                pendingKinds,
                ffmpegRuntimeIdentity: resolvedFFmpegRuntimeIdentity
            )
            PerformanceSignpost.event(
                "CapabilityBootstrapApply",
                message: pendingKindsDescription(for: pendingKinds)
            )
            taskState.capabilityBootstrapTask = nil
        }
    }

    func uniqueMediaKinds(_ kinds: [MediaKind]) -> [MediaKind] {
        var seen: Set<MediaKind> = []
        return kinds.filter { seen.insert($0).inserted }
    }

    func applyWarmedDefaultCapabilitiesIfNeeded(_ warmedCapabilities: [WarmedDefaultCapability]) {
        warmedCapabilities.forEach {
            capabilityBootstrapDescriptor(for: $0.kind).applyWarmedIfIdle(self, $0)
        }
    }

    private func warmDefaultCapabilities(
        for kinds: [MediaKind]
    ) async -> [WarmedDefaultCapability] {
        let warmers = kinds.map { capabilityBootstrapDescriptor(for: $0).warmDefaultCapabilities }
        return await detachedTaskValue(priority: .userInitiated) {
            await withTaskGroup(
                of: WarmedDefaultCapability.self,
                returning: [WarmedDefaultCapability].self
            ) { group in
                for warm in warmers {
                    group.addTask {
                        warm()
                    }
                }

                var warmed: [WarmedDefaultCapability] = []
                for await capability in group {
                    warmed.append(capability)
                }
                return warmed
            }
        }
    }

    private func pendingKindsDescription(for kinds: [MediaKind]) -> String {
        kinds.map(\.rawValue).joined(separator: ",")
    }
}
