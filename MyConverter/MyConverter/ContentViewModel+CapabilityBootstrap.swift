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
        let descriptor = kind.mediaStateDescriptor
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
        kind.applyPlaceholderCapabilities(to: self)
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
                        kind.warmedDefaultCapability()
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

extension ContentViewModel.MediaKind {
    private struct CapabilityBootstrapBehavior: Sendable {
        let applyPlaceholderCapabilities: @MainActor @Sendable (ContentViewModel) -> Void
        let warmedDefaultCapability: @Sendable () -> ContentViewModel.WarmedDefaultCapability
    }

    nonisolated private static let capabilityBootstrapBehaviorByKind: [Self: CapabilityBootstrapBehavior] = [
        .video: CapabilityBootstrapBehavior(
            applyPlaceholderCapabilities: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    ContentViewModelSupport.placeholderVideoFormats(),
                    using: ContentViewModel.videoOutputFormatDescriptor
                )
                Self.video.applyPlaceholderCodecOptions(to: viewModel)
            },
            warmedDefaultCapability: {
                let warmedFormats = VideoConversionEngine.defaultOutputFormats()
                return ContentViewModel.WarmedDefaultCapability { viewModel in
                    viewModel.applyWarmedOutputFormatsIfIdle(
                        warmedFormats,
                        for: .video,
                        formatDescriptor: ContentViewModel.videoOutputFormatDescriptor,
                        postApply: {
                            Self.video.refreshCodecOptions(in: viewModel)
                        }
                    )
                }
            }
        ),
        .image: CapabilityBootstrapBehavior(
            applyPlaceholderCapabilities: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    ContentViewModelSupport.placeholderImageFormats(),
                    using: ContentViewModel.imageOutputFormatDescriptor
                )
            },
            warmedDefaultCapability: {
                let warmedFormats = ImageConversionEngine.defaultOutputFormats()
                return ContentViewModel.WarmedDefaultCapability { viewModel in
                    viewModel.applyWarmedOutputFormatsIfIdle(
                        warmedFormats,
                        for: .image,
                        formatDescriptor: ContentViewModel.imageOutputFormatDescriptor
                    )
                }
            }
        ),
        .audio: CapabilityBootstrapBehavior(
            applyPlaceholderCapabilities: { viewModel in
                viewModel.applyAvailableOutputFormats(
                    ContentViewModelSupport.placeholderAudioFormats(),
                    using: ContentViewModel.audioOutputFormatDescriptor
                )
                Self.audio.applyPlaceholderCodecOptions(to: viewModel)
            },
            warmedDefaultCapability: {
                let warmedFormats = VideoConversionEngine.defaultAudioOutputFormats()
                return ContentViewModel.WarmedDefaultCapability { viewModel in
                    viewModel.applyWarmedOutputFormatsIfIdle(
                        warmedFormats,
                        for: .audio,
                        formatDescriptor: ContentViewModel.audioOutputFormatDescriptor,
                        postApply: {
                            Self.audio.refreshCodecOptions(in: viewModel)
                        }
                    )
                }
            }
        )
    ]

    nonisolated private var capabilityBootstrapBehavior: CapabilityBootstrapBehavior {
        Self.capabilityBootstrapBehaviorByKind[self] ?? Self.capabilityBootstrapBehaviorByKind[.video]!
    }

    func applyPlaceholderCapabilities(to viewModel: ContentViewModel) {
        capabilityBootstrapBehavior.applyPlaceholderCapabilities(viewModel)
    }

    nonisolated func warmedDefaultCapability() -> ContentViewModel.WarmedDefaultCapability {
        capabilityBootstrapBehavior.warmedDefaultCapability()
    }
}
