import Foundation

extension ContentViewModel {
    struct WarmedDefaultCapability: Sendable {
        let applyIfIdle: @MainActor @Sendable (ContentViewModel) -> Void
    }

    struct CapabilityBootstrapDescriptor {
        let warmDefaultCapabilities: @Sendable () -> WarmedDefaultCapability
        let applyPlaceholder: (ContentViewModel) -> Void
    }

    static func makeCapabilityBootstrapDescriptor<Format: Sendable>(
        for kind: MediaKind,
        warmDefaultFormats: @escaping @Sendable () -> [Format],
        placeholderFormats: @escaping () -> [Format],
        formatDescriptor: @escaping @MainActor @Sendable (ContentViewModel) -> OutputFormatDescriptor<Format>,
        applyAdditionalPlaceholderState: @escaping (ContentViewModel) -> Void = { _ in },
        postApplyWhenWarmed: @escaping @MainActor @Sendable (ContentViewModel) -> Void = { _ in }
    ) -> CapabilityBootstrapDescriptor {
        CapabilityBootstrapDescriptor(
            warmDefaultCapabilities: {
                let warmedFormats = warmDefaultFormats()
                return WarmedDefaultCapability { viewModel in
                    viewModel.applyWarmedOutputFormatsIfIdle(
                        warmedFormats,
                        for: kind,
                        formatDescriptor: formatDescriptor(viewModel),
                        postApply: {
                            postApplyWhenWarmed(viewModel)
                        }
                    )
                }
            },
            applyPlaceholder: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    placeholderFormats(),
                    using: formatDescriptor(viewModel)
                )
                applyAdditionalPlaceholderState(viewModel)
            }
        )
    }

    static let videoCapabilityBootstrapDescriptorValue = makeCapabilityBootstrapDescriptor(
        for: .video,
        warmDefaultFormats: VideoConversionEngine.defaultOutputFormats,
        placeholderFormats: ContentViewModelSupport.placeholderVideoFormats,
        formatDescriptor: { _ in videoOutputFormatDescriptorValue },
        applyAdditionalPlaceholderState: { $0.applyPlaceholderVideoCodecOptions() },
        postApplyWhenWarmed: { $0.refreshVideoCodecOptions() }
    )

    static let imageCapabilityBootstrapDescriptorValue = makeCapabilityBootstrapDescriptor(
        for: .image,
        warmDefaultFormats: ImageConversionEngine.defaultOutputFormats,
        placeholderFormats: ContentViewModelSupport.placeholderImageFormats,
        formatDescriptor: { _ in imageOutputFormatDescriptorValue }
    )

    static let audioCapabilityBootstrapDescriptorValue = makeCapabilityBootstrapDescriptor(
        for: .audio,
        warmDefaultFormats: VideoConversionEngine.defaultAudioOutputFormats,
        placeholderFormats: ContentViewModelSupport.placeholderAudioFormats,
        formatDescriptor: { _ in audioOutputFormatDescriptorValue },
        applyAdditionalPlaceholderState: { $0.applyPlaceholderAudioCodecOptions() },
        postApplyWhenWarmed: { $0.refreshAudioCodecOptions() }
    )

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
        mediaStateDescriptor(for: kind).capabilityBootstrap.applyPlaceholder(self)
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
            $0.applyIfIdle(self)
        }
    }

    private func warmDefaultCapabilities(
        for kinds: [MediaKind]
    ) async -> [WarmedDefaultCapability] {
        let warmers = kinds.map {
            mediaStateDescriptor(for: $0).capabilityBootstrap.warmDefaultCapabilities
        }
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
