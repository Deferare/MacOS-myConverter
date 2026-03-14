import Foundation

extension ContentViewModel {
    struct WarmedDefaultCapability: Sendable {
        let applyIfIdle: @MainActor @Sendable (ContentViewModel) -> Void
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
        guard self[keyPath: descriptor.sourceURL] == nil,
              !self[keyPath: descriptor.isAnalyzing] else {
            return
        }

        applyAvailableOutputFormats(
            warmedFormats,
            using: formatDescriptor,
            postApply: postApply
        )
    }

    func applyPlaceholderCapabilities(for kind: MediaKind) {
        switch kind {
        case .video:
            applyAvailableOutputFormats(
                ContentViewModelSupport.placeholderVideoFormats(),
                using: Self.videoOutputFormatDescriptorValue
            )
            applyPlaceholderVideoCodecOptions()
        case .image:
            applyAvailableOutputFormats(
                ContentViewModelSupport.placeholderImageFormats(),
                using: Self.imageOutputFormatDescriptorValue
            )
        case .audio:
            applyAvailableOutputFormats(
                ContentViewModelSupport.placeholderAudioFormats(),
                using: Self.audioOutputFormatDescriptorValue
            )
            applyPlaceholderAudioCodecOptions()
        }
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
        return await detachedTaskValue(priority: .userInitiated) {
            await withTaskGroup(
                of: WarmedDefaultCapability.self,
                returning: [WarmedDefaultCapability].self
            ) { group in
                for kind in kinds {
                    group.addTask {
                        Self.warmedDefaultCapability(for: kind)
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

    nonisolated private static func warmedDefaultCapability(for kind: MediaKind) -> WarmedDefaultCapability {
        switch kind {
        case .video:
            let warmedFormats = VideoConversionEngine.defaultOutputFormats()
            return WarmedDefaultCapability { viewModel in
                viewModel.applyWarmedOutputFormatsIfIdle(
                    warmedFormats,
                    for: .video,
                    formatDescriptor: Self.videoOutputFormatDescriptorValue,
                    postApply: {
                        viewModel.refreshVideoCodecOptions()
                    }
                )
            }
        case .image:
            let warmedFormats = ImageConversionEngine.defaultOutputFormats()
            return WarmedDefaultCapability { viewModel in
                viewModel.applyWarmedOutputFormatsIfIdle(
                    warmedFormats,
                    for: .image,
                    formatDescriptor: Self.imageOutputFormatDescriptorValue
                )
            }
        case .audio:
            let warmedFormats = VideoConversionEngine.defaultAudioOutputFormats()
            return WarmedDefaultCapability { viewModel in
                viewModel.applyWarmedOutputFormatsIfIdle(
                    warmedFormats,
                    for: .audio,
                    formatDescriptor: Self.audioOutputFormatDescriptorValue,
                    postApply: {
                        viewModel.refreshAudioCodecOptions()
                    }
                )
            }
        }
    }
}
